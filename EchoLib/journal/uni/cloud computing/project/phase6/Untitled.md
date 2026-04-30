*Joana Carrasqueira, 64414* *branch: jcarrasqueira*

# Cloud Computing — Phase 6: Non-Functional Requirements & Technical Architecture

## 1. Introduction & Proposed Improvement
In Phase 4 and 5, the **Review Service** and **Recommendation Service** were implemented and deployed to a Kubernetes cluster. For Phase 6, the goal is to introduce a cloud-native Data Science improvement: **Large Language Model (LLM) Integration**. 

Instead of relying solely on strict deterministic weight-based algorithms, the system will be augmented with an LLM to provide:
1. **Automated Sentiment & Tag Extraction:** Asynchronously analyzing the text of user reviews to extract nuanced sentiments and hidden tags without blocking the user's API request.
2. **Conversational Recommendations:** Generating natural language explanations for *why* a user was recommended a specific top-5 movie list, combining their explicit preferences with dynamic text generation.

To ensure this remains cloud-native and highly performant, the architecture will introduce an **Event-Driven pattern** (Pub/Sub) for the async processing.

---

## 2. Use Cases
The existing use cases (UC1, UC7, UC10) are expanded with the following:

| **Use Case** | **Description** |
| :--- | :--- |
| **UC11. Conversational Recommendation Insights** | A user requests their personalized movie recommendations. The system not only returns the top 5 movies based on weights but also provides a dynamically generated natural language summary explaining the recommendations based on the user's history. |
| **UC12. Async Review Sentiment Analysis** | A user submits a text review for a movie. The system accepts the review immediately. In the background, an LLM analyzes the text, extracts implicit tags (e.g., "visually stunning", "slow burn"), calculates a sentiment score, and updates the user's profile metadata. |

---

## 3. Requirements

### Functional Requirements
| **Requirement** | **Description** | **Related UC** |
| :--- | :--- | :--- |
| **FR25. Recommendation Explanation** | The Recommendation Service must query the LLM to generate a short, personalized text paragraph explaining the recommended movies. | UC11 |
| **FR26. Async Text Analysis** | The system must automatically extract tags and a sentiment score (Positive/Neutral/Negative) from newly submitted text reviews. | UC12 |

### Non-Functional Requirements
| **Requirement** | **Description** |
| :--- | :--- |
| **NFR1. Asynchronous Processing (Event-Driven)** | Review submission must not block waiting for the LLM analysis. The Review Service must publish an event to a message broker (e.g., Google Cloud Pub/Sub or RabbitMQ), which the LLM worker consumes. |
| **NFR2. Scalability (HPA)** | The LLM Processing worker must be decoupled and scale independently based on the queue length of pending reviews, using Kubernetes Horizontal Pod Autoscaler (HPA). |
| **NFR3. Cost-Efficiency & Resource Limits** | Due to the heavy computational nature of LLMs, the deployed model must be lightweight (e.g., a quantized Llama 3 8B via Ollama/vLLM, or offloaded to a managed cloud API like GCP Vertex AI) to prevent massive cloud billing costs. Strict Kubernetes resource requests and limits must be enforced. |
| **NFR4. Fault Tolerance (Retry Pattern)** | If the LLM service is temporarily unavailable, the message broker must queue the review events and retry processing with exponential backoff. |

---

## 4. Technical Architecture

The technical architecture shifts from purely synchronous REST/gRPC calls to a hybrid synchronous/asynchronous system.

### Components:
1. **API Gateway / Ingress:** Routes external traffic to the correct microservices.
2. **Review Service:** Handles CRUD for ratings/reviews. Now acts as a **Publisher**.
3. **Recommendation Service:** Handles movie scoring. Makes synchronous calls to the LLM for explanations.
4. **Message Broker (Pub/Sub):** Handles the event queue for new reviews (Topic: `review.created`).
5. **LLM Processing Service (Worker):** Consumes messages from the broker, runs inference (prompting the LLM for sentiment/tags), and updates the Review database via gRPC. 
6. **PostgreSQL Database:** Shared or logically separated database holding user preferences and reviews.

### Workflows:
* **Synchronous Flow (Recommendations):** User -> Ingress -> Recommendation Service -> Calculates Top 5 -> Sends Top 5 + User Preferences to LLM Service -> Returns JSON + Natural Language Explanation to User.
* **Asynchronous Flow (Reviews):**
    User -> Ingress -> Review Service -> Saves base review & returns `201 Created` to User. 
    Review Service -> Publishes `review.created` event -> Message Broker -> LLM Worker consumes event -> Analyzes text -> Updates Review DB with tags/sentiment.

---

## 5. Deployment Plan

For Phase 7, the deployment to the existing GKE cluster will be updated with the following steps:

1. **Message Broker Deployment:**
   * Deploy RabbitMQ to Kubernetes (using a StatefulSet or Helm chart), OR provision a Google Cloud Pub/Sub topic and service account credentials.
2. **LLM Service Deployment:**
   * Create a new Docker image for the LLM Processing Service (FastAPI + LLM client).
   * Define Kubernetes manifests (`14-llm-service.yaml`) including Deployment and ClusterIP Service.
   * *Cost Optimization Note:* To avoid expensive GPU node pools on GKE, the LLM service can be configured to act as a proxy that calls GCP's Vertex AI API, keeping the cluster lightweight while still utilizing state-of-the-art LLMs.
3. **Updates to Existing Services:**
   * Update the **Review Service** deployment to inject Message Broker connection strings via Kubernetes Secrets/ConfigMaps.
   * Update the **Recommendation Service** deployment to communicate with the new LLM Service.
4. **Autoscaling:**
   * Implement `HorizontalPodAutoscaler` (HPA) for the LLM Worker based on CPU utilization or external metrics (queue depth).