inside grpc
```.env
REST_URL="http:review-service:8002"
REST_URL_LOCAL="http://localhost:8000"
GRPC_PORT=50052
GRPC_URL="review-service:50052"
```

inside review-system
```
DB_URL_LOCAL=postgresql://cng8:m8cloud@localhost:5432/movielens25m
DB_URL=postgresql://cng8:m8cloud@postgres:5444/movielens25m
```

inside prpject
```
DB_USER=cng8
DB_PASSWORD=m8cloud
DB_NAME=movielens25m
DB_HOST=postgres
DB_PORT=5444
DB_URL=postgresql://cng8:m8cloud@postgres:5432/movielens25m
REVIEW_SERVICE_PORTS=8002:8002
RECOMMENDATIONS_SERVICE_PORTS=8003:8003
```

```
# Database configuration
DB_USER=cng8
DB_PASSWORD=m8cloud
DB_NAME=movielens25m
DB_HOST=postgres
DB_PORT=5444
DB_URL=postgresql://cng8:m8cloud@postgres:5432/movielens25m
# Review service
REVIEW_SERVICE_PORTS=8002:8002
REVIEW_GRPC_PORTS=50052:50052
REVIEW_GRPC_PORT=50052
REVIEW_REST_PORT=8002
REVIEW_REST_URL="http://review-service:8002"
REVIEW_GRPC_PORT=50052
REVIEW_GRPC_URL="review-service:50052"
# Recommendation service
RECOMMENDATIONS_SERVICE_PORTS=8003:8003
```