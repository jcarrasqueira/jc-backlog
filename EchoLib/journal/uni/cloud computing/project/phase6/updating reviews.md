To implement the Option 1 architecture (GCP Pub/Sub + Vertex AI) in your current **Review Service**, you need to turn your FastAPI application into a **Publisher**.

Whenever a user submits or updates a review with text, the service should immediately save it to the PostgreSQL database, and then fire off an asynchronous message to Google Cloud Pub/Sub. (The actual LLM processing will be done by a separate worker you'll build later).

Here are the exact modifications you need to make to your existing branch files:

### 1. Update `requirements.txt`

You need the official Google Cloud Pub/Sub SDK. Add this to the bottom of your file:

Plaintext

```
google-cloud-pubsub>=2.21.0
```

### 2. Update `config.py`

Add the necessary environment variables to configure your GCP connection. Add these right after `DB_URL = os.getenv("DB_URL")`:

Python

```
# GCP Configuration
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
PUBSUB_TOPIC = os.getenv("PUBSUB_TOPIC", "new-reviews")
```

### 3. Update `ratings.py` (The Core Logic)

You need to initialize the Pub/Sub client and trigger it during the `create_rating` and `update_rating` flows.

**A. Add Imports & Initialization (Top of file)**

Add these imports right under your existing `from sqlalchemy.orm import Session`:

Python

```
import json
from google.cloud import pubsub_v1
from config import GCP_PROJECT_ID, PUBSUB_TOPIC
```

Then, initialize the publisher right below your `app = FastAPI(...)` definition. We wrap it in a `try/except` so your app doesn't crash if you run it locally without GCP credentials set up yet:

Python

```
# Initialize Pub/Sub Publisher
publisher = None
topic_path = None

if GCP_PROJECT_ID:
    try:
        publisher = pubsub_v1.PublisherClient()
        topic_path = publisher.topic_path(GCP_PROJECT_ID, PUBSUB_TOPIC)
        print(f"Pub/Sub initialized for topic: {topic_path}")
    except Exception as e:
        print(f"Failed to initialize Pub/Sub client: {e}")

def publish_review_to_pubsub(rating_id: int, review_text: str):
    """Helper function to publish an event asynchronously without blocking the API."""
    if publisher and topic_path and review_text:
        try:
            data = json.dumps({"rating_id": rating_id, "text": review_text}).encode("utf-8")
            # This publishes asynchronously
            future = publisher.publish(topic_path, data)
            # Add a callback to print the message ID once published
            future.add_done_callback(lambda f: print(f"Published message ID: {f.result()}"))
        except Exception as e:
            print(f"Error publishing to Pub/Sub: {e}")
```

**B. Trigger the Event in `create_rating`**

Inside your `@app.post("/ratings")` endpoint, find the two places where you commit to the database. Add the `publish_review_to_pubsub` call right before you return the response.

_Update block (upsert):_

Python

```
            db.commit()
            db.refresh(rating_exists)
            
            # --- NEW: Publish if there is review text ---
            if rating_exists.review:
                publish_review_to_pubsub(rating_exists.rating_id, rating_exists.review)
                
            return rating_exists
```

_Creation block:_

Python

```
        db.add(new_rating)
        db.commit()
        db.refresh(new_rating)
        
        # --- NEW: Publish if there is review text ---
        if new_rating.review:
            publish_review_to_pubsub(new_rating.rating_id, new_rating.review)
            
        return new_rating
```

**C. Trigger the Event in `update_rating`**

Inside your `@app.put("/ratings/{rating_id}")` endpoint, add the trigger right after the commit:

Python

```
        db.commit()
        db.refresh(rating)
        
        # --- NEW: Publish if there is review text ---
        if rating.review:
            publish_review_to_pubsub(rating.rating_id, rating.review)
            
        return {"status_code": 200, "detail": "Rating updated successfully"}
```

### 4. Update `docker-compose.yaml` (For Local Testing)

To test this locally using Docker Compose, your `review-service` container needs access to a Google Cloud Service Account JSON key.

Update the `review-service` section in your `docker-compose.yaml`:

YAML

```
  review-service:
    image: jrcarrasqueira/reviews-phase5:v2.0
    container_name: review-service
    ports:
      - ${REVIEW_SERVICE_PORTS}
      - ${REVIEW_GRPC_PORTS}
    environment:
      DB_URL: ${DB_URL}
      GRPC_PORT: ${REVIEW_GRPC_PORT}
      REST_PORT: ${REVIEW_REST_PORT}
      GRPC_URL: ${REVIEW_GRPC_URL}
      REST_URL: ${REVIEW_REST_URL}
      # --- NEW ENVIRONMENT VARIABLES ---
      GCP_PROJECT_ID: ${GCP_PROJECT_ID}
      PUBSUB_TOPIC: new-reviews
      GOOGLE_APPLICATION_CREDENTIALS: /var/secrets/google/key.json
    volumes:
      # --- NEW VOLUME MOUNT ---
      - ./gcp-key.json:/var/secrets/google/key.json:ro
    depends_on:
      postgres:
        condition: service_healthy
      populate-db:
        condition: service_completed_successfully
```

### What you need to do locally to make it work:

1. Generate a Service Account JSON key from your Google Cloud Console (with `Pub/Sub Publisher` role).
    
2. Save it as `gcp-key.json` in the root of your project directory (right next to your `docker-compose.yaml`). **Important: add `gcp-key.json` to your `.gitignore` immediately so you don't commit your cloud credentials to GitHub.**
    
3. Add `GCP_PROJECT_ID=your-actual-gcp-project-id` to your `.env` file.
    

With these changes, your Review Service is now fully prepared to act as an event publisher for your Phase 6 LLM architecture!