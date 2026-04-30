# CC2526 — Phase 6
*Joana Carrasqueira, 64414*  
*branch: jcarrasqueira*

---

## Plan for Phase 7: LLM Integration into Existing Microservices

### Overview

This phase extends the two existing microservices — **Review Service** and **Recommendations Service** — with LLM-powered capabilities using **Google Cloud Vertex AI (Gemini 1.5 Flash)**. No new microservice is introduced. The LLM features are added directly to the services that already own the relevant data and logic, keeping the architecture simple and avoiding unnecessary operational overhead.

Authentication to Vertex AI is handled through **GKE Workload Identity**, meaning no API keys are stored anywhere — the pods acquire GCP credentials automatically at runtime from the GKE metadata server.

This work implements the **BC5. Smart Intelligent Review System** business capability and extends **UC4. Sentiment and Topic Dashboard by User Segment** from Phase 1.

---

## Use Cases

### UC4. Sentiment and Topic Dashboard (Review Service extension)

- **Actor:** Studios, production companies, and marketing teams.
- **Problem:** Large volumes of free-text reviews are hard to interpret quickly. Stakeholders need a fast, structured summary of sentiment and recurring topics per movie without reading every review.
- **Description:**
  1. When a user submits or updates a rating with a non-empty review text, the Review Service calls Gemini to analyse the text.
  2. The result — a sentiment label and a list of topics — is persisted into the `review_sentiment` and `rating_topics` tables already defined in the database schema.
  3. A consumer calls `GET /movies/{movie_id}/review-summary` on the Review Service.
  4. The service aggregates from `review_sentiment` and `rating_topics` with a plain SQL query and returns a structured JSON response. No LLM call happens on the read path.

### UC-NEW. Natural Language Recommendation Explanation (Recommendations Service extension)

- **Actor:** Registered user.
- **Problem:** The recommendation algorithm returns a ranked list of movies with no human-readable explanation, reducing user trust and engagement.
- **Description:**
  1. A user calls `GET /recommendations/{user_id}/explained` on the Recommendations Service.
  2. The service runs the existing scoring algorithm to obtain the top-5 recommendations and their metadata (matched genres, reference movies, score breakdown).
  3. The metadata for all 5 movies is sent to Gemini in a single batched prompt requesting one plain-language explanation per movie.
  4. The enriched list — movie title + explanation — is returned to the caller.

---

## Functional Requirements

### FR-LLM1. Review Summary Generation (Review Service)
- The system must expose `GET /movies/{movie_id}/review-summary` returning a structured summary of existing reviews.
- If no analysed reviews exist for the movie yet, the endpoint must return a 404 with a clear message instead of calling the LLM.
- The response must include: `sentiment_breakdown` (counts per label), `top_topics` (list of up to 5 strings), `total_reviews` (int).
- Review texts must not be persisted beyond the scope of the LLM call — analysis is stateless.

### FR-LLM2. Recommendation Explanation (Recommendations Service)
- The system must expose `GET /recommendations/{user_id}/explained` returning the existing top-5 list enriched with one explanation string per movie.
- If the user has no recommendations (cold-start), the response must return an empty list gracefully without calling the LLM.
- All explanations must be generated in a single Vertex AI call to minimise latency and token cost.

### FR-LLM3. GCP-Native Authentication via Workload Identity
- Both services must authenticate to Vertex AI using GCP Service Accounts bound to their respective Kubernetes Service Accounts via Workload Identity Federation.
- No API keys or JSON key files may be stored in Kubernetes Secrets or committed to the repository.

### FR-LLM4. Graceful Degradation
- LLM failures must never break the rating creation response. If Vertex AI is unavailable, the rating is saved normally and analysis is skipped silently with a logged warning.
- A configurable timeout (default: 15 s) must be applied to all Vertex AI calls.

---

## Non-Functional Requirements

