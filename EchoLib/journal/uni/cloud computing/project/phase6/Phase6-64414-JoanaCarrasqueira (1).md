# CC2526 — Phase 6
*Joana Carrasqueira, 64414*  
*branch: jcarrasqueira*

---

## Plan for Phase 7: LLM-Powered Review Intelligence Service

### Overview

This phase introduces a new microservice — the **Review Intelligence Service** — that integrates a Large Language Model (LLM) hosted on **Google Cloud Vertex AI (Gemini 1.5 Flash)** to add AI-driven capabilities on top of the existing Review and Recommendation services. The service implements the **BC5. Smart Intelligent Review System** business capability and **UC4. Sentiment and Topic Dashboard by User Segment** use case defined in Phase 1.

Using Vertex AI rather than an external LLM provider is a deliberate cloud-native choice: authentication is handled through **GKE Workload Identity** (no API keys ever stored), network traffic stays within GCP's private backbone, and billing is consolidated under the same GCP project as the rest of the cluster.

The service will be deployed as a containerised workload on the existing GKE cluster (`group8-cluster`, namespace `group8`), consistent with the architecture established in previous phases.

---

## Use Cases

### UC4. Sentiment and Topic Dashboard by User Segment (Extended)

- **Actor:** Studios, production companies, and marketing teams.
- **Problem:** Large volumes of free-text reviews are hard to summarise. Stakeholders need fast insight into sentiment and recurring topics per movie, without reading every review manually.
- **Description:**
  1. A consumer calls `GET /movies/{movie_id}/review-summary` on the Review Intelligence Service.
  2. The service fetches all existing reviews for that movie from the Review Service REST API (`GET /movies/{movie_id}/ratings`).
  3. The collected review texts are batched into a single prompt and sent to **Gemini 1.5 Flash** via the Vertex AI Python SDK, requesting: overall sentiment (positive / negative / mixed), a 2–3 sentence summary of what reviewers liked, a 2–3 sentence summary of what reviewers criticised, and a list of up to 5 recurring topics.
  4. The structured response is parsed and returned to the caller as JSON.

### UC-NEW. Natural Language Recommendation Explanation

- **Actor:** Registered user.
- **Problem:** The existing recommendation algorithm returns a list of movies but provides no explanation for *why* each title was recommended, reducing trust and engagement.
- **Description:**
  1. A user calls `GET /users/{user_id}/recommendations/explained` on the Review Intelligence Service.
  2. The service calls the Recommendations Service REST API to retrieve the user's top-5 recommendations along with scoring metadata (genre weights, reference movies, rating history).
  3. The scoring context for all 5 movies is sent to Gemini in a single batched prompt requesting one human-readable explanation per movie.
  4. The enriched list — movie title + explanation — is returned to the caller.

---

## Functional Requirements

### FR-LLM1. Review Summary Generation
- The system must accept a `movie_id` and return a structured summary derived from existing textual reviews.
- If fewer than 3 reviews with non-empty text exist, the system must return a meaningful fallback message (e.g. *"Not enough reviews to generate a summary"*) rather than calling the LLM.
- The response must include: `sentiment` (positive / negative / mixed), `liked_summary` (string), `criticism_summary` (string or null), `topics` (list of up to 5 strings).
- The service must not persist raw review texts beyond the scope of a single request (stateless processing).

### FR-LLM2. Recommendation Explanation
- The system must accept a `user_id` and return the same top-5 recommendations enriched with a one-sentence explanation per movie.
- If the user has no recommendations (cold-start), the response must reflect this gracefully.
- Explanations must be generated in a single batched Vertex AI call to minimise latency and cost.

### FR-LLM3. GCP-Native Authentication via Workload Identity
- The service must authenticate to Vertex AI using a **GCP Service Account** bound to the Kubernetes Service Account via Workload Identity Federation.
- No API keys or service account JSON key files may be stored in Kubernetes Secrets or committed to the repository.

### FR-LLM4. Graceful Degradation
- If Vertex AI is unavailable or returns an error, the service must return HTTP 503 with a clear error message rather than propagating a 500.
- The service must apply a configurable request timeout (default: 15 s) on all Vertex AI calls.

---

## Non-Functional Requirements

### NFR1. Stateless, Cloud-Native Microservice
- Packaged as a Docker container; deployed as a Kubernetes Deployment in namespace `group8`.
- No local state — all data is fetched at request time from sibling services via their ClusterIP addresses.

### NFR2. Cost Efficiency (FinOps)
- **Gemini 1.5 Flash** is selected because it is Google's lowest-cost generally available multimodal model, and it is covered by the **Vertex AI free tier** (up to 1 500 requests/day at no charge), making it ideal for development and testing.
- Prompts are designed to be concise: review texts are truncated to 200 characters each and only the 20 most recent reviews per movie are included, capping input token usage per request.
- The pod runs as a single replica with minimal resource requests (`cpu: 100m`, `memory: 128Mi`) since all heavy computation is offloaded to Vertex AI.
- Vertex AI billing is consolidated into the existing GCP project — no separate external API account or secret is needed.

### NFR3. Security — Workload Identity (zero secrets)
- A dedicated GCP Service Account (`review-intelligence-sa`) is created with only the `roles/aiplatform.user` IAM role — least privilege.
- The Kubernetes Service Account is annotated to bind to this GCP Service Account via Workload Identity, so the pod acquires credentials automatically from the GKE metadata server at runtime.
- No JSON key file is ever created or stored anywhere.

### NFR4. Observability
- The service exposes a `/health` endpoint consistent with the other microservices.
- Structured JSON logs are written to stdout so that **Google Cloud Logging** indexes them automatically without additional configuration.

---

## Technical Architecture

### New Component

| Component | Type | Protocol | Port |
|---|---|---|---|
| `review-intelligence-service` | FastAPI microservice | REST | 8005 |

### Dependencies

| Dependency | How it is accessed | Protocol |
|---|---|---|
| Review Service | `reviews-service:8003` (internal ClusterIP) | REST (HTTP) |
| Recommendations Service | `recommendations-service:8004` (internal ClusterIP) | REST (HTTP) |
| Vertex AI — Gemini 1.5 Flash | `<region>-aiplatform.googleapis.com` (GCP-internal) | HTTPS via Vertex AI Python SDK + Workload Identity |

### Architecture Diagram

```mermaid
graph TD
    Client([External Client]) -->|REST :8005| RIS[Review Intelligence Service]

    RIS -->|GET /movies/{id}/ratings\nREST :8003| RS[Review Service]
    RIS -->|GET /users/{id}/recommendations\nREST :8004| REC[Recommendations Service]
    RIS -->|Vertex AI SDK\nWorkload Identity| VAI[Vertex AI\nGemini 1.5 Flash]

    RS --> DB[(PostgreSQL)]
    REC --> DB

    subgraph GKE — namespace: group8
        RIS
        RS
        REC
        DB
    end

    subgraph GCP Managed
        VAI
    end
```

### New Files / Modules

```
review-intelligence/
├── dockerfile
├── .dockerignore
├── requirements.txt
├── start.sh
├── config.py                  # env vars, GCP project/region, httpx clients
├── llm_client.py              # Vertex AI SDK wrapper (abstracted behind interface)
└── review_intelligence.py     # FastAPI app, endpoints

k8s/
├── 11-review-intelligence-ksa.yaml      # Kubernetes ServiceAccount with Workload Identity annotation
└── 12-review-intelligence-service.yaml  # Deployment + ClusterIP Service
```

---

## Deployment Plan

### 1. Enable the Vertex AI API in GCP

```bash
gcloud services enable aiplatform.googleapis.com
```

### 2. Create and configure the GCP Service Account

```bash
# Create the GCP service account
gcloud iam service-accounts create review-intelligence-sa \
  --display-name="Review Intelligence Service Account"

# Grant only the Vertex AI user role (least privilege)
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# Bind the Kubernetes Service Account to the GCP Service Account via Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/review-intelligence-ksa]"
```

### 3. Apply the Kubernetes Service Account manifest

`k8s/11-review-intelligence-ksa.yaml` annotates the KSA with the GCP service account so GKE's Workload Identity controller resolves credentials automatically:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: review-intelligence-ksa
  namespace: group8
  annotations:
    iam.gke.io/gcp-service-account: review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com
```

```bash
kubectl apply -f k8s/11-review-intelligence-ksa.yaml
```

### 4. Build and publish the Docker image

```bash
docker build -t jrcarrasqueira/review-intelligence:v1.0 ./review-intelligence
docker push jrcarrasqueira/review-intelligence:v1.0
```

### 5. Deploy the service

The Deployment in `k8s/12-review-intelligence-service.yaml` references `serviceAccountName: review-intelligence-ksa` so the pod inherits Workload Identity credentials automatically — no further configuration needed.

```bash
kubectl apply -f k8s/12-review-intelligence-service.yaml
```

### 6. Verify

```bash
kubectl get pods -n group8
kubectl port-forward svc/review-intelligence-service 8005:8005 -n group8
# open http://localhost:8005/docs
```

### Resource Configuration

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "300m"
    memory: "256Mi"
```

An HPA will be configured in Phase 7 targeting 70% CPU utilisation, consistent with the other microservices.

---

## Implementation Notes

### Vertex AI SDK usage (`llm_client.py`)

```python
import vertexai
from vertexai.generative_models import GenerativeModel

vertexai.init(project=PROJECT_ID, location=REGION)
model = GenerativeModel("gemini-1.5-flash")

response = model.generate_content(prompt)
result = response.text
```

When running inside a GKE pod with Workload Identity, `vertexai.init()` picks up credentials automatically from the GKE metadata server — no key file or environment variable needed.

### LLM prompt design — review summary

```
You are a movie review analyst. Given the following user reviews, return a JSON object with exactly these keys:
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
You are a movie recommendation assistant. Explain in one friendly sentence why each movie was recommended, based on the scoring context below.

User liked genres: <genres>
Reference movies: <titles>

Recommendations:
1. <title> — matched genres: <genres>, score: <score>
...

Respond with only a JSON array of strings, one explanation per movie, in the same order.
```

### Integration with existing services

The Review Intelligence Service reuses the existing REST interfaces of the Review Service and Recommendations Service — no changes are required to those services. This preserves the **database per service** pattern: the new microservice has no direct database access.
