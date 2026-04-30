# CC2526 — Phase 6
*Joana Carrasqueira, 64414*  
*branch: jcarrasqueira*

---

## Plan for Phase 7: LLM Integration with Async Event-Driven Architecture

This phase extends the existing **Review Service** and **Recommendations Service** with LLM-powered capabilities using **Google Cloud Vertex AI (Gemini 1.5 Flash)** and an asynchronous event-driven architecture using **Google Cloud Pub/Sub**.

The proposed improvement follows two cloud-native patterns listed in the course guidelines:
- **BaaS (Backend-as-a-Service):** offloading LLM computation to Vertex AI, eliminating the need for GPU node pools in the cluster.
- **Event-Driven / Pub/Sub:** decoupling review submission from LLM analysis so the user gets an instant response and analysis happens asynchronously in the background.

A new lightweight **Review Worker Service** is introduced as a Pub/Sub consumer responsible solely for calling Vertex AI and persisting the results.

## Use Cases

### UC11. Conversational Recommendation Insights
- **Actor:** Registered user.
- **Problem:** The recommendation algorithm returns a ranked list of movies with no human-readable explanation, reducing user trust and engagement.
- **Description:**
  1. A user calls `GET /recommendations/{user_id}/explained` on the Recommendations Service.
  2. The service runs the existing scoring algorithm to obtain the top-5 recommendations and their metadata (matched genres, reference movies, score breakdown).
  3. The Recommendations Service calls Vertex AI synchronously with a single batched prompt requesting one plain-language explanation per movie.
  4. The enriched list — movie title + explanation — is returned to the caller.

### UC12. Async Review Sentiment Analysis
- **Actor:** Registered user / Platform.
- **Problem:** Analysing review text with an LLM takes 1–2 seconds. Blocking the review submission response on this would degrade the user experience.
- **Description:**
  1. A user submits a rating with a text review via `POST /ratings` or `POST /movies/{movie_id}/ratings`.
  2. The Review Service saves the rating to PostgreSQL immediately and returns a 201 response to the user.
  3. The Review Service publishes a `review.created` event to a **GCP Pub/Sub** topic containing the `rating_id` and `review` text.
  4. The **Review Worker Service** receives the event, calls Vertex AI to extract sentiment and topics, and persists the results into `review_sentiment` and `rating_topics`.
  5. `GET /movies/{movie_id}/review-summary` aggregates from those tables and returns a structured summary — no LLM call on the read path.

## Functional Requirements
### FR25. Recommendation Explanation
- The Recommendations Service must expose `GET /recommendations/{user_id}/explained` returning the top-5 list enriched with one plain-language explanation per movie.
- If the user has no recommendations (cold-start), the response must return an empty list gracefully without calling the LLM.
- All explanations must be generated in a single Vertex AI call.
### FR26. Async Review Analysis
- Upon creation of a rating with non-empty review text, the Review Service must publish a `review.created` event to Pub/Sub and return the 201 response immediately — it must not wait for LLM analysis.
- The Review Worker must consume the event, call Vertex AI, and persist the sentiment label and up to 5 topics into `review_sentiment` and `rating_topics`.
- If the review text is empty, no event is published.
### FR27. Review Summary
- The Review Service must expose `GET /movies/{movie_id}/review-summary` that aggregates sentiment and topics from the database.
- If no analysed reviews exist for the movie yet, the endpoint must return a 404 with a clear message.
- The response must include: `sentiment_breakdown` (counts per label), `top_topics` (list of up to 5 strings), `total_reviews` (int).

### FR28. Fault Tolerance
- If Vertex AI is rate-limited or unavailable, the Review Worker must implement a **retry pattern**: up to 3 retries with exponential backoff before discarding the message.
- LLM failures in the Recommendations Service must return HTTP 503 with a clear error message.

## Non-Functional Requirements
### NFR1. Serverless AI Integration (BaaS)
- LLM computation is fully offloaded to Vertex AI — no GPU nodes are added to the GKE cluster.
- **Gemini 1.5 Flash** is selected for its low cost and free tier (up to 1 500 requests/day), keeping expenses within the existing GCP project

### NFR2. Asynchronous Processing (Event-Driven)
- Review submission must never block on LLM analysis. The Pub/Sub pattern decouples the write path from the analysis path, keeping p99 latency of `POST /ratings` unaffected by Vertex AI response times.

