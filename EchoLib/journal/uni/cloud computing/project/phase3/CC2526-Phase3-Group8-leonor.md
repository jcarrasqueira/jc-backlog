# Cloud Native Application - Phase 3

### Group
Joana Carrasqueira, 64414
Leonor Silva, 59811
Tiago Pereira, 55854
Tiago Pina, 66101

# Functional Requirements

## User Management
### FR. User Registration
- System must allow new users to register with email, password, username and optional parameters (gender, age).
- Password must follow security requirements, such as:
    - at least 15 characters
    - at least one number
    - at least one uppercase letter
    - at least one special character
- Terms and conditions must be accepted.
- System must validate the email and username uniqueness.

### FR. User Authentication
- System must authenticate users with OAuth2.0 or username/email and password.
- System must receive a unique authentication in the token upon OAuth2.0 login.
- If unique id doesn't exist in the system database, system must convert OAuth2.0 login into a profile compatible with the platform.
- System must invalidate OAuth2.0 token on logout.

### FR. User Profile 
- Users must be able to update their profile (username, gender, age).
    -  Username must be unique.
- Users must be able to adjust their preferences.
- Users must be able to delete their account.

## Movie Catalog (UC8,UC9)
### FR. Movie Detail
- System must provide detailed view of a specific movie when requested by its unique identifier (movie ID), including: 
    - title
    - release date
    - genres
    - average rating
    - main cast
    - director(s)
    - synopse or description
    - runtime (duration)
    - parental rating (e.g. PG-13)
    - list of streaming platforms where the movie is available
- If the requested movie does not exist, the system must return an error message.

### FR. Movie Search
- System must allow users to search for movies using keywords and/or filters.
- System must support filtering by:
    - genre
    - year range (from-to)
    - average rating
    - cast/director name
- Search results must be paginated and sortable by relevance, release date and rating.
- System must return results in a timely manner, optimizing for performance.
- System must handle empty search queries gracefully (e.g., return popular or recently added movies).

### FR. Movie List
- System must provide a list of movies with browsing options, including:
    - pagination
    - sorting (by title, release date, rating, etc.)
    - filtering (by genre, year, etc.)
- The list view should display basic information: title, poster, release year, genres, average rating.
- User must be able to click on a movie to access its details.

### FR. Movie CRUD
- System must allow authorized administrators to create, read, update, and delete operations on movie entries.
- Creation and update operations must include fields such as: title, description, release date, genres, cast, directors, runtime, poster image URL, etc.
- Deletion should be implemented as a logical (soft) delete or performed with appropriate checks to maintain referential integrity (e.g., associated reviews, watchlists).
- Any changes to movie data should be reflected across the system (e.g., in search, lists, details).

## Review System
### FR. Rating CRUD
- Registered users must be able to submit a rating (integer from 1 to 10) and an optional text review for a specific movie.
- Users must be able to update or delete their own ratings and reviews at any time.
- The system must enforce that a user can have only one rating per movie; a new submission replaces the previous one.
- Upon any rating change (create, update, delete), the system must trigger an asynchronous recalculation of the movie's average rating.

### FR. Ratings List
- System must allow retrieval of all ratings and reviews for a specific movie.
- The list must be paginated and sortable by date, rating, or helpfulness.
- For each rating, the system must display:
    - the user (anonymized or username)
    - rating value
    - review text
    - timestamp
- Optionally, the system must allow filtering by rating value or by the presence of a text review.

### FR. Recalculate Movie Rating
- System must maintain an accurate average rating for each movie based on all submitted ratings (excluding those flagged as fraudulent or quarantined).
- Recalculation must be performed asynchronously after each rating change (create, update, or delete) to prevent performance degradation.
- The updated average rating must be stored in the movie catalog database for quick retrieval.
- Only ratings not marked as fraudulent should contribute to the average.

## Badges
### FR. CRUD badges (system)
### FR. Award Badges
### FR. List user badges

## Watchlists
### FR8. CRUD Watchlists
### FR. Create Watchlist
### FR. Edit Watchlist
### FR. List User Watchlists

## Subscriptions
### FR. Subscribe to plan
### FR. Manage subscription plan
### FR. Premium Access
### FR. CRUD Subscriptions

## Recommendation
### FR. Initial Profile Recommendations
- New users must be able to select preferred genres and genres to avoid during the registration process.
- New users must be able to search and select 3 to 5 reference movies.
- The system must build a preference vector based on the user's explicit genre choices, reference titles, and similarities with other users.
- The system must generate tailored homepage shelves such as "Based on Your Genres", "Based on Your Favourite Titles" for the user's first session.
- Users must be able to filter these initial recommendations based on the streaming platforms they own.