### NFR1. Minimal Architectural Footprint
- No new microservice, no new Docker image, no new Kubernetes Deployment. The LLM capability is added as new endpoints and a new module (`llm_client.py`) within the existing services.

### NFR2. Cost Efficiency (FinOps)
- **Gemini 1.5 Flash** is selected for its low per-token cost and **Vertex AI free tier** (up to 1 500 requests/day), making development and testing free.
- The LLM is only called at write time, not on every read. For a movie with 10 000 ratings only the newest review triggers a call — the summary is always read from the DB.
- Review texts are truncated to 500 characters before being sent to the model, capping token usage per request.
- No additional pod replicas or resource limit increases are needed — LLM calls are lightweight outbound HTTP requests.
- Vertex AI billing is consolidated into the existing GCP project.

### NFR3. Security — Workload Identity (zero secrets)
- A dedicated GCP Service Account (`review-intelligence-sa`) is created with only `roles/aiplatform.user` — least privilege.
- Both the Review Service KSA and the Recommendations Service KSA are annotated to bind to this GCP Service Account. No JSON key file is ever created.

### NFR4. Observability
- LLM call failures are logged to stdout as structured warnings, visible in Google Cloud Logging without additional configuration.
- The new endpoints follow the same `/health` and error response patterns already established in both services.

---

## Technical Architecture

### Changes to Existing Components

| Service | New endpoint | New file |
|---|---|---|
| Review Service (:8003) | `GET /movies/{movie_id}/review-summary` | `llm_client.py` — `analyse_review(text)` |
| Recommendations Service (:8004) | `GET /recommendations/{user_id}/explained` | `llm_client.py` — `explain_recommendations(...)` |

No new Kubernetes Deployments, Services, or namespaces are required.

### New Dependency

| Dependency | How it is accessed | Protocol |
|---|---|---|
| Vertex AI — Gemini 1.5 Flash | `<region>-aiplatform.googleapis.com` (GCP-internal) | HTTPS via Vertex AI Python SDK + Workload Identity |

### Architecture Diagram

```mermaid
graph TD
    Client([External Client]) -->|REST :8003| RS[Review Service]
    Client -->|REST :8004| REC[Recommendations Service]

    RS -->|POST/PUT rating with review\ntriggers at write time| VAI[Vertex AI\nGemini 1.5 Flash]
    VAI -->|sentiment + topics| RS
    RS -->|persists to| DB[(PostgreSQL\nreview_sentiment\nrating_topics)]

    RS -->|GET /movies/{id}/review-summary\naggregates from DB — no LLM| DB

    REC -->|GET /recommendations/{id}/explained\ncalls LLM once at read time| VAI
    REC --> DB
    REC -->|GetUserRatings gRPC :50055| RS

    subgraph GKE — namespace: group8
        RS
        REC
        DB
    end

    subgraph GCP Managed
        VAI
    end
```

### New and Modified Files

```
review-system/
├── llm_client.py              # new — Vertex AI wrapper, analyse_review()
├── ratings.py                 # modified — _persist_llm_analysis helper + hook in
│                              #   create_rating and update_rating + new summary endpoint
├── config.py                  # modified — add ReviewSentimentTable, TopicTable, RatingTopicTable ORM models
└── requirements.txt           # modified — add google-cloud-aiplatform

recommendations/
├── llm_client.py              # new — Vertex AI wrapper, explain_recommendations()
├── recommendations.py         # modified — add /recommendations/{user_id}/explained endpoint
└── requirements.txt           # modified — add google-cloud-aiplatform

k8s/
├── 00-configmap.yaml          # modified — add GCP_PROJECT_ID and GCP_REGION
├── 09-reviews-service.yaml    # modified — add env refs + serviceAccountName
└── 10-recommendations-service.yaml  # modified — add env refs + serviceAccountName
```

---

## Deployment Plan

### 1. Enable the Vertex AI API

```bash
gcloud services enable aiplatform.googleapis.com
```