### NFR3. Security
- A dedicated GCP Service Account (`review-intelligence-sa`) is created with only `roles/aiplatform.user` and `roles/pubsub.publisher` / `roles/pubsub.subscriber` as needed — least privilege.
- Credentials are injected into pods via a **Kubernetes Secret** mounted as an environment variable (`GOOGLE_APPLICATION_CREDENTIALS`).

### NFR4. Cost Efficiency (FinOps)
- Review texts are truncated to 500 characters before being sent to the model, capping token usage per request.
- The Review Worker runs as a single replica with minimal resources (`cpu: 100m`, `memory: 128Mi`) since it performs no heavy computation locally.
- Pub/Sub free tier covers up to 10 GB of messages per month, sufficient for this project's scale.

### NFR5. Observability
- All services log to stdout in structured JSON, visible in Google Cloud Logging without additional configuration.
- The Review Worker logs each Pub/Sub message received, Vertex AI call result, and any retry attempts.

---

## Technical Architecture

### Components

| Component | Type | Protocol | Port | Change |
|---|---|---|---|---|
| Review Service | Existing FastAPI | REST + gRPC | 8003 / 50055 | Publishes `review.created` to Pub/Sub on rating create |
| Recommendations Service | Existing FastAPI | REST + gRPC | 8004 / 50056 | Calls Vertex AI synchronously for explanations |
| Review Worker Service | **New** FastAPI/Python | Pub/Sub pull | — | Consumes events, calls Vertex AI, writes to DB |
| GCP Pub/Sub | Managed | — | — | New topic: `review-created` |
| Vertex AI (Gemini 1.5 Flash) | Managed BaaS | HTTPS | — | New dependency for both services |

### Architecture Diagram

```mermaid
graph TD
    Client([External Client]) -->|POST /ratings\nREST :8003| RS[Review Service]
    Client -->|GET /recommendations/{id}/explained\nREST :8004| REC[Recommendations Service]

    RS -->|1 save rating| DB[(PostgreSQL)]
    RS -->|2 publish review.created| PS[GCP Pub/Sub\nreview-created topic]
    RS -->|3 return 201 immediately| Client

    PS -->|pull event| RW[Review Worker Service]
    RW -->|analyse text| VAI[Vertex AI\nGemini 1.5 Flash]
    VAI -->|sentiment + topics| RW
    RW -->|persist to review_sentiment\nrating_topics| DB

    REC -->|run scoring algorithm| DB
    REC -->|explain recommendations| VAI
    REC -->|GetUserRatings gRPC :50055| RS

    Client -->|GET /movies/{id}/review-summary\nREST :8003| RS
    RS -->|aggregate from DB| DB

    subgraph GKE — namespace: group8
        RS
        REC
        RW
        DB
    end

    subgraph GCP Managed
        PS
        VAI
    end
```

### New and Modified Files

```
review-system/
├── ratings.py          modified — publish event to Pub/Sub after save in create_rating
├── config.py           modified — add ReviewSentimentTable, TopicTable, RatingTopicTable ORM models
└── requirements.txt    modified — add google-cloud-pubsub, google-cloud-aiplatform

recommendations/
├── llm_client.py       new — Vertex AI wrapper, explain_recommendations()
├── recommendations.py  modified — add GET /recommendations/{user_id}/explained
└── requirements.txt    modified — add google-cloud-aiplatform

review-worker/
├── dockerfile          new
├── .dockerignore       new
├── requirements.txt    new
├── worker.py           new — Pub/Sub pull loop, Vertex AI call, DB write
└── config.py           new — DB connection, ORM models (shared subset)

k8s/
├── 00-configmap.yaml               modified — add GCP_PROJECT_ID, GCP_REGION, PUBSUB_TOPIC
├── 01-secret.yaml                  modified — add GCP service account key (base64)
├── 09-reviews-service.yaml         modified — add env refs for Pub/Sub + GCP vars
├── 10-recommendations-service.yaml modified — add env refs for Vertex AI vars
└── 11-review-worker.yaml           new — Deployment for the worker service
```

---

## Deployment Plan

### 1. Enable GCP APIs

```bash
gcloud services enable aiplatform.googleapis.com
gcloud services enable pubsub.googleapis.com
```

