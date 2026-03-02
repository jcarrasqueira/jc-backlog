# Phase 1 – Dataset, Business Capabilities and Use Cases  
**Project:** MovieVerse – A “Goodreads for Movies”  
**Student:** <Your Name>  
**Group:** <Group Number>  

## 1. Dataset Identification

### 1.1 Main dataset – IMDb non‑commercial datasets

- **URL:** https://developer.imdb.com/non-commercial-datasets/ [web:10]  
- **Topic:** Structured information about movies, TV series and other titles, including metadata (titles, year, genres, runtime), ratings and people (actors, directors, writers). [web:10]  
- **Format:** Gzipped TSV (tab‑separated values), UTF‑8 encoded, with header row and `\N` for missing values. [web:10]  
- **Size:** IMDb movie datasets in TSV format are typically several GB in raw size (around 4–5 GB across all tables, depending on the mirror). [web:1][web:4][web:7]  
- **Date of release / recency:** IMDb provides regularly updated snapshots (e.g., updated datasets up to March 2025 exist in public mirrors). [web:7][web:10]  

For this project, we will focus on a subset of the IMDb datasets relevant to movies only (excluding episodes and some TV data) and only the fields required to implement our use cases. This filtered subset is expected to be around 1–2 GB when stored as TSV/CSV.

#### 1.1.1 Files to be used (subset)

From the IMDb non‑commercial datasets: [web:10]  

- `title.basics.tsv.gz` – basic information about titles (primary title, original title, type, year, runtime, genres).  
- `title.ratings.tsv.gz` – average rating and number of votes per title.  
- `title.crew.tsv.gz` – director and writers per title.  

Optional (if needed later):  

- `name.basics.tsv.gz` – information about people (actors, directors, etc.).  

### 1.2 Optional enrichment dataset – Kaggle “The Movies Dataset”

- **URL (index page):** https://www.kaggle.com/datasets?search=movie [web:9]  
- **Specific dataset:** “The Movies Dataset” (Rounak Banik) – 7 CSV files, ≈239 MB, with about 45,000 movies and 26 M ratings (MovieLens‑based). [web:3][web:9]  
- **Topic:** Movie metadata and user‑movie ratings collected from the MovieLens platform. [web:3]  

This dataset can be used later to enrich recommendations with user rating patterns if needed.

---

## 2. Motivation and Topic

The goal is to build **MovieVerse**, a cloud‑native movie database and recommendation backend similar to Goodreads but for movies. It will provide searchable movie information, user ratings, and basic analytics and recommendations. The IMDb dataset is a strong fit because it:  

- Is text‑based (TSV, UTF‑8), suitable for ingestion and cleaning. [web:10]  
- Covers a large number of movies with structured fields like year, genres, rating and vote counts, which support interesting queries and analytics. [web:10]  
- Is updated regularly and has recent data up to at least 2025 in public copies. [web:7][web:10]  
- Is naturally relational and can be normalized into multiple tables (titles, genres, ratings, crew). [web:4][web:10]  

This project can support business‑like capabilities such as personalized recommendations, trend analysis (e.g., what is popular now), and data‑driven decisions for hypothetical partners (streaming platforms, cinemas, or content curators).

---

## 3. Business Capabilities

The planned system will expose several **business capabilities** as backend services:

1. **Movie Information Service**  
   - Provides detailed, cleaned and searchable information about movies (title, year, genres, rating, runtime, crew).  
   - Enables external clients (web front‑ends or partner services) to power movie discovery experiences.

2. **Ratings and Reviews Service**  
   - Allows users to submit and update their ratings and (project‑scoped) reviews for movies.  
   - Aggregates ratings and can compute basic statistics such as average rating or rating distribution per movie.

3. **Recommendation Service**  
   - Suggests movies to users based on their past ratings, genres they prefer or similar popular titles.  
   - Can initially use simple collaborative filtering or “more like this” logic based on genres and ratings.

4. **Trend and Analytics Service**  
   - Computes lists such as “Top rated this week/month”, “Most popular recently”, “Hidden gems with high rating but low vote count”.  
   - Supports future data‑science extensions (e.g., time‑based analysis, genre popularity evolution).

5. **User Library / Watchlist Service** (optional)  
   - Manages user watchlists (“want to watch”, “already watched”).  
   - Allows external clients to display personalized library views.

Each of these capabilities will later correspond to one or more microservices and REST endpoints.

---

## 4. Use Cases (Student‑Owned)

Below are the use cases I plan to contribute to, all built on top of the above capabilities.

> Replace UC‑1 / UC‑2 selection with what you personally want to own.

### UC‑1 – Search movies by title and filter by genre/year

- **Actor:** End user (or client application).  
- **Goal:** Find movies matching a text query (title) with optional filters (genre, year range).  
- **Preconditions:** The dataset is imported and indexed in the database; movie records exist.  
- **Main flow:**  
  1. User provides a search term (e.g., “Inception”) and optional filters (genre: “Sci‑Fi”, year ≥ 2000).  
  2. System searches movies by title, applies filters and sort criteria (e.g., by relevance, rating).  
  3. System returns a paginated list of movies with key attributes (title, year, genres, average rating).  
- **Business capability:** Movie Information Service.

### UC‑2 – Get detailed information for a movie

- **Actor:** End user (or client application).  
- **Goal:** View the full details of a selected movie.  
- **Preconditions:** Movie exists in the dataset and is identified by its ID.  
- **Main flow:**  
  1. User selects a movie (e.g., from search results) and requests details.  
  2. System fetches detailed information from the database: title, year, genres, runtime, rating, vote count, director(s), writers.  
  3. System returns a complete movie details object suitable for use in a detail page.  
- **Business capability:** Movie Information Service.

### UC‑3 – Submit or update a rating for a movie

- **Actor:** Authenticated user.  
- **Goal:** Rate a movie on a numeric scale (e.g., 1–10) and optionally update the existing rating.  
- **Preconditions:**  
  - User is authenticated.  
  - Movie exists in the dataset.  
- **Main flow:**  
  1. User sends a rating value for a movie.  
  2. System validates the rating range and associates it with the user and movie.  
  3. System updates aggregate statistics (average rating, number of votes) in a derived table or cached structure.  
  4. System returns the updated aggregate rating data.  
- **Business capability:** Ratings and Reviews Service.

### UC‑4 – Get personalized recommendations (basic version)

- **Actor:** Authenticated user.  
- **Goal:** Receive a list of recommended movies tailored to the user’s preferences.  
- **Preconditions:** User has previously rated at least a few movies.  
- **Main flow:**  
  1. User requests recommendations.  
  2. System analyses the user’s ratings and favorite genres, and/or finds similar movies with high average rating and sufficient vote count.  
  3. System returns a list of recommended movies (IDs plus key metadata).  
- **Business capability:** Recommendation Service.

*(You can drop UC‑4 from your individual list if it will be owned by another teammate.)*

---

## 5. Data Cleaning and Preparation Plan

To make the IMDb data usable for the above use cases, I plan to perform the following steps:

### 5.1 Initial import

1. Download the selected IMDb TSV files (`title.basics`, `title.ratings`, `title.crew`) from the non‑commercial dataset page. [web:10]  
2. Create a local relational database (e.g., PostgreSQL or MySQL).  
3. Create a staging table for each raw TSV file and import all rows, treating `\N` as NULL. [web:10]  

### 5.2 Normalization and schema design

1. From `title.basics`, build a main `movies` table with fields like:  
   - `movie_id` (primary key, `tconst`)  
   - `primary_title`  
   - `original_title`  
   - `start_year`  
   - `runtime_minutes`  
   - `is_adult`  
2. Extract distinct genres from the genre column and create a separate `genres` table, and a junction table `movie_genres(movie_id, genre_id)` to support multi‑genre movies.  
3. From `title.ratings`, create a `movie_ratings` table:  
   - `movie_id`  
   - `average_rating`  
   - `num_votes`  
4. From `title.crew`, create a `movie_crew` table for director IDs and writer IDs (optionally linking to `people` later if `name.basics` is imported).  

### 5.3 Cleaning steps

- Remove non‑movie types (e.g., TV episodes) by filtering on title type (keep movies and possibly documentaries).  
- Remove rows with missing critical fields for our use cases (e.g., missing title or year).  
- Normalize genres into a controlled list (e.g., avoid duplicates like “Sci-Fi” vs “Science Fiction”).  
- Optionally restrict to movies with at least a minimum number of votes (e.g., ≥ 50) to avoid noise for recommendations.  

### 5.4 Indexing

To support the planned use cases efficiently:

- Add indices on `primary_title` and `start_year` in `movies` for search by title/year.  
- Add index on `average_rating` and `num_votes` in `movie_ratings` for queries like “top rated” or “trending”.  
- Add index on `genre_id` in `movie_genres` to accelerate filtering by genre.  

### 5.5 Export for other storage engines (optional)

Once the data is cleaned and normalized, I can:

- Export key tables to CSV for potential use in a NoSQL database or data warehouse later (e.g., BigQuery or a document store).  
- Keep the relational schema as the primary source for the early implementation phases.

---

## 6. Summary of My Individual Scope in Phase 1

For Phase 1, my individual contribution focuses on:

- Selecting and documenting the IMDb non‑commercial datasets relevant for a movie‑database backend, with optional enrichment from Kaggle’s “The Movies Dataset”. [web:3][web:9][web:10]  
- Defining the **Movie Information Service** and **Ratings and Reviews Service** as core business capabilities I will help implement.  
- Defining and documenting the use cases **UC‑1 (search movies)**, **UC‑2 (movie details)** and **UC‑3 (submit/update rating)** as my main responsibilities for the following phases.  
- Designing an initial data cleaning and normalization plan, including relational schema, filtering rules and basic indexing strategy.