### 2. Create the GCP Service Account and bind Workload Identity

```bash
# create service account
gcloud iam service-accounts create review-intelligence-sa \
  --display-name="Review Intelligence SA"

# grant only Vertex AI user role (least privilege)
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# bind to review service KSA
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/reviews-service-ksa]"

# bind to recommendations service KSA
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/recommendations-service-ksa]"
```

### 3. Annotate the existing Kubernetes Service Accounts

```bash
kubectl annotate serviceaccount reviews-service-ksa \
  iam.gke.io/gcp-service-account=review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  -n group8

kubectl annotate serviceaccount recommendations-service-ksa \
  iam.gke.io/gcp-service-account=review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  -n group8
```

### 4. Update the ConfigMap and Kubernetes manifests

Add to `k8s/00-configmap.yaml`:
```yaml
GCP_PROJECT_ID: "<PROJECT_ID>"
GCP_REGION: "europe-west1"
```

Add to both service Deployment env sections in `k8s/09-reviews-service.yaml` and `k8s/10-recommendations-service.yaml`:
```yaml
- name: GCP_PROJECT_ID
  valueFrom:
    configMapKeyRef:
      name: group8-config
      key: GCP_PROJECT_ID
- name: GCP_REGION
  valueFrom:
    configMapKeyRef:
      name: group8-config
      key: GCP_REGION
```

Also add `serviceAccountName: reviews-service-ksa` (or `recommendations-service-ksa`) to each Deployment's pod spec.

### 5. Rebuild and redeploy both services

```bash
kubectl apply -f k8s/00-configmap.yaml

docker build -t jrcarrasqueira/review-system:v2.0 ./review-system
docker push jrcarrasqueira/review-system:v2.0
kubectl set image deployment/reviews-service \
  reviews-service=jrcarrasqueira/review-system:v2.0 -n group8

docker build -t jrcarrasqueira/recommendations:v2.0 ./recommendations
docker push jrcarrasqueira/recommendations:v2.0
kubectl set image deployment/recommendations-service \
  recommendations-service=jrcarrasqueira/recommendations:v2.0 -n group8

kubectl rollout status deployment/reviews-service -n group8
kubectl rollout status deployment/recommendations-service -n group8
```

---

## Implementation Notes

### Vertex AI SDK usage (`llm_client.py` — both services)

```python
import vertexai
from vertexai.generative_models import GenerativeModel
import os

vertexai.init(project=os.getenv("GCP_PROJECT_ID"), location=os.getenv("GCP_REGION", "europe-west1"))
_model = GenerativeModel("gemini-1.5-flash")
```

When running inside a GKE pod with Workload Identity, `vertexai.init()` resolves credentials automatically from the GKE metadata server — no key file or environment variable needed for auth.

### LLM prompt design — review analysis (Review Service)

```
You are a movie review analyst. Analyse the following review and return a JSON object
with exactly two keys:
- "sentiment": one of "positive", "negative", or "neutral"
- "topics": a list of up to 5 short topic strings (e.g. "acting", "plot", "pacing")

Review:
<review text, truncated to 500 chars>

Respond with only valid JSON and nothing else.
```

### LLM prompt design — recommendation explanation (Recommendations Service)

```
You are a movie recommendation assistant. Explain in one short friendly sentence why
each movie was recommended to a user with the following profile.

Liked genres: <genres>
Reference movies they love: <titles>

Recommendations:
1. <title> (genres: <genres>, score: <score>)
...

Respond with only a JSON array of strings, one explanation per movie, in the same order.
```

### Write-time vs read-time LLM calls

The Review Service calls the LLM at **write time** only (on rating create/update) and stores the result. `GET /movies/{movie_id}/review-summary` is a pure DB aggregation — fast and cheap regardless of how many reviews exist. The Recommendations Service calls the LLM at **read time** for the explanation endpoint, since explanations are dynamic per-user and cannot be pre-computed.