### 2. Create Pub/Sub topic and subscription

```bash
gcloud pubsub topics create review-created

gcloud pubsub subscriptions create review-worker-sub \
  --topic=review-created \
  --ack-deadline=60
```

### 3. Create the GCP Service Account and key

```bash
# create service account
gcloud iam service-accounts create review-intelligence-sa \
  --display-name="Review Intelligence SA"

# grant Vertex AI and Pub/Sub roles
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com" \
  --role="roles/pubsub.subscriber"

# create and download key
gcloud iam service-accounts keys create sa-key.json \
  --iam-account=review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

### 4. Store credentials in Kubernetes Secret

```bash
kubectl create secret generic gcp-sa-secret \
  --from-file=sa-key.json=./sa-key.json \
  -n group8

# remove local key file after
rm sa-key.json
```

### 5. Update ConfigMap

Add to `k8s/00-configmap.yaml`:
```yaml
GCP_PROJECT_ID: "<PROJECT_ID>"
GCP_REGION: "europe-west1"
PUBSUB_TOPIC: "review-created"
PUBSUB_SUBSCRIPTION: "review-worker-sub"
```

Reference the secret in the Deployment env sections of all three services:
```yaml
- name: GOOGLE_APPLICATION_CREDENTIALS
  value: "/var/secrets/google/sa-key.json"
volumes:
  - name: gcp-sa-secret
    secret:
      secretName: gcp-sa-secret
volumeMounts:
  - name: gcp-sa-secret
    mountPath: /var/secrets/google
    readOnly: true
```

### 6. Build and deploy

```bash
kubectl apply -f k8s/00-configmap.yaml
kubectl apply -f k8s/01-secret.yaml

# review service (now publishes to Pub/Sub)
docker build -t jrcarrasqueira/review-system:v2.0 ./review-system
docker push jrcarrasqueira/review-system:v2.0
kubectl set image deployment/reviews-service \
  reviews-service=jrcarrasqueira/review-system:v2.0 -n group8

# recommendations service (now calls Vertex AI)
docker build -t jrcarrasqueira/recommendations:v2.0 ./recommendations
docker push jrcarrasqueira/recommendations:v2.0
kubectl set image deployment/recommendations-service \
  recommendations-service=jrcarrasqueira/recommendations:v2.0 -n group8

# review worker (new)
docker build -t jrcarrasqueira/review-worker:v1.0 ./review-worker
docker push jrcarrasqueira/review-worker:v1.0
kubectl apply -f k8s/11-review-worker.yaml

# verify
kubectl rollout status deployment/reviews-service -n group8
kubectl rollout status deployment/recommendations-service -n group8
kubectl rollout status deployment/review-worker -n group8
```

---

## Implementation Notes

### Pub/Sub event published by Review Service

```python
# in ratings.py, after db.commit() in create_rating
from google.cloud import pubsub_v1
import json, os

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(os.getenv("GCP_PROJECT_ID"), os.getenv("PUBSUB_TOPIC"))

if new_rating.review:
    data = json.dumps({"rating_id": new_rating.rating_id, "review": new_rating.review}).encode()
    publisher.publish(topic_path, data=data)
```

### Review Worker pull loop

```python
# worker.py
from google.cloud import pubsub_v1
subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(PROJECT_ID, SUBSCRIPTION)

def callback(message):
    data = json.loads(message.data)
    result = analyse_review(data["review"])   # Vertex AI call
    persist_llm_analysis(data["rating_id"], result, db)
    message.ack()

subscriber.subscribe(subscription_path, callback=callback)
```

### Vertex AI call (`llm_client.py` — both services)

```python
import vertexai
from vertexai.generative_models import GenerativeModel

vertexai.init(project=os.getenv("GCP_PROJECT_ID"), location=os.getenv("GCP_REGION"))
_model = GenerativeModel("gemini-1.5-flash")
response = _model.generate_content(prompt)
```

### Retry pattern in Review Worker

Up to 3 retries with exponential backoff. If all retries fail, the message is **not acknowledged** — Pub/Sub will redeliver it according to the subscription's retry policy. After the maximum delivery attempts configured on the subscription, the message is dropped to a dead-letter topic (configured in Phase 7 if needed).
