Here is the complete, step-by-step implementation guide including all the code, files, and commands needed to implement the event-driven LLM architecture for Phase 6/7.

### 1. GCP and Kubernetes Setup Commands

Run these commands in your Google Cloud Shell or terminal to set up the infrastructure.

Bash

```
# 1. Enable APIs
gcloud services enable aiplatform.googleapis.com pubsub.googleapis.com

# 2. Create Pub/Sub Topic and Subscription
gcloud pubsub topics create review-created
gcloud pubsub subscriptions create review-worker-sub --topic=review-created --ack-deadline=60

# 3. Create Service Account & Assign Roles
gcloud iam service-accounts create review-intelligence-sa --display-name="Review Intelligence SA"
PROJECT_ID=$(gcloud config get-value project)
SA_EMAIL="review-intelligence-sa@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/aiplatform.user"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/pubsub.publisher"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/pubsub.subscriber"

# 4. Generate Key and Create Kubernetes Secret
gcloud iam service-accounts keys create sa-key.json --iam-account=${SA_EMAIL}
kubectl create secret generic gcp-sa-secret --from-file=sa-key.json=./sa-key.json -n group8
rm sa-key.json
```

---

### 2. Review Service Updates

This service needs to publish to Pub/Sub and aggregate the database results.

**File: `review-system/requirements.txt`** Add the following line to your existing requirements:

Plaintext

```
google-cloud-pubsub==2.19.0
```

**File: `review-system/config.py`** Add the new SQLAlchemy models to map to your database schema:

Python

```
from sqlalchemy import Column, Integer, String, Numeric, DateTime, ForeignKey, func

class ReviewSentiment(Base):
    __tablename__ = 'review_sentiment'
    sentiment_id = Column(Integer, primary_key=True)
    rating_id = Column(Integer, ForeignKey('ratings.rating_id'))
    sentiment_label = Column(String(20), nullable=False)
    sentiment_score = Column(Numeric(4,3))
    created_at = Column(DateTime, default=func.now())

class Topic(Base):
    __tablename__ = 'topics'
    topic_id = Column(Integer, primary_key=True)
    name = Column(String(100), unique=True, nullable=False)

class RatingTopic(Base):
    __tablename__ = 'rating_topics'
    rating_topic_id = Column(Integer, primary_key=True)
    rating_id = Column(Integer, ForeignKey('ratings.rating_id'))
    topic_id = Column(Integer, ForeignKey('topics.topic_id'))
    relevance_score = Column(Numeric(4,3))
```

**File: `review-system/review_system_server.py`** Add the Pub/Sub logic and the new summary endpoint. Add these imports and initializations at the top:

Python

```
import os
import json
from google.cloud import pubsub_v1
from config import ReviewSentiment, Topic, RatingTopic # Add to your config imports

# Pub/Sub Setup
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
TOPIC_ID = os.getenv("PUBSUB_TOPIC", "review-created")
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID) if PROJECT_ID else None

def publish_review_event(rating_id: int, review_text: str):
    if not topic_path:
        print("Pub/Sub not configured.")
        return
    data = json.dumps({"rating_id": rating_id, "review": review_text}).encode("utf-8")
    future = publisher.publish(topic_path, data)
    print(f"Published review event: {future.result()}")
```

Modify the `create_rating` (and `create_movie_rating`) endpoint to publish the event before returning:

Python

```
        # Inside create_rating, right after: db.refresh(new_rating)
        if new_rating.review:
            try:
                publish_review_event(new_rating.rating_id, new_rating.review)
            except Exception as e:
                print(f"Failed to publish to Pub/Sub: {e}")
                
        return new_rating
```

Add the new summary endpoint:

Python

