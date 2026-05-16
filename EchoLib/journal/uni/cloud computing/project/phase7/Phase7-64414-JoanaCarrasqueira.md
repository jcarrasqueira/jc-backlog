# Group8
## Phase 7: LLM Integration with Async Event-Driven Architecture
Phase 7 implements the plan designed in Phase 6: LLM-powered capabilities are added to the **Review Service** and **Recommendations Service** using **Google Cloud Vertex AI (Gemini 1.5 Flash)**, and a new **Review Worker Service** is introduced to handle asynchronous sentiment analysis via **Google Cloud Pub/Sub**.

Two cloud-native patterns are applied:
- **BaaS (Backend-as-a-Service):** LLM computation is fully offloaded to Vertex AI — no GPU nodes are added to the cluster.
- **Event-Driven - Pub/Sub:** review submission is decoupled from LLM analysis so the user gets an instant `201` response and the analysis happens in the background.

## What Was Implemented
### UC11. Conversational Recommendation Insights 
#### FR25. Recommendation Explanation
**GET /recommendations/{user_id}/explained)**
A new endpoint on the **Recommendations Service** returns the top-5 personalized movie recommendations enriched with a plain-language explanation for each one.

**How it works:**
1. The existing scoring algorithm runs to determine the top-5 movies for the user (based on genre preferences, reference movies, and past ratings).
2. The user's taste context (liked/disliked genres, reference movie titles) is assembled into a single batched prompt.
3. The Recommendations Service calls **Vertex AI (Gemini 1.5 Flash)** synchronously with that prompt.
4. The enriched list — movie title + one-sentence explanation — is returned to the caller.
5. If the user has no recommendations (cold-start), the endpoint returns `404` without calling the LLM.

### UC12. Async Review Sentiment Analysis
#### FR26. Async Review Analysis
Changes in existing endpoints:
- **POST /ratings**  
- **POST /movies/{movie_id}/ratings**

When a rating is submitted with non-empty review text, the Review Service publishes an event to Pub/Sub immediately and returns `201`, it never waits for LLM analysis.

**How it works:**
1. A user submits a rating with a text review.
2. The **Review Service** saves the rating to PostgreSQL and returns `201` right away.
3. The service publishes a `review.created` event to the GCP Pub/Sub topic `review-created`, containing `rating_id` and `review`.
4. The **Review Worker** receives the event, calls Vertex AI to extract:
    - Overall sentiment: positive, negative, or neutral
    - Up to 5 main topics (e.g., acting, plot, special effects)
5. Results are persisted into *review_sentiment* and *rating_topics* tables.

####  FR27. Review Summary
**GET /movies/{movie_id}/review-summary**
A read-only endpoint on the **Review Service** aggregates the LLM analysis results from the database, no LLM call is made on the read path.

**Response includes:**
- *sentiment_breakdown:* counts per sentiment label (e.g., `{"positive": 10, "negative": 2}`)
- *top_topics:* up to 5 most frequently mentioned topics
- *total_reviews:* total number of analysed reviews

Returns `404` if no analysed reviews exist yet for the movie.

### Implementation Summary 

| ID   | Type           | Description                                          | Implements / Supports |
| ---- | -------------- | ---------------------------------------------------- | --------------------- |
| UC11 | Use Case       | User requests explained recommendations              | —                     |
| UC12 | Use Case       | Async review sentiment analysis + summary            | —                     |
| FR25 | Functional     | `GET /recommendations/{user_id}/explained`           | UC11                  |
| FR26 | Functional     | Async publish on review create + worker analysis     | UC12                  |
| FR27 | Functional     | `GET /movies/{movie_id}/review-summary`              | UC12                  |
| NFR1 | Non-Functional | Offload LLM to Vertex AI (BaaS, no GPU nodes)        | FR25, FR26            |
| NFR2 | Non-Functional | Decouple write path from LLM via Pub/Sub             | FR26                  |
| NFR3 | Non-Functional | Least-privilege SA + K8s Secret credential injection | FR25, FR26            |
## New Component: Review Worker Service

| Property         | Value                                                         |
| ---------------- | ------------------------------------------------------------- |
| Image            | `jrcarrasqueira/review-worker-phase7:v1.0`                    |
| Trigger          | GCP Pub/Sub subscription `review-worker-sub`                  |
| Responsibilities | Pull events, call Vertex AI, persist sentiment + topics to DB |
| Deployment file  | `08-review-worker.yaml`                                       |
The worker runs as a long-lived Deployment (not a Job) with a single replica, continuously listening for messages via streaming pull.


## Cloud Deployment Instructions

These steps assume a GCP project is already set up and `gcloud` is authenticated.

