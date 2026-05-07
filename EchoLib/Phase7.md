
```
# 1. Enable APIs
gcloud services enable aiplatform.googleapis.com pubsub.googleapis.com

# 2. Create Pub/Sub Topic and Subscription
gcloud pubsub topics create review-created
gcloud pubsub subscriptions create review-worker-sub --topic=review-created --ack-deadline=60

# 3. Create Service Account & Assign Roles
gcloud iam service-accounts create review-intelligence-sa --display-name="Review Intelligence SA"
PROJECT_ID=$(gcloud config get-value project)
SA_EMAIL="review-intelligence-sa@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/aiplatform.user"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/pubsub.publisher"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${SA_EMAIL}" --role="roles/pubsub.subscriber"


# Required to let the SA use the project's quota and API limits
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/serviceusage.serviceUsageConsumer"

# Provides broader access to Vertex AI resources within the project
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/aiplatform.serviceAgent"
```

# Create the GKE cluster
```
gcloud container clusters create group8-cluster \
    --zone europe-west1-b \
    --num-nodes 2 \
    --machine-type e2-standard-2 \
    --disk-type pd-standard \
    --disk-size 30 \
    --enable-ip-alias \
    --release-channel regular
```

# Get authentication credentials for kubectl
```
gcloud container clusters get-credentials group8-cluster --zone europe-west1-b
```

## 2. Namespace and Environment Configuration
We isolated our project within a dedicated namespace and apply shared configurations.

```
# Create and switch to the group8 namespace
kubectl create namespace group8
kubectl config set-context --current --namespace=group8

# Apply configuration and secrets
kubectl apply -f 00-configmap.yaml
kubectl apply -f 01-secret.yaml
```

```
kubectl create secret generic gcp-sa-secret \
  --from-file=sa-key.json=./sa-key.json \
  -n group8
```
## 3. Database Deployment and Population
The PostgreSQL database must be running before the microservices can connect.

```
# Deploy Postgres
kubectl apply -f 02-postgres.yaml
kubectl get pods --watch
# Run the database population job
kubectl apply -f 03-populate-db.yaml

# Monitor the job until status is 'Complete'
kubectl get jobs --watch
```

## 4. Microservices Deployment
Deploy the core functional services.
```
kubectl apply -f 06-reviews-service.yaml
kubectl apply -f 07-recommendations-service.yaml
kubectl apply -f 08-review-worker.yaml
```

**Note:** If a pod enters `ErrImagePull`, ensure the image path in the YAML is correct. To restart a service, you can use `kubectl delete -f <file>.yaml` and then `kubectl apply -f <file>.yaml`.

## 5. Ingress Configuration
To expose the services to the internet, we used an NGINX Ingress Controller.

### Install NGINX Controller
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/cloud/deploy.yaml

# Wait for the controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Apply Ingress Rules:
```
kubectl apply -f 12-ingress.yaml
```

## 6. Accessing the Application
Once deployed, find your **External IP**:
```
kubectl get ingress group8-ingress
```

issue in recommendations endpoints 
options:
- change rest to db connections in grpc
- add timeout to 30.0 asyncio client
- change resources:
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m" # <-- Increased from 300m
```


```
{
  "user_id": 1,
  "movie_id": 20,
  "rating": 4.5,
  "review": "The visual effects were stunning, but the acting felt flat."
}
```