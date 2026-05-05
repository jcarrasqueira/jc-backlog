Here is the complete, consolidated master guide containing all the code, files, and commands you need to implement the Pub/Sub + Vertex AI pipeline strictly for the **Review Service** and the new **Review Worker**, ready for local testing.

---

### Step 1: Cloud Credentials (Run in Terminal)

Run this in your Google Cloud Shell to create the infrastructure and download your key.

Bash

```
# 1. Enable APIs
gcloud services enable aiplatform.googleapis.com pubsub.googleapis.com

# 2. Create Topic and Subscription
gcloud pubsub topics create review-created
gcloud pubsub subscriptions create review-worker-sub --topic=review-created --ack-deadline=60

# 3. Create Service Account & Roles
gcloud iam service-accounts create review-intelligence-sa --display-name="Review Intelligence SA"
PROJECT_ID=$(gcloud config get-value project)
SA_EMAIL="review-intelligence-sa@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/aiplatform.user"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/pubsub.publisher"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/pubsub.subscriber"

# 4. Generate Key (Move the downloaded sa-key.json into your project's root folder!)
gcloud iam service-accounts keys create sa-key.json --iam-account=${SA_EMAIL}
```

---

### Step 2: Update the Review Service

**1. `review-system/requirements.txt`**

Add the Pub/Sub library to the bottom:

Plaintext

```
google-cloud-pubsub==2.19.0
```

**2. `review-system/config.py`**

Add the new database models and the Pub/Sub setup logic:

Python

```
import os
import json
from google.cloud import pubsub_v1
from sqlalchemy import Column, Integer, String, Numeric, DateTime, ForeignKey, func

# ... [Keep your existing Base and get_db logic] ...

# --- AI DATABASE MODELS ---
class ReviewSentiment(Base):
    __tablename__ = 'review_sentiment'
    sentiment_id = Column(Integer, primary_key=True)
    rating_id = Column(Integer, ForeignKey('ratings.rating_id', ondelete="CASCADE"), nullable=False)
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
    rating_id = Column(Integer, ForeignKey('ratings.rating_id', ondelete="CASCADE"), nullable=False)
    topic_id = Column(Integer, ForeignKey('topics.topic_id'), nullable=False)
    relevance_score = Column(Numeric(4,3))

# --- PUBSUB SETUP ---
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
TOPIC_ID = os.getenv("PUBSUB_TOPIC", "review-created")

if PROJECT_ID:
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)
else:
    publisher = None
    topic_path = None

def publish_review_event(rating_id: int, review_text: str):
    if not topic_path:
        print("Pub/Sub not configured. Skipping event publish.")
        return
    data = json.dumps({"rating_id": rating_id, "review": review_text}).encode("utf-8")
    future = publisher.publish(topic_path, data)
    print(f"Published review event: {future.result()}")
```

**3. `review-system/review_system_server.py`** (or `ratings.py`)

Add the Pydantic model, update the `create/update` endpoints, and add the summary endpoint.

Python