### 1. Enable Required GCP APIs

```bash
gcloud services enable aiplatform.googleapis.com pubsub.googleapis.com
```

### 2. Create the Pub/Sub Topic and Subscription

```bash
gcloud pubsub topics create review-created

gcloud pubsub subscriptions create review-worker-sub \
  --topic=review-created \
  --ack-deadline=60
```

### 3. Create the Service Account and Assign Roles

```bash
gcloud iam service-accounts create review-intelligence-sa \
  --display-name="Review Intelligence SA"

PROJECT_ID=$(gcloud config get-value project)
SA_EMAIL="review-intelligence-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# to access vertexai
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" --role="roles/aiplatform.user"

# publisher
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" --role="roles/pubsub.publisher"

# subscriber
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" --role="roles/pubsub.subscriber"

# required to let the SA use the project's quota and API limits
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" --role="roles/serviceusage.serviceUsageConsumer"

# provides broader access to Vertex AI resources within the project
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" --role="roles/aiplatform.serviceAgent"

# for local deployment download the key
gcloud iam service-accounts keys create sa-key.json \
  --iam-account="${SA_EMAIL}"
```

### 4. Create the GKE Cluster

```bash
gcloud container clusters create group8-cluster \
  --zone europe-west1-b \
  --num-nodes 2 \
  --machine-type e2-standard-2 \
  --disk-type pd-standard \
  --disk-size 30 \
  --enable-ip-alias \
  --release-channel regular
```

### 5. Configure kubectl

```bash
gcloud container clusters get-credentials group8-cluster --zone europe-west1-b
```

### 6. Create the Namespace

```bash
kubectl create namespace group8
kubectl config set-context --current --namespace=group8
```

### 7. Apply Configuration and Secrets

```bash
kubectl apply -f 00-configmap.yaml
kubectl apply -f 01-secret.yaml

# store the gcp service account key as a k8s secret
kubectl create secret generic gcp-sa-secret \
  --from-file=sa-key.json=./sa-key.json \
  -n group8

# remove the local key file after storing it in the cluster
rm sa-key.json
```

### 8. Deploy PostgreSQL and Populate the Database

```bash
kubectl apply -f 02-postgres.yaml

# wait for PostgreSQL to be ready
kubectl get pods --watch

kubectl apply -f 03-populate-db.yaml

# wait for the population job to complete
kubectl get jobs --watch
```

### 9. Deploy the Microservices

```bash
kubectl apply -f 06-reviews-service.yaml
kubectl apply -f 07-recommendations-service.yaml
kubectl apply -f 08-review-worker.yaml
```

> **Note:** If a pod enters `ErrImagePull`, verify the image path in the YAML is correct. To restart a service: `kubectl delete -f <file>.yaml` then `kubectl apply -f <file>.yaml`.

### 10. Install the NGINX Ingress Controller and Apply Ingress Rules

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/cloud/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

kubectl apply -f 12-ingress.yaml
```

### 11. Get the External IP

```bash
kubectl get ingress group8-ingress
```

Use the returned *ADDRESS* to access the services:

| Service                        | URL                                                 |
| ------------------------------ | --------------------------------------------------- |
| Review Service (REST)          | `http://<EXTERNAL_IP>/review-service/docs`          |
| Recommendations Service (REST) | `http://<EXTERNAL_IP>/recommendations-service/docs` |

## Verifying the Deployment

```bash
# Check all pods are running
kubectl get pods

# Check services
kubectl get services

# Check the populate-db job completed
kubectl get jobs

# Tail review worker logs to confirm it is listening for Pub/Sub messages
kubectl logs -f deployment/review-worker
```


## Verifying the New Endpoints

### Submit a rating with a review (triggers async analysis)

```bash
curl -X POST http://<EXTERNAL_IP>/review-service/ratings \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "movie_id": 20,
    "rating": 4.5,
    "review": "The visual effects were stunning, but the acting felt flat."
  }'
```

The response is `201` immediately. After a few seconds, the Review Worker processes the message and persists the sentiment and topics.

### Retrieve the review summary (reads from DB, no LLM call)

```bash
curl http://<EXTERNAL_IP>/review-service/movies/20/review-summary
```

### Get explained recommendations

```bash
curl http://<EXTERNAL_IP>/recommendations-service/recommendations/90/explained
```

## Docker Images

|Service|Image|
|---|---|
|Review Service|`jrcarrasqueira/reviews-phase7:v1.0`|
|Recommendations Service|`jrcarrasqueira/recommendations-phase7:v1.0`|
|Review Worker|`jrcarrasqueira/review-worker-phase7:v1.0`|
|DB Population Job|`jrcarrasqueira/populate-db:v3.0`|
