# CC2526 - Group 8
Distributed movie platform built with microservices. Each service exposes a REST API and a gRPC interface, backed by a shared PostgreSQL database.

## What's new in Phase 5
Phase 5 adds Kubernetes deployment support on top of the existing local Docker Compose setup. The following changes were made:

- **`k8s/` directory** — new folder containing all Kubernetes manifests:
    - `00-configmap.yaml` — non-sensitive configuration (DB host/port/name, admin username, token expiry, gRPC URLs)
    - `01-secret.yaml` — sensitive values (DB password, DB connection URL, JWT secret, admin password)
    - `02-postgres.yaml` — PostgreSQL 15 Deployment + ClusterIP Service, with a readiness probe to gate dependent workloads
    - `03-populate-db-phase5.yaml` — Kubernetes Job that seeds tables for the microservices, such as ratings, user_preferences and user_reference_movies
    - `09-reviews-service.yaml` — Review system microservice Deployment + ClusterIP Service (REST :8003, gRPC :50055)
    - `08-movies-service.yaml` — Movies microservice Deployment + ClusterIP Service (REST :8004, gRPC :50056)
- Services are exposed internally via **ClusterIP** only — no ports are exposed directly to the internet without an Ingress/Gateway
- Environment is fully driven by ConfigMap and Secret references — no hardcoded values in the pod specs
- Docker images were built and published to Docker Hub for use in the Kubernetes manifests

## Cloud Deployment
### Prerequisites
- Ensure in to enable kubernetes with: 
```
gcloud services enable container.googleapis.com
```
- A running GKE cluster with `kubectl` configured to point at it:
   - cluster applied:
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

- to point the cluster: 
  ```
  gcloud container clusters get-credentials group8-cluster --zone europe-west1-b
  ``` 
  
- A dedicated namespace created for this project:

```shell
kubectl create namespace group8
kubectl config set-context --current --namespace=group8
```

### Apply the Manifests in Order
```shell
kubectl apply -f k8s/00-configmap.yaml
kubectl apply -f k8s/01-secret.yaml
kubectl apply -f k8s/02-postgres.yaml
```

Wait for PostgreSQL to become ready before continuing:

```shell
kubectl wait --for=condition=Ready pod -l app=postgres --timeout=120s
```

Then run the database population job:

```shell
kubectl apply -f k8s/03-populate-db-phase5.yaml
```

Wait for job to complete:

```shell
kubectl wait --for=condition=complete job/populate-db-phase5 --timeout=300s
```

Then deploy the microservices:

```shell
kubectl apply -f 09-reviews-service.yaml
kubectl apply -f 10-recommendations-service.yaml
```

### Network Exposure
All services are of type **ClusterIP** and are not directly reachable from outside the cluster. To access the REST APIs from outside, an Ingress or Kubernetes Gateway must be configured and pointed at the needed services.

To test locally while the pods are running, use port-forwarding:

```shell
# Users service
kubectl port-forward service/reviews-service 8080:8003

# Movies service
kubectl port-forward svc/recommendations-service 8080:8004
```

Then click on webpreview of cloudshell, remove from the link  *?authuser=0* and add *docs*, giving access to fastapi swagger to test the microservice. 
 
### Verify Everything is Running
```shell
kubectl get pods
kubectl get services
kubectl get jobs
```

### Database Test

``` 
kubectl exec -it <postgres-pod-name> -- psql -U cng8 -d movielens25m
# check tables list
\dt

# check tables
SELECT * FROM ratings LIMIT 10;
SELECT * FROM user_preferences LIMIT 10;
SELECT * FROM user_movie_references LIMIT 10;
```

