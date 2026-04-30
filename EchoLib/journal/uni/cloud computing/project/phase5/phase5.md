```
gcloud container clusters create-auto test --region us-central1
```

```
gcloud container clusters get-credentials test --region us-central1
```

```
kubectl apply -f 00-configmap.yaml
kubectl apply -f 01-secret.yaml
kubectl apply -f 02-postgres.yaml

kubectl wait --for=condition=available deployment/postgres --timeout=180s

kubectl apply -f 03-populate-db-phase5.yaml

kubectl wait --for=condition=complete job/populate-db-phase5 --timeout=600s

kubectl apply -f 09-reviews-service.yaml
kubectl apply -f 10-recommendations-service.yaml

kubectl get pods
kubectl get services
```

```
gcloud container clusters delete test --region us-central1 --quiet
```




kubectl port-forward service/recommendations-service 8080:8004

1. gcloud container clusters create group8-cluster \ --zone europe-west1-b \ --num-nodes 2 \ --machine-type e2-standard-2 \ --disk-type pd-standard \ --disk-size 30 \ --enable-ip-alias \ --release-channel regular
    
2. -----------------------------------------
    
3. gcloud container clusters create group8-cluster \ --zone europe-west1-b \ --num-nodes 2 \ --machine-type e2-standard-4 \ --disk-type pd-standard \ --disk-size 50 \ --enable-ip-alias \ --release-channel regular
    
4. gcloud container clusters get-credentials group8-cluster --zone europe-west1-b
kubectl port-forward service/recommendations-service 8080:8004