```
@app.get("/movies/{movie_id}/review-summary")
def get_review_summary(movie_id: int = Path(...), db: Session = Depends(get_db)):
    # Verify movie exists
    movie = db.query(Movie).filter(Movie.movie_id == movie_id).first()
    if not movie:
        raise HTTPException(status_code=404, detail="Movie not found")

    # Get all rating IDs for this movie
    rating_ids = [r.rating_id for r in db.query(RatingTable.rating_id).filter(RatingTable.movie_id == movie_id).all()]
    
    if not rating_ids:
        raise HTTPException(status_code=404, detail="No analyzed reviews exist for this movie")

    # Aggregate Sentiment
    sentiments = db.query(
        ReviewSentiment.sentiment_label, 
        func.count(ReviewSentiment.sentiment_id).label('count')
    ).filter(ReviewSentiment.rating_id.in_(rating_ids)).group_by(ReviewSentiment.sentiment_label).all()
    
    sentiment_breakdown = {s.sentiment_label: s.count for s in sentiments}

    # Aggregate Topics
    topics = db.query(
        Topic.name, 
        func.count(RatingTopic.rating_topic_id).label('count')
    ).join(RatingTopic, Topic.topic_id == RatingTopic.topic_id)\
     .filter(RatingTopic.rating_id.in_(rating_ids))\
     .group_by(Topic.name).order_by(func.count(RatingTopic.rating_topic_id).desc()).limit(5).all()

    top_topics = [t.name for t in topics]
    total_reviews = db.query(ReviewSentiment).filter(ReviewSentiment.rating_id.in_(rating_ids)).count()

    if total_reviews == 0:
        raise HTTPException(status_code=404, detail="No analyzed reviews exist for this movie")

    return {
        "movie_id": movie_id,
        "total_reviews": total_reviews,
        "sentiment_breakdown": sentiment_breakdown,
        "top_topics": top_topics
    }
```

---

### 3. Recommendations Service Updates

This service needs to talk to Vertex AI synchronously.

**File: `recommendations/requirements.txt`** Add the following line:

Plaintext

```
google-cloud-aiplatform==1.38.1
```

**File: `recommendations/recomendations_server.py`** Add Vertex AI initialization and the new endpoint.

Python

````
import os
import vertexai
from vertexai.generative_models import GenerativeModel

# Initialize Vertex AI
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
REGION = os.getenv("GCP_REGION", "europe-west1")
if PROJECT_ID:
    vertexai.init(project=PROJECT_ID, location=REGION)
    llm = GenerativeModel("gemini-1.5-flash")
else:
    llm = None

