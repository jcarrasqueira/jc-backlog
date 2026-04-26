*Joana Carrasqueira, 64414* 
*branch: jcarrasqueira*
# Cloud Computing — Phase 4 Implementation
The microservices implement in this phase were the following:
- **Review Service** (Review system): manages user reviews, ratings, sentiment, and topic metadata 
- **Recommendation Service**: generates personalized movie recommendations based on preferences, reference movies, and genre families

Both services are fully isolated, own their respective data, and expose REST (FastAPI) and gRPC interfaces.

The system is backed by a PostgreSQL database populated via another container (*populate-db*)

## Populate-db
### Initial approach
A python container that ran a python script which loaded the csv files of each table in database into the database container.
- **script:** db-initial/populate-db.py
- **csv files folder:** db-initial/data (files available in [google drive link](https://drive.google.com/drive/folders/1yBRaUi72Y1QmUHmtBbip8_81QaxbVKey?usp=drive_link))
- **dockerfile:** db-initial/dockerfile
- **image created and published:** jrcarrasqueira/populate-db-phase5: v2.0

This approach was time consuming and heavy, which is why it was altered.

### Dump file approach
With the previous setup was created a dump file of the database with

```
docker exec -t postgres pg_dump -U {username} -Fc [db_name] > migration_backup.dump
```

Now we use the generated dump and created a new image based on it:
- **bash file for dockerfile:** db/setup.sh
- **dockerfile:** db/dockerfile
- **image created and published:** jrcarrasqueira/populate-db-phase5: v3.0

This not only is faster but allows for a backup of the database with the dump file.
## Running Locally
### 1. Create .env file
Create .env file in project's base folder (`CC2526-Group8`) with the structure provided in `.env.example` provided in base directory.

### 3. Build and run docker compose
```
docker compose up --build -d
``` 

With this multiple containers will be built and run:
- **postgres** which creates a container with ***postgres:15*** image with initialization files defined in `CC2526-Group8/db/init.sql`
    - only after health-check performed successfully can other containers be ran
- **populate-db** which creates a container with dump file and populates database accordingly.
    - only to be run once to populate the database or to restore it to its original state
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
###### Get Ratings (with filters)
```
GET http://localhost:<review-rest-port>/ratings?user_id=1&min_rating=3&max_rating=4
```
###### Get rating
```
GET http://localhost:<review-rest-port>/ratings/10
```
###### Post rating
```
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

###### Delete rating
```
DELETE http://localhost:<review-rest-port>/ratings/10
```

###### Get movie ratings
```
GET http://localhost:<review-rest-port>/movies/296/ratings
```

###### Update movie rating
```
PUT http://localhost:<review-rest-port>/ratings/10
Content-Type: application/json

{
  "rating": 3.5,
  "review": "Updated review"
}
``` 

###### Post a movie rating
```
POST /movies/3/ratings
Content-Type: application/json

{
  "user_id": 20,
  "rating": 4.0,
  "review": "Very fun movie",
  "tag": "fun"
}
```

###### Get user ratings
``` 
GET http://localhost:<review-rest-port>/users/1/ratings?min_rating=3&max_rating=4
```

#### GRPC
| gRPC Method Name    | Description                                                                         |
| ------------------- | ----------------------------------------------------------------------------------- |
| **GetRatings**      | Returns ratings with optional filters: *user_id, movie_id, min_rating, max_rating.* |
| **GetMovieRatings** | Returns all ratings for a specific movie.                                           |
| **GetUserRatings**  | Returns all ratings for a specific user.                                            |

In project base directory run:
```
docker exec -it review-service bash
```

then run the test client inside the container:
```
python grpc/rating_test.py
```

what should appear:
![[rating_test.png|500]]

### Recommendation Service
#### REST
| Method | Endpoint                                     | Description                                                                                                                                                                                                        |
| ------ | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| POST   | /users/{user_id}/preferences                 | Create a user genre preference                                                                                                                                                                                     |
| GET    | /users/{user_id}/preferences                 | Get all preferences for a user                                                                                                                                                                                     |
| DELETE | /users/{user_id}/preferences/{genre_id}      | Delete a user preference                                                                                                                                                                                           |
| POST   | /users/{user_id}/reference-movies            | Add a reference movie for a user                                                                                                                                                                                   |
| GET    | /users/{user_id}/reference-movies            | Get all reference movies for a user                                                                                                                                                                                |
| DELETE | /users/{user_id}/reference-movies/{movie_id} | Delete a reference movie for a user                                                                                                                                                                                |
| GET    | /recommendations/{user_id}                   | Gets 5 movies recommendations according to user preferences, user reference movies and user ratings. In case no data needed available (no ratings, preferences or reference movies) it returns top 5 rated movies. |
##### SwaggerUI
```
http://localhost:<recommendation-rest-port>/docs
``` 

##### Postman examples
###### Post user preference
```
POST http://localhost:<recommendation-rest-port>/users/1/preferences
Content-Type: application/json

{
  "genre_id": 18,
  "preference_type": "like"
}
``` 

###### Get user preferences
```
GET http://localhost:<recommendation-rest-port>/users/45885/preferences 
```

###### Delete user preference
```
DELETE http://localhost:<recommendation-rest-port>/users/1/preferences/18
``` 

###### Add a reference movie
```
POST http://localhost:<recommendation-rest-port>/users/90/reference-movies?movie_id=2
```

###### Get reference movies
```
GET http://localhost:<recommendation-rest-port>/users/90/reference-movies
```

###### Delete a reference movie
```
DELETE http://localhost:<recommendation-rest-port>/users/1/reference-movies/18
```

###### Get recommendations


#### GRPC
| gRPC Method Name         | Description                                         |
| ------------------------ | --------------------------------------------------- |
| **CreateUserPreference** | Creates a new user preference for a specific genre. |
| **GetUserPreferences**   | Returns all genre preferences for a specific user.  |
| **DeleteUserPreference** | Deletes a user’s preference for a specific genre.   |
| **AddReferenceMovie**    | Adds a reference movie for a user.                  |
| **GetReferenceMovies**   | Returns all reference movies for a specific user.   |
| **DeleteReferenceMovie** | Deletes a reference movie for a user.               |
| **GetRecommendations**   | Retrives user movies recommendations.               |
In project base directory run:
```
docker exec -it recommendations-service bash
```

then run the test client inside the container:
```
python grpc/recommendations_test.py
``` 

what should appear:
![[rec_test.png|500]]

## Use cases and functional requirements implemented
