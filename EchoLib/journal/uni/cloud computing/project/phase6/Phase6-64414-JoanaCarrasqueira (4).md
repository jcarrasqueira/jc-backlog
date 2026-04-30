*Joana Carrasqueira, 64414*
*branch: jcarrasqueira*

# Cloud Computing — Phase 6

The goal of this phase is to extend the existing **Review Service** and **Recommendations Service** with LLM-powered capabilities using **Google Cloud Vertex AI (Gemini 1.5 Flash)**, deployed natively on the existing GKE cluster.

No new microservice is introduced. The LLM features are added directly to the services that already own the relevant data and logic.

## Non-Functional Improvement: Data Science — LLM Integration

The improvement proposed is the integration of an LLM into the existing services to implement **BC5. Smart Intelligent Review System** and extend **UC4. Sentiment and Topic Dashboard by User Segment**.

### Design decision: write-time analysis

The LLM runs at **write time** — when a review is created or updated — and persists its output into the `review_sentiment` and `rating_topics` tables already defined in the database schema. The read endpoint (`GET /movies/{movie_id}/review-summary`) then aggregates from those tables with a plain SQL query, with no LLM call on the read path. This keeps read latency low and avoids redundant LLM calls for the same review.

### Why Vertex AI

Authentication is handled through **GKE Workload Identity** — the pods acquire GCP credentials automatically at runtime from the GKE metadata server. No API keys or secrets are stored anywhere. **Gemini 1.5 Flash** is selected for its low cost and free tier (up to 1 500 requests/day), keeping expenses within the existing GCP project.

## Implemented

### Use Cases

| **Use Case** | **Implementation Details** |
| --- | --- |
| **UC4. Sentiment and Topic Dashboard** | When a review is submitted, Gemini analyses the text and writes sentiment label and topics to `review_sentiment` and `rating_topics`. `GET /movies/{movie_id}/review-summary` aggregates these into a structured response. |
| **UC-NEW. Recommendation Explanation** | `GET /recommendations/{user_id}/explained` runs the existing scoring algorithm then calls Gemini once to generate a one-sentence explanation per recommended movie. |

### Functional Requirements

| **Requirement** | **Description** | **Service** |
| --- | --- | --- |
| **FR-LLM1. Review Summary** | Returns sentiment breakdown and top topics for a movie, aggregated from persisted LLM analysis. Returns 404 if no analysed reviews exist yet. | Review Service |
| **FR-LLM2. Recommendation Explanation** | Returns top-5 recommendations enriched with a plain-language explanation per movie. Falls back gracefully if no recommendations exist. | Recommendations Service |
| **FR-LLM3. Workload Identity Auth** | Both services authenticate to Vertex AI via GCP Service Account bound to their Kubernetes Service Account. No API keys stored anywhere. | Both |
| **FR-LLM4. Graceful Degradation** | LLM failures never break the rating creation response. If Vertex AI is unavailable the rating is saved normally and analysis is skipped silently. | Review Service |

## Changes to Existing Services

### Review Service — new files and changes

| File | Change |
| --- | --- |
| `review-system/llm_client.py` | New — Vertex AI wrapper, `analyse_review(text)` returns `{sentiment, topics}` |
| `review-system/ratings.py` | `_persist_llm_analysis` helper added; hooked into `create_rating` and `update_rating` after `db.refresh`; new endpoint `GET /movies/{movie_id}/review-summary` |
| `review-system/config.py` | Three new ORM models: `ReviewSentimentTable`, `TopicTable`, `RatingTopicTable` |
| `review-system/requirements.txt` | Added `google-cloud-aiplatform==1.71.1` |

### Recommendations Service — new files and changes

| File | Change |
| --- | --- |
| `recommendations/llm_client.py` | New — Vertex AI wrapper, `explain_recommendations(liked_genres, ref_titles, movies)` returns list of explanation strings |
| `recommendations/recommendations.py` | New endpoint `GET /recommendations/{user_id}/explained` |
| `recommendations/requirements.txt` | Added `google-cloud-aiplatform==1.71.1` |

### Kubernetes — changes to existing manifests

| File | Change |
| --- | --- |
| `k8s/00-configmap.yaml` | Added `GCP_PROJECT_ID` and `GCP_REGION` |
| `k8s/09-reviews-service.yaml` | Added env references to new configmap keys; added `serviceAccountName: reviews-service-ksa` |
| `k8s/10-recommendations-service.yaml` | Added env references to new configmap keys; added `serviceAccountName: recommendations-service-ksa` |

## GCP Setup (run once)

```bash
# enable Vertex AI
gcloud services enable aiplatform.googleapis.com

# create service account
gcloud iam service-accounts create review-intelligence-sa \
  --display-name="Review Intelligence SA"

# grant Vertex AI user role
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# bind Workload Identity — review service
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/reviews-service-ksa]"

# bind Workload Identity — recommendations service
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/recommendations-service-ksa]"

# annotate existing kubernetes service accounts
kubectl annotate serviceaccount reviews-service-ksa \
  iam.gke.io/gcp-service-account=review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  -n group8

kubectl annotate serviceaccount recommendations-service-ksa \
  iam.gke.io/gcp-service-account=review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  -n group8
```

## Building and Deploying

```bash
# apply updated configmap first
kubectl apply -f k8s/00-configmap.yaml

# rebuild and push review service
docker build -t jrcarrasqueira/review-system:v2.0 ./review-system
docker push jrcarrasqueira/review-system:v2.0
kubectl set image deployment/reviews-service \
  reviews-service=jrcarrasqueira/review-system:v2.0 -n group8

# rebuild and push recommendations service
docker build -t jrcarrasqueira/recommendations:v2.0 ./recommendations
docker push jrcarrasqueira/recommendations:v2.0
kubectl set image deployment/recommendations-service \
  recommendations-service=jrcarrasqueira/recommendations:v2.0 -n group8

# verify
kubectl rollout status deployment/reviews-service -n group8
kubectl rollout status deployment/recommendations-service -n group8
```

## Testing

### Review Service
#### REST
| Method | Endpoint | Description |
| --- | --- | --- |
| GET | /movies/{movie_id}/review-summary | Returns sentiment breakdown and top topics for a movie |

##### SwaggerUI
```
http://localhost:<review-rest-port>/docs
```

##### Postman examples

###### Post a rating with a review (triggers LLM analysis)
```
POST http://localhost:<review-rest-port>/movies/1/ratings
Content-Type: application/json

{
  "user_id": 1,
  "rating": 4.0,
  "review": "Great cinematography and a gripping plot, though the pacing was slow in the second act."
}
```

###### Get review summary for a movie
```
GET http://localhost:<review-rest-port>/movies/1/review-summary
```

Expected response:
```json
{
  "movie_id": 1,
  "total_reviews": 1,
  "sentiment_breakdown": { "positive": 1 },
  "top_topics": ["cinematography", "plot", "pacing"]
}
```

### Recommendations Service
#### REST
| Method | Endpoint | Description |
| --- | --- | --- |
| GET | /recommendations/{user_id}/explained | Returns top-5 recommendations with a plain-language explanation per movie |

##### Postman examples

###### Get explained recommendations
```
GET http://localhost:<recommendation-rest-port>/recommendations/1/explained
```

Expected response:
```json
[
  {
    "movie_id": 356,
    "title": "Forrest Gump",
    "explanation": "Recommended because you enjoy Drama and have highly rated similar character-driven films."
  },
  ...
]
```