```
from typing import List, Dict, Optional
from config import publish_review_event, ReviewSentiment, Topic, RatingTopic

# --- NEW PYDANTIC MODEL ---
class ReviewSummary(BaseModel):
    movie_id: int = Field(notnull=True, description="The ID of the movie")
    total_reviews: int = Field(notnull=True, description="Total number of analyzed reviews for this movie")
    sentiment_breakdown: Dict[str, int] = Field(description="Breakdown of sentiments")
    top_topics: List[str] = Field(description="List of the most frequently mentioned topics (up to 5)")

    class Config:
        from_attributes = True

# --- ENDPOINTS ---
@app.post("/ratings", response_model=Rating, status_code=201)
async def create_rating(
    rating_create: RatingCreate,
    user_client: UserGrpcClient = Depends(get_user_client),
    movie_client: MovieGrpcClient = Depends(get_movie_client),
    db: Session = Depends(get_db)
):
    try:
        query = db.query(RatingTable)
        rating_exists = query.filter(RatingTable.user_id == rating_create.user_id, RatingTable.movie_id == rating_create.movie_id, RatingTable.is_quarantined == False).first()
        
        if rating_exists:
            update_rating_dict = rating_create.model_dump(exclude_unset=True)
            for field, value in update_rating_dict.items():
                setattr(rating_exists, field, value)
            rating_exists.updated_at = datetime.now()
            db.commit()
            db.refresh(rating_exists)

            # Publish if review text exists
            if rating_exists.review:
                try: publish_review_event(rating_exists.rating_id, rating_exists.review)
                except Exception as e: print(f"Pub/Sub Error: {e}")
            return rating_exists

        # Validations
        user_exists = await user_client.validate_user(rating_create.user_id)
        movie_exists = await movie_client.validate_movie(rating_create.movie_id)
        if not user_exists: raise HTTPException(status_code=404, detail="User does not exist")
        if not movie_exists: raise HTTPException(status_code=404, detail="Movie does not exist")
        
        new_rating = RatingTable(user_id=rating_create.user_id, movie_id=rating_create.movie_id, rating=rating_create.rating, review=rating_create.review, tag=rating_create.tag)
        db.add(new_rating)
        db.commit()
        db.refresh(new_rating)

        # Publish if review text exists
        if new_rating.review:
            try: publish_review_event(new_rating.rating_id, new_rating.review)
            except Exception as e: print(f"Pub/Sub Error: {e}")
        return new_rating
    except HTTPException: raise 
    except Exception as e: raise HTTPException(status_code=500, detail="Error creating rating")

@app.put("/ratings/{rating_id}")
def update_rating(rating_id: int = Path(...), rating_update: UpdateRating = None, db: Session = Depends(get_db)):
    try:
        rating = db.query(RatingTable).filter(RatingTable.rating_id == rating_id, RatingTable.is_quarantined == False).first()
        if not rating: raise HTTPException(status_code=404, detail="Rating not found")
        
        update_dict = rating_update.model_dump(exclude_unset=True)
        for field, value in update_dict.items(): setattr(rating, field, value)
        
        rating.updated_at = datetime.now()
        db.commit()
        db.refresh(rating)

        # Publish update to re-analyze
        if "review" in update_dict and rating.review:
            try: publish_review_event(rating.rating_id, rating.review)
            except Exception as e: print(f"Pub/Sub Error: {e}")

        return {"status_code": 200, "detail": "Rating updated successfully"}
    except Exception as e: raise HTTPException(status_code=500, detail="Error updating rating")


@app.get("/movies/{movie_id}/review-summary", response_model=ReviewSummary)
async def get_review_summary(movie_id: int = Path(...), movie_client: MovieGrpcClient = Depends(get_movie_client), db: Session = Depends(get_db)):
    try:
        if not await movie_client.validate_movie(movie_id):
            raise HTTPException(status_code=404, detail="Movie does not exist")

        rating_ids = [r.rating_id for r in db.query(RatingTable.rating_id).filter(RatingTable.movie_id == movie_id).all()]
        if not rating_ids: raise HTTPException(status_code=404, detail="No analyzed reviews exist")

        # Sentiments
        sentiments = db.query(ReviewSentiment.sentiment_label, func.count(ReviewSentiment.sentiment_id).label('count')).filter(ReviewSentiment.rating_id.in_(rating_ids)).group_by(ReviewSentiment.sentiment_label).all()
        sentiment_breakdown = {s.sentiment_label: s.count for s in sentiments}

        # Topics
        topics = db.query(Topic.name, func.count(RatingTopic.rating_topic_id).label('count')).join(RatingTopic, Topic.topic_id == RatingTopic.topic_id).filter(RatingTopic.rating_id.in_(rating_ids)).group_by(Topic.name).order_by(func.count(RatingTopic.rating_topic_id).desc()).limit(5).all()
        top_topics = [t.name for t in topics]

        total_reviews = db.query(ReviewSentiment).filter(ReviewSentiment.rating_id.in_(rating_ids)).count()
        if total_reviews == 0: raise HTTPException(status_code=404, detail="No analyzed reviews exist")

        return {
            "movie_id": movie_id,
            "total_reviews": total_reviews,
            "sentiment_breakdown": sentiment_breakdown,
            "top_topics": top_topics
        }
    except HTTPException: raise
    except Exception as e: raise HTTPException(status_code=500, detail="Error retrieving summary")
```

---

### Step 3: Create the New Review Worker

Create a brand new folder named `review-worker`.

**1. `review-worker/requirements.txt`**

Plaintext

```
google-cloud-pubsub==2.19.0
google-cloud-aiplatform==1.38.1
psycopg2-binary==2.9.9
SQLAlchemy==2.0.25
python-dotenv==1.0.0
```

**2. `review-worker/Dockerfile`**

Dockerfile

```
FROM python:3.11-slim
WORKDIR /review-worker
COPY requirements.txt .
RUN apt-get update && apt-get install -y build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "-u", "main.py"]
```

**3. `review-worker/main.py`**

Python

````
import os, json, vertexai
from vertexai.generative_models import GenerativeModel
from google.cloud import pubsub_v1
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

DB_URL = os.getenv("DB_URL")
engine = create_engine(DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

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
        result = json.loads(response.text.replace('```json', '').replace('
```', '').strip())
        
        sentiment = result.get('sentiment', 'neutral').lower()
        topics = result.get('topics', [])

        db = SessionLocal()
        try:
            # Delete old metadata for updates (Upsert logic)
            db.execute(text("DELETE FROM review_sentiment WHERE rating_id = :r_id"), {"r_id": rating_id})
            db.execute(text("DELETE FROM rating_topics WHERE rating_id = :r_id"), {"r_id": rating_id})
            
            db.execute(text("INSERT INTO review_sentiment (rating_id, sentiment_label, created_at) VALUES (:r_id, :lbl, NOW())"), {"r_id": rating_id, "lbl": sentiment})

            for t_name in topics[:5]:
                t_name = t_name.lower().strip()
                db.execute(text("INSERT INTO topics (name) VALUES (:name) ON CONFLICT (name) DO NOTHING"), {"name": t_name})
                t_result = db.execute(text("SELECT topic_id FROM topics WHERE name = :name"), {"name": t_name}).fetchone()
                if t_result:
                    db.execute(text("INSERT INTO rating_topics (rating_id, topic_id) VALUES (:r_id, :t_id)"), {"r_id": rating_id, "t_id": t_result[0]})
            db.commit()
            print(f"Successfully saved analysis for rating_id {rating_id}")
        except Exception as db_e:
            db.rollback()
            print(f"Database error: {db_e}")
        finally: db.close()
    except Exception as e: print(f"Vertex AI Error: {e}")

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
    try: streaming_pull_future.result()
    except KeyboardInterrupt: streaming_pull_future.cancel()
````

---

### Step 4: Local Testing via Docker Compose

**1. `.env` file updates:**

Code snippet

```
# Add these to your existing .env
GCP_PROJECT_ID=your-actual-gcp-project-id
GCP_REGION=europe-west1
PUBSUB_TOPIC=review-created
PUBSUB_SUBSCRIPTION=review-worker-sub
```

**2. `docker-compose.yaml` updates:**

Ensure `sa-key.json` is in your root directory.

YAML

```
  review-service:
    # ... keep your existing build/ports
    environment:
      DB_URL: ${DB_URL}
      GCP_PROJECT_ID: ${GCP_PROJECT_ID}
      PUBSUB_TOPIC: ${PUBSUB_TOPIC}
      GOOGLE_APPLICATION_CREDENTIALS: "/var/secrets/google/sa-key.json"
    volumes:
      - ./sa-key.json:/var/secrets/google/sa-key.json:ro
    depends_on:
      postgres:
        condition: service_healthy

  review-worker:
    build: ./review-worker
    container_name: review-worker
    environment:
      DB_URL: ${DB_URL}
      GCP_PROJECT_ID: ${GCP_PROJECT_ID}
      GCP_REGION: ${GCP_REGION}
      PUBSUB_SUBSCRIPTION: ${PUBSUB_SUBSCRIPTION}
      GOOGLE_APPLICATION_CREDENTIALS: "/var/secrets/google/sa-key.json"
    volumes:
      - ./sa-key.json:/var/secrets/google/sa-key.json:ro
    depends_on:
      postgres:
        condition: service_healthy
```

**3. Run the commands to test:**

Bash

```
docker compose up --build
```

Post a review using Postman, then GET `http://localhost:8003/movies/{movie_id}/review-summary` to see the magic happen!