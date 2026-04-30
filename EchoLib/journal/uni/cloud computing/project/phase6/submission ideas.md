Here are the two documents you requested. The first is your official Phase 6 deliverable, formatted and ready to submit. The second is your internal implementation guide, which provides the step-by-step technical instructions you will need to actually build this for Phase 7.

### Deliverable 1: Phase 6 Submission Document

Save this block as `Phase6-64414-JoanaCarrasqueira.md` and submit it.

Markdown

```
*Joana Carrasqueira, 64414* *branch: jcarrasqueira*

# Cloud Computing — Phase 6: Non-Functional Requirements & Technical Architecture

## 1. Introduction & Proposed Improvement
In previous phases, the **Review Service** and **Recommendation Service** were implemented and deployed to a Google Kubernetes Engine (GKE) cluster. [cite_start]For Phase 6, the objective is to introduce a cloud-native improvement[cite: 165]. 

[cite_start]The proposed improvement is the integration of a Large Language Model (LLM) utilizing a Backend-as-a-Service (BaaS) pattern [cite: 170] [cite_start]via Google Cloud Vertex AI, coupled with an Event-Driven architecture using Google Cloud Pub/Sub[cite: 170]. [cite_start]This enhances the system with advanced data science capabilities [cite: 171] while remaining highly cost-effective and scalable.

## 2. Use Cases
The existing use cases are expanded with the following:

**UC11. Conversational Recommendation Insights**
A user requests their personalized movie recommendations. The Recommendation Service retrieves the top 5 movies and queries the LLM to generate a natural language summary explaining *why* these movies were chosen based on the user's history and preferences.

**UC12. Async Review Sentiment Analysis**
A user submits a text review. The system accepts it immediately. In the background, an event is published, triggering an LLM analysis of the text to extract implicit tags (e.g., "visually stunning") and a sentiment score, which then updates the database.

## 3. Requirements

### Functional Requirements
**FR25. Recommendation Explanation:** The Recommendation Service must query Vertex AI to generate a short, personalized text paragraph explaining the recommended movies.
**FR26. Async Text Analysis:** The system must automatically extract tags and a sentiment score from newly submitted text reviews using an LLM.

### Non-Functional Requirements
**NFR1. Serverless AI Integration (BaaS):** The system must utilize Google Cloud Vertex AI to offload LLM computation, eliminating the need to provision expensive GPU node pools within the GKE cluster.
**NFR2. Asynchronous Processing (Event-Driven):** Review submission must not block waiting for LLM analysis. [cite_start]The Review Service must publish events to a message broker (GCP Pub/Sub)[cite: 170].
**NFR3. [cite_start]Security & Access Control:** Microservices must securely authenticate with Google Cloud services using injected Service Account credentials or Workload Identity[cite: 174].
**NFR4. [cite_start]Fault Tolerance:** If the LLM API is rate-limited, the system must implement a retry pattern for the asynchronous analysis workflow[cite: 169].

## 4. Technical Architecture
[cite_start]The technical architecture shifts from purely synchronous REST/gRPC calls to a hybrid synchronous/asynchronous system leveraging managed cloud services[cite: 175].

**Component Interactions:**
1. **API Gateway / Ingress:** Routes external traffic to the microservices.
2. **Review Service (Publisher):** Handles CRUD for ratings. Upon review creation, it saves the base data to PostgreSQL and publishes a `review.created` event to GCP Pub/Sub.
3. **Recommendation Service:** Makes synchronous REST calls to Vertex AI (Gemini model) to generate the recommendation insights before returning the final payload to the user.
4. **Pub/Sub Broker:** Google Cloud's managed message queue.
5. **Review Worker Service:** A new lightweight consumer service that listens to Pub/Sub, queries Vertex AI for sentiment/tags, and updates the PostgreSQL database via gRPC.

## 5. Deployment Plan
[cite_start]For the next phase, the deployment to the existing GKE cluster will be updated with the following steps[cite: 183]:

1. **GCP Provisioning:** Enable Vertex AI and Pub/Sub APIs in the Google Cloud Project.
2. **Security Configuration:** Generate a GCP Service Account with `Vertex AI User` and `Pub/Sub Publisher/Subscriber` roles. Create a Kubernetes Secret containing these credentials.
3. **Microservice Updates:** Implement the Google Cloud Python SDK in the Recommendation and Review services. 
4. **Worker Deployment:** Containerize and deploy the new Review Worker Service to the GKE cluster using a standard Deployment manifest.
5. **Configuration Management:** Update existing ConfigMaps to include the GCP Project ID and region variables.
```

---

### Deliverable 2: Implementation Guide for Phase 7

Keep this file for yourself. This is your roadmap for writing the code and updating your Kubernetes manifests.

Markdown

````
# Phase 7 Implementation Guide: Vertex AI & Pub/Sub

## Step 1: Google Cloud Setup
You need to enable the services in your GCP project so your code can use them.

1. Open the Google Cloud Console.
2. Ensure you are in your `group8` project.
3. Open Cloud Shell and run:
   `gcloud services enable aiplatform.googleapis.com`
   `gcloud services enable pubsub.googleapis.com`
4. Create a Pub/Sub topic and subscription:
   `gcloud pubsub topics create new-reviews`
   `gcloud pubsub subscriptions create review-worker-sub --topic=new-reviews`

## Step 2: Security & Authentication
Your Kubernetes pods need permission to call Vertex AI and Pub/Sub.

1. Create a service account in Cloud Shell:
   `gcloud iam service-accounts create group8-ai-sa`
2. Grant it permissions:
   `gcloud projects add-iam-policy-binding YOUR_PROJECT_ID --member="serviceAccount:group8-ai-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" --role="roles/aiplatform.user"`
   `gcloud projects add-iam-policy-binding YOUR_PROJECT_ID --member="serviceAccount:group8-ai-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" --role="roles/pubsub.editor"`
3. Generate a JSON key file:
   `gcloud iam service-accounts keys create key.json --iam-account=group8-ai-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com`
4. Upload this key to your Kubernetes cluster as a secret:
   `kubectl create secret generic gcp-credentials --from-file=credentials.json=key.json -n group8`

## Step 3: Python Code Implementation

### Update `requirements.txt`
Add these to both your Review and Recommendation services:
`google-cloud-aiplatform`
`google-cloud-pubsub`

### Recommendation Service (Vertex AI Call)
In your `recommendations-service` endpoints, add this logic to generate the text summary.

```python
import vertexai
from vertexai.generative_models import GenerativeModel
import os

# Initialize Vertex AI
vertexai.init(project=os.environ.get("GCP_PROJECT_ID"), location="europe-west1")

def get_llm_explanation(user_preferences, recommended_movies):
    model = GenerativeModel("gemini-1.5-flash-001")
    
    prompt = f"""
    The user likes these genres: {user_preferences}. 
    We are recommending these movies: {recommended_movies}.
    Write a 2-sentence friendly explanation of why they will love these movies.
    """
    
    response = model.generate_content(prompt)
    return response.text
````

### Review Service (Pub/Sub Publish)

When a user POSTs a new review, save it, then publish to Pub/Sub.

Python

```
from google.cloud import pubsub_v1
import json
import os

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(os.environ.get("GCP_PROJECT_ID"), "new-reviews")

def publish_review_event(review_id, text):
    data = json.dumps({"review_id": review_id, "text": text}).encode("utf-8")
    publisher.publish(topic_path, data)
```

## Step 4: Kubernetes Manifest Updates

You must tell your pods where to find the GCP credentials. Update `09-reviews-service.yaml` and `10-recommendations-service.yaml` to mount the secret you created in Step 2.

Add this under your container spec:

YAML

```
          env:
            - name: GOOGLE_APPLICATION_CREDENTIALS
              value: "/var/secrets/google/credentials.json"
            - name: GCP_PROJECT_ID
              value: "your-actual-gcp-project-id"
          volumeMounts:
            - name: gcp-secret
              mountPath: /var/secrets/google
              readOnly: true
      volumes:
        - name: gcp-secret
          secret:
            secretName: gcp-credentials
```

