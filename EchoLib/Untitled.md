## 3. Use cases (services/endpoints)

You can later split these among group members.

- **UC1 – “Top‑N Personalized Recommendations”**
    
    - **Actor(s)**: Registered user of a client movie site
        
    - **Goal**: Get a list of movies they are likely to enjoy based on past ratings or watch history.
        
    - **Input**: User ID or explicit list of (movie_id, rating), optional filters (language, year, min rating).
        
    - **Output**: JSON list of recommended movies with scores, titles, genres, and reasons (e.g., “similar to movies you rated 5”).
        
- **UC2 – “Genre‑Focused Discovery”**
    
    - **Actor(s)**: User exploring the catalog
        
    - **Goal**: Discover highly rated or popular movies in one or more genres.
        
    - **Input**: Genre(s), sort criteria (average rating, popularity), paging parameters.
        
    - **Output**: List of movies with aggregated stats (average rating, number of ratings, year).
        
- **UC3 – “New User Warm‑Start Recs”**
    
    - **Actor(s)**: New user with no history
        
    - **Goal**: Receive initial suggestions quickly after answering a few questions.
        
    - **Input**: Short preference form (favourite genres, preferred era, a few liked movies) or no input at all.
        
    - **Output**: Initial recommendation list based on popularity + genres + simple similarity.
        
- **UC4 – “Catalog & Audience Analytics”**
    
    - **Actor(s)**: Content manager / platform admin
        
    - **Goal**: Understand what content works best to support decisions (promotions, licensing).
        
    - **Input**: Time window, optional filters (genre, year).
        
    - **Output**: Aggregated indicators (most rated movies, average rating per genre, rating distribution, top trending titles).
        
- **UC5 – “Similar Movies / ‘Because you watched…’”**
    
    - **Actor(s)**: User on a movie detail page
        
    - **Goal**: Get similar movies to the one they are viewing.
        
    - **Input**: Movie ID.
        
    - **Output**: List of similar movies based on co‑viewing / co‑rating patterns or shared genres/tags.
        

## 4. Data cleaning & DB plan (short)

- Import raw CSVs (`movies.csv`, `ratings.csv`, etc.) into a staging table in a relational DB.[](https://zenodo.org/records/8276077)​
    
- Detect missing or invalid values (e.g., invalid timestamps, unknown movie IDs in ratings) and either fix or discard.[](https://zenodo.org/records/8276077)​
    
- Normalize into tables like:
    
    - `movies(movie_id, title, year, genres, …)`
        
    - `users(user_id, …)` (even if user features are limited)
        
    - `ratings(user_id, movie_id, rating, timestamp)`
        
    - `tags(user_id, movie_id, tag, timestamp)`
        
- Add indexes on `ratings(user_id)`, `ratings(movie_id)`, and `movies(genres)` to support frequent queries.
  
  
---




  ```