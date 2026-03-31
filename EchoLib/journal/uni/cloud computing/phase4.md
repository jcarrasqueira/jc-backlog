# Cloud Computing — Phase 4 Implementation
The microservices implement in this phase were the following:
- **Review Service** (Review system): manages user reviews, ratings, sentiment, and topic metadata 
- **Recommendation Service**: generates personalized movie recommendations based on preferences, reference movies, and genre families

Both services are fully isolated, own their respective data, and expose REST (FastAPI) and gRPC interfaces.

The system is backed by a PostgreSQL database populated via another container (*populate-db*)
## Running Locally

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

## Testing Microservices
(After containers properly ran)

### Review Service
#### REST
| Method | Endpoint                   | Description                                   |
| ------ | -------------------------- | --------------------------------------------- |
| GET    | /ratings                   | Create or update a rating (upsert behavior)   |
| GET    | /rating                    | Filter ratings by user, movie, min/max rating |
| GET    | /ratings/{rating_id}       | Retrieve a single rating                      |
| PUT    | /ratings/{rating_id}       | Update rating fields                          |
| DELETE | /ratings/{rating_id}       | Delete a rating                               |
| POST   | /movies/{movie_id}/ratings | Create rating for a specific movie            |
| GET    | /movies/{movie_id}/ratings | Get ratings for a movie                       |
| GET    | /users/{user_id}/ratings   | Get ratings for a user                        
##### SwagerUI
```
http://localhost:<review-rest-port>/docs
``` 

##### Postman examples

###### Get movie ratings
```json
GET http://localhost:<review-rest-port>/movies/296/ratings
```

###### Post rating
```json
POST http://localhost:<review-rest-port>/ratings
Content-Type: application/json

{
  "user_id": 1,
  "movie_id": 20,
  "rating": 4.5,
  "review": "Loved it!",
  "tag": "classic"
}
``` 

###### update movie rating
```json
PUT http://localhost:<review-rest-port>/ratings/10
Content-Type: application/json

{
  "rating": 3.5,
  "review": "Updated review"
}
``` 



