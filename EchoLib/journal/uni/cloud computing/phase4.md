# Cloud Computing — Phase 4 Implementation
The microservices implement in this phase were the following:
- **Review Service** (Review system): manages user reviews, ratings, sentiment, and topic metadata 
- **Recommendation Service**: generates personalized movie recommendations based on preferences, reference movies, and genre families

Both services are fully isolated, own their respective data, and expose REST (FastAPI) and gRPC interfaces.

The system is backed by a PostgreSQL database populated via another container (*populate-db*)
## Running Locally
### Do

### 1. Download required files
Since the csv files used to populate the database are a bit heavy they must be downloaded from google drive in link:
```
https://drive.google.com/drive/folders/1yBRaUi72Y1QmUHmtBbip8_81QaxbVKey?usp=drive_link
``` 

Once downloaded the folder, put data folder with csv in path: `CC2526-Group8/db/data`

### 2. Create .env file
Create .env file in project's base folder (`CC2526-Group8`) with the structure provided in `.env.example` provided in base directory.

### 3. Build and run docker compose
```
docker compose up --build -d
``` 

With this multiple containers will be built and run:
- **postgres** which creates a container with ***postgres:15*** image with initialization files defined in `CC2526-Group8/db/init.sql`
    - only after health-check performed successfully can other containers be ran
- **populate-db** which creates a container of ***python:3.11-slim*** which runs a python script to populate the database with csv in `CC2526-Group8/db/data`.
    - only after performed successfully can the microservice containers be ran
- **review-service** which runs API (REST) and grpc of service.
- **recommendations-service** which runs API (REST) and grpc of service.

