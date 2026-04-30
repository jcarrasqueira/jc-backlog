# CC2526 — Phase 6
*Joana Carrasqueira, 64414*  
*branch: jcarrasqueira*

---

## Plan for Phase 7: LLM Integration into Existing Microservices

### Overview

This phase extends the two existing microservices — **Review Service** and **Recommendations Service** — with LLM-powered capabilities using **Google Cloud Vertex AI (Gemini 1.5 Flash)**. Rather than introducing a separate service, the LLM features are added directly to the services that already own the relevant data and logic, keeping the architecture simple and avoiding unnecessary operational overhead.

Authentication to Vertex AI is handled through **GKE Workload Identity**, meaning no API keys are stored anywhere — the pods acquire GCP credentials automatically at runtime from the GKE metadata server.

This work implements the **BC5. Smart Intelligent Review System** business capability and extends **UC4. Sentiment and Topic Dashboard by User Segment** from Phase 1.

---

## Use Cases

### UC4. Sentiment and Topic Dashboard (Review Service extension)

- **Actor:** Studios, production companies, and marketing teams.
- **Problem:** Large volumes of free-text reviews are hard to interpret quickly. Stakeholders need a fast, structured summary of sentiment and recurring topics per movie without reading every review.
- **Description:**
  1. A consumer calls `GET /movies/{movie_id}/review-summary` on the Review Service.
  2. The service fetches the existing reviews for that movie from its own database.
  3. The review texts are batched into a single prompt and sent to **Gemini 1.5 Flash** via the Vertex AI Python SDK, requesting: overall sentiment, a summary of what reviewers liked, a summary of criticisms, and up to 5 recurring topics.
  4. The structured JSON response is returned to the caller.

### UC-NEW. Natural Language Recommendation Explanation (Recommendations Service extension)

- **Actor:** Registered user.
- **Problem:** The recommendation algorithm returns a ranked list of movies with no human-readable explanation, reducing user trust and engagement.
- **Description:**
  1. A user calls `GET /users/{user_id}/recommendations/explained` on the Recommendations Service.
  2. The service runs the existing scoring algorithm to obtain the top-5 recommendations and their scoring metadata (matched genres, reference movies, score breakdown).
  3. The metadata for all 5 movies is sent to Gemini in a single batched prompt requesting one plain-language explanation per movie.
  4. The enriched list — movie title + explanation — is returned to the caller.

---

## Functional Requirements

### FR-LLM1. Review Summary Generation (Review Service)
- The system must expose `GET /movies/{movie_id}/review-summary` returning a structured summary of existing reviews.
- If fewer than 3 reviews with non-empty text exist for the movie, the endpoint must return a graceful fallback message instead of calling the LLM.
- The response must include: `sentiment` (positive / negative / mixed), `liked_summary` (string), `criticism_summary` (string or null), `topics` (list of up to 5 strings).
- Review texts must not be persisted beyond the scope of the request — the LLM call is stateless.

### FR-LLM2. Recommendation Explanation (Recommendations Service)
- The system must expose `GET /users/{user_id}/recommendations/explained` returning the existing top-5 list enriched with one explanation string per movie.
- If the user has no recommendations (cold-start), the response must reflect this gracefully without calling the LLM.
- All 5 explanations must be generated in a single Vertex AI call to minimise latency and token cost.

### FR-LLM3. GCP-Native Authentication via Workload Identity
- Both services must authenticate to Vertex AI using GCP Service Accounts bound to their respective Kubernetes Service Accounts via Workload Identity Federation.
- No API keys or JSON key files may be stored in Kubernetes Secrets or committed to the repository.

### FR-LLM4. Graceful Degradation
- If Vertex AI is unavailable or returns an error, the affected endpoint must return HTTP 503 with a clear error message.
- A configurable timeout (default: 15 s) must be applied to all Vertex AI calls.

---

## Non-Functional Requirements

### NFR1. Minimal Architectural Footprint
- No new microservice is introduced. The LLM capability is added as new endpoints within the existing Review Service and Recommendations Service, reusing their existing Deployments, Docker images, and Kubernetes manifests.
- A shared `llm_client.py` module is added to each service's codebase — a small, self-contained Vertex AI wrapper.

### NFR2. Cost Efficiency (FinOps)
- **Gemini 1.5 Flash** is selected for its low per-token cost and the **Vertex AI free tier** (up to 1 500 requests/day), making it suitable for the scale of this project.
- Prompts are kept concise: review texts are truncated to 200 characters each and capped at the 20 most recent reviews per request.
- No additional pod replicas or resource increases are needed — the LLM calls are lightweight HTTP requests that add negligible CPU/memory load to the existing pods.

### NFR3. Security — Workload Identity (zero secrets)
- A dedicated GCP Service Account (`review-intelligence-sa`) is created with only `roles/aiplatform.user` (least privilege).
- Both the Review Service KSA and the Recommendations Service KSA are annotated to bind to this GCP Service Account via Workload Identity — no key file is ever created.

### NFR4. Observability
- The new endpoints follow the same structured JSON logging pattern already in place in both services, so Google Cloud Logging indexes them automatically.

---

## Technical Architecture

### Changes to Existing Components

| Service | New endpoint | Change |
|---|---|---|
| Review Service (:8003) | `GET /movies/{movie_id}/review-summary` | New endpoint + `llm_client.py` module |
| Recommendations Service (:8004) | `GET /users/{user_id}/recommendations/explained` | New endpoint + `llm_client.py` module |

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

    RS -->|GET /movies/{id}/review-summary\nnew endpoint| RS
    RS -->|Vertex AI SDK\nWorkload Identity| VAI[Vertex AI\nGemini 1.5 Flash]

    REC -->|GET /users/{id}/recommendations/explained\nnew endpoint| REC
    REC -->|Vertex AI SDK\nWorkload Identity| VAI

    RS --> DB[(PostgreSQL)]
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

### New Files per Service

```
review-system/
└── llm_client.py              # Vertex AI SDK wrapper, review summary prompt

recommendations/
└── llm_client.py              # Vertex AI SDK wrapper, explanation prompt

k8s/
└── 11-workload-identity.yaml  # KSA annotations for both services (or inline in existing manifests)
```

No new Dockerfiles, no new Kubernetes Deployments.

---

## Deployment Plan

### 1. Enable the Vertex AI API

```bash
gcloud services enable aiplatform.googleapis.com
```

### 2. Create the GCP Service Account and grant permissions

```bash
gcloud iam service-accounts create review-intelligence-sa \
  --display-name="Review Intelligence Service Account"

gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"
```

### 3. Bind Workload Identity to both existing KSAs

```bash
# Review Service KSA
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/reviews-service-ksa]"

# Recommendations Service KSA
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/recommendations-service-ksa]"
```

### 4. Annotate existing Kubernetes Service Accounts

Add the annotation to both existing KSA manifests (or patch inline):

```yaml
metadata:
  annotations:
    iam.gke.io/gcp-service-account: review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

```bash
kubectl apply -f k8s/11-workload-identity.yaml
```

### 5. Rebuild and redeploy the two services

```bash
docker build -t jrcarrasqueira/review-system:v2.0 ./review-system
docker push jrcarrasqueira/review-system:v2.0

docker build -t jrcarrasqueira/recommendations:v2.0 ./recommendations
docker push jrcarrasqueira/recommendations:v2.0

kubectl rollout restart deployment/reviews-service -n group8
kubectl rollout restart deployment/recommendations-service -n group8
```

### 6. Verify

```bash
kubectl rollout status deployment/reviews-service -n group8
kubectl rollout status deployment/recommendations-service -n group8

# Test the new endpoints via port-forward
kubectl port-forward svc/reviews-service 8003:8003 -n group8
curl http://localhost:8003/movies/1/review-summary

kubectl port-forward svc/recommendations-service 8004:8004 -n group8
curl http://localhost:8004/users/1/recommendations/explained
```

---

## Implementation Notes

### Vertex AI SDK usage (`llm_client.py`)

```python
import vertexai
from vertexai.generative_models import GenerativeModel

vertexai.init(project=PROJECT_ID, location=REGION)
model = GenerativeModel("gemini-1.5-flash")

response = model.generate_content(prompt)
return response.text
```

When running inside a GKE pod with Workload Identity, `vertexai.init()` resolves credentials automatically from the GKE metadata server — no key file or environment variable needed.

### LLM prompt design — review summary

```
You are a movie review analyst. Given the following user reviews, return a JSON object
with exactly these keys:
- "sentiment": one of "positive", "negative", or "mixed"
- "liked_summary": 2-3 sentences on what reviewers appreciated
- "criticism_summary": 2-3 sentences on what reviewers criticised (or null if none)
- "topics": list of up to 5 recurring topic strings

Reviews:
<review_1>
<review_2>
...

Respond with only valid JSON and nothing else.
```

### LLM prompt design — recommendation explanation

```
You are a movie recommendation assistant. Explain in one friendly sentence why each
movie was recommended, based on the scoring context below.

User liked genres: <genres>
Reference movies: <titles>

Recommendations:
1. <title> — matched genres: <genres>, score: <score>
...

Respond with only a JSON array of strings, one explanation per movie, in the same order.
```