@app.get("/recommendations/{user_id}/explained")
async def get_explained_recommendations(
    user_id: int, 
    db: Session = Depends(get_db), 
    review: ReviewGrpcClient = Depends(get_review_client)
):
    # 1. Reuse existing recommendation logic to get top 5 movies
    recommendations = await get_recommendations(user_id, db, review)
    
    if not recommendations:
        return []

    # 2. Build prompt for Vertex AI
    movie_titles = [rec.title for rec in recommendations]
    prompt = f"""
    You are a movie recommendation expert. I am recommending the following movies to a user based on their past likes and highly-rated genres:
    {', '.join(movie_titles)}.
    
    Provide a brief, 1-sentence plain-language explanation for WHY each movie is recommended. 
    Format your response strictly as a JSON array of objects with keys "title" and "explanation".
    """

    explained_recs = []
    try:
        if llm:
            response = llm.generate_content(prompt)
            # Clean markdown formatting if Gemini returns it
            clean_text = response.text.replace('```json', '').replace('
```', '').strip()
            ai_explanations = json.loads(clean_text)
            
            # Map explanations back to recommendations
            exp_dict = {item['title']: item['explanation'] for item in ai_explanations}
            
            for rec in recommendations:
                explained_recs.append({
                    "movie_id": rec.movie_id,
                    "title": rec.title,
                    "explanation": exp_dict.get(rec.title, "Recommended based on your recent activity.")
                })
        else:
            raise Exception("Vertex AI not initialized.")
    except Exception as e:
        print(f"Vertex AI Error: {e}")
        # Fallback if LLM fails
        for rec in recommendations:
            explained_recs.append({
                "movie_id": rec.movie_id,
                "title": rec.title,
                "explanation": "Recommended based on your genre preferences."
            })

    return explained_recs
````

---

### 4. New Review Worker Service

Create a new folder named `review-worker` in your project root.

**File: `review-worker/requirements.txt`**

Plaintext

```
google-cloud-pubsub==2.19.0
google-cloud-aiplatform==1.38.1
psycopg2-binary==2.9.9
SQLAlchemy==2.0.25
python-dotenv==1.0.0
```

**File: `review-worker/main.py`**

Python

```
import os
import json
import time
import vertexai
from vertexai.generative_models import GenerativeModel
from google.cloud import pubsub_v1
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# DB Setup
DB_URL = os.getenv("DB_URL")
engine = create_engine(DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# GCP Setup
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
REGION = os.getenv("GCP_REGION", "europe-west1")
SUB_ID = os.getenv("PUBSUB_SUBSCRIPTION", "review-worker-sub")

vertexai.init(project=PROJECT_ID, location=REGION)
llm = GenerativeModel("gemini-1.5-flash")

subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(PROJECT_ID, SUB_ID)

def process_review(rating_id, review_text):
    print(f"Processing rating_id: {rating_id}")
    prompt = f"""
    Analyze the following movie review: "{review_text}"
    Extract the overall sentiment (choose exactly one: "positive", "negative", or "neutral") 
    and extract up to 5 main topics discussed (e.g., "acting", "plot", "special effects").
    Format strictly as JSON: {{"sentiment": "positive", "topics": ["topic1", "topic2"]}}
    """
    
    try:
        response = llm.generate_content(prompt)
        clean_text = response.text.replace('```json', '').replace('```', '').strip()
        result = json.loads(clean_text)
        
        sentiment = result.get('sentiment', 'neutral').lower()
        topics = result.get('topics', [])

        db = SessionLocal()
        try:
            # 1. Insert Sentiment
            db.execute(text(
                "INSERT INTO review_sentiment (rating_id, sentiment_label, created_at) "
                "VALUES (:r_id, :lbl, NOW())"
            ), {"r_id": rating_id, "lbl": sentiment})

            # 2. Process Topics
            for t_name in topics[:5]:
                t_name = t_name.lower().strip()
                # Insert topic if not exists, get ID
                db.execute(text(
                    "INSERT INTO topics (name) VALUES (:name) ON CONFLICT (name) DO NOTHING"
                ), {"name": t_name})
                
                t_result = db.execute(text("SELECT topic_id FROM topics WHERE name = :name"), {"name": t_name}).fetchone()
                if t_result:
                    db.execute(text(
                        "INSERT INTO rating_topics (rating_id, topic_id) VALUES (:r_id, :t_id)"
                    ), {"r_id": rating_id, "t_id": t_result[0]})

            db.commit()
            print(f"Successfully saved analysis for rating_id {rating_id}")
        except Exception as db_e:
            db.rollback()
            print(f"Database error: {db_e}")
        finally:
            db.close()

    except Exception as e:
        print(f"Vertex AI Error: {e}")

def callback(message):
    try:
        data = json.loads(message.data.decode("utf-8"))
        process_review(data['rating_id'], data['review'])
        message.ack()
    except Exception as e:
        print(f"Failed to process message: {e}")
        message.nack()

print(f"Listening for messages on {subscription_path}...")
streaming_pull_future = subscriber.subscribe(subscription_path, callback=callback)

with subscriber:
    try:
        streaming_pull_future.result()
    except KeyboardInterrupt:
        streaming_pull_future.cancel()
```

**File: `review-worker/Dockerfile`**

Dockerfile

```
FROM python:3.11-slim

WORKDIR /review-worker

COPY requirements.txt .

# Install dependencies (psycopg2 requires build-essential and libpq-dev)
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# We don't need a start.sh script here, we can just run the worker directly
CMD ["python", "-u", "main.py"]
```

```
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
CMD ["python", "-u", "main.py"]
```

---

### 5. Kubernetes Configurations

**File: `k8s/00-configmap.yaml`** (Add to bottom of existing file)

YAML

```
  GCP_PROJECT_ID: "<YOUR_PROJECT_ID_HERE>"
  GCP_REGION: "europe-west1"
  PUBSUB_TOPIC: "review-created"
  PUBSUB_SUBSCRIPTION: "review-worker-sub"
```

**File: `k8s/11-review-worker.yaml`** (Create this new file)

YAML

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: review-worker
  namespace: group8
spec:
  replicas: 1
  selector:
    matchLabels:
      app: review-worker
  template:
    metadata:
      labels:
        app: review-worker
    spec:
      containers:
        - name: review-worker
          image: jrcarrasqueira/review-worker:v1.0
          envFrom:
            - configMapRef:
                name: group8-config
            - secretRef:
                name: group8-secrets
          env:
            - name: GOOGLE_APPLICATION_CREDENTIALS
              value: "/var/secrets/google/sa-key.json"
          volumeMounts:
            - name: gcp-sa-secret
              mountPath: /var/secrets/google
              readOnly: true
      volumes:
        - name: gcp-sa-secret
          secret:
            secretName: gcp-sa-secret
```

_Note: Make sure to add the `env` block and `volumes` block exactly like above to your existing `09-reviews-service.yaml` and `10-recommendations-service.yaml` as well so they can authenticate._