### FR. Personalized Recommendations
- System must analyze a user’s rating history, preferred genres, and interactions to calculate personalized movie and series recommendations.
- System must order the recommended titles by relevance and probability of user satisfaction.
- System must update recommendations dynamically as the user rates new titles or alters their watchlists.

### FR. Genre Family Exploration
- System must group movies into "genre families" by analyzing genre co-occurrence and overall user consumption patterns.
- System must calculate and categorize each user's consumption into highly explored and underexplored genre families.
- System must generate distinct discovery shelves for the user interface, such as "Comfort Zone" and "Explore Something New"

## Fraud Detection (UC3, UC5)
### FR. Detect Inconsistent Consumption
- System must continuously monitor user interactions (views, ratings, reviews) to detect anomalous patterns that may indicate fraud, compromised accounts, or bot activity.
- Anomaly detection should consider, among others:
    - sudden spikes in activity within a short period
    - extreme ratings (e.g. 1 or 10) coming from new recent accounts or accounts with very little history
    - unusual device or geographic location patterns
    - coordinated behavior across multiple accounts (e.g., same IP address, similar timings)
    - significant deviations from a user's typical behavior profile (viewing times, preferred genres, rating distribution, etc.)
- System must distinguish between potentially malicious patterns and genuine shifts in taste, using adaptative models where feasible.
- Detected anomalies must be flagged for further analysis or automatic action.

### FR. Review Fraud Treatment
- When a rating or review is identified as potentially fraudulent (e.g., part of review bombing), the system must quarantine it:
    - Exclude it from public averages, recommendations, and studio analytics.
    - Store quarantine metadata (reason, timestamp, user)
- Quarantined items must be reviewed by administrators, who can either restore them or permanently mark them as fraudulent.
- The system must maintain a log of all fraud detection events and actions taken.

## Studio Analytics
### FR. Sentiment Analysis
- System must automatically process user text reviews using Natural Language Processing (NLP).
- System must classify each processed review into sentiment categories: positive, negative, or neutral.
- System must aggregate these sentiment metrics to calculate an overall sentiment score for each movie or series.

### FR. Topic Extraction
- System must analyze reviews to extract frequently mentioned topics (e.g., plot, acting, special effects, pacing).
- System must generate automated summaries highlighting the most frequent strengths and weaknesses mentioned by the audience.

### Fr. User Cluster Analytics 
- System must group users into distinct segments (clusters) based on consumption history, preferred genres, and usage patterns.
- System must correlate and aggregate the extracted sentiments and topics specific to each user segment (e.g., showing how 'Casual Viewers' vs. 'Cinephiles' reacted to the same movie).


# Application Architecture
## Architecture Diagram

```mermaid
graph TD;
    ClientApps[Client Apps] -->|HTTP/REST| APIGatewayLayer[API Gateway Layer]
    APIGatewayLayer -->|gRPC| Services
    
    UserManagement -->|Reads/Writes| DB[(PostgreSQL)]
    MovieCatalog -->|Reads/Writes| DB[(PostgreSQL)]
    ReviewSystem -->|Reads/Writes| DB[(PostgreSQL)]
    Badges -->|Reads/Writes| DB[(PostgreSQL)]
    Watchlist -->|Reads/Writes| DB[(PostgreSQL)]
    Subscriptions -->|Reads| DB[(PostgreSQL)]
    Recommendations -->|Reads/Writes| DB[(PostgreSQL)]
    FraudDetection -->|Reads/Writes| DB[(PostgreSQL)]
    StudioAnalytics -->|Reads/Writes| DB[(PostgreSQL)]
    
    DB[(PostgreSQL)] <--> BackupDB[(PostgreSQL)]
    
    subgraph Services
       UserManagement
       MovieCatalog
       ReviewSystem
       Badges
       Watchlist
       Subscriptions
       Recommendations
       FraudDetection
       StudioAnalytics
    end
```


## Architecture Description 
description: 

### API Gateway

### Microservices

| Microservice     | Description                                                                            | Communication |
| ---------------- | -------------------------------------------------------------------------------------- | ------------- |
| User Management  | Includes user admin operations (CRUD), user profiles and user registration             |               |
| Movie Catalog    | Movie CRUD operations, Movie listing and details, as well as movie search with filters |               |
| Review System    | Ratings, reviews and average scores updates                                            |               |
| Badges           | Badge definitions and awarding                                                         |               |
| Watchlists       | Create and manage wathclists                                                           |               |
| Subscriptions    | Subcriptions lifecycle                                                                 |               |
| Recomendation    | Hybrid recommendations, genre families and personalised recommendations                |               |
| Fraud Detection  | Fraud detection, fraud rating treatment                                                |               |
| Studio Analytics | NLP sentiment, topic/tag modeling, dashboards                                          |               |

### Database

### Protocols
- **REST/HTTPS** for all client–server communication
### Deployment