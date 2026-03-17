### Group
Joana Carrasqueira, 64414
Leonor Silva, 59811
Tiago Pereira, 55854
Tiago Pina, 66101

# Functional Requirements

## User Management
### FR1. User Registration
- System must allow new users to register with email, password, username and optional parameters (gender, age).
- Password must follow security requirements, such as:
    - at least 15 characters
    - at least one number
    - at least one uppercase letter
    - at least one special character
- Terms and conditions must be accepted.
- System must validate the email and username uniqueness.

### FR2. User Authentication
- System must authenticate users with OAuth2.0 or username/email and password.
- System must receive a unique authentication in the token upon OAuth2.0 login.
- If unique id doesn't exist in the system database, system must convert OAuth2.0 login into a profile compatible with the platform.
- System must invalidate OAuth2.0 token on logout.

### FR3. User Profile 
- Users must be able to update their profile (username, gender, age).
    -  Username must be unique.
- Users must be able to adjust their preferences.
- Users must be able to delete their account.

## Movie Catalog
### FR4. Movie Detail
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

### FR5. Movie Search
- System must allow users to search for movies using keywords and/or filters.
- System must support filtering by:
    - genre
    - year range (from-to)
    - average rating
    - cast/director name
- Search results must be paginated and sortable by relevance, release date and rating.
- System must return results in a timely manner, optimizing for performance.
- System must handle empty search queries gracefully (e.g., return popular or recently added movies).

### FR6. Movie List
- System must provide a list of movies with browsing options, including:
    - pagination
    - sorting (by title, release date, rating, etc.)
    - filtering (by genre, year, etc.)
- The list view should display basic information: title, poster, release year, genres, average rating.
- User must be able to click on a movie to access its details.

### FR7. Movie CRUD
- System must allow authorized administrators to create, read, update, and delete operations on movie entries.
- Creation and update operations must include fields such as: title, description, release date, genres, cast, directors, runtime, poster image URL, etc.
- Deletion should be implemented as a logical (soft) delete or performed with appropriate checks to maintain referential integrity (e.g., associated reviews, watchlists).
- Any changes to movie data should be reflected across the system (e.g., in search, lists, details).

## Review System
### FR8. Rating CRUD
- Registered users must be able to submit a rating (integer from 1 to 5) and an optional text review for a specific movie.
- Users must be able to update or delete their own ratings and reviews at any time.
- The system must enforce that a user can have only one rating per movie; a new submission replaces the previous one.
- Upon any rating change (create, update, delete), the system must trigger an asynchronous recalculation of the movie's average rating.

### FR9. Ratings List
- System must allow retrieval of all ratings and reviews for a specific movie.
- The list must be paginated and sortable by date, rating, or helpfulness.
- For each rating, the system must display:
    - the user (anonymized or username)
    - rating value
    - review text
    - timestamp
- Optionally, the system must allow filtering by rating value or by the presence of a text review.

### FR10. Recalculate Movie Rating
- System must maintain an accurate average rating for each movie based on all submitted ratings (excluding those flagged as fraudulent or quarantined).
- Recalculation must be performed asynchronously after each rating change (create, update, or delete) to prevent performance degradation.
- The updated average rating must be stored in the movie catalog database for quick retrieval.
- Only ratings not marked as fraudulent should contribute to the average.

## Badges
### FR11. CRUD badges (system)
- System must allow administrators to create, read, update and delete badge definitions (e.g., “Explorer”, “Streak Master”).  
- Each badge definition must include at least: unique identifier, title, milestone rule and optional description.  
- System must validate that badge titles are unique across all badge definitions.  
- Deleting a badge definition must not remove historical records of badges already awarded to users, but must prevent the badge from being awarded in the future (up to debate).  

### FR12. Award Badges
- System must automatically evaluate user activity (ratings, watchlists, viewing streaks, genre exploration, etc.) to determine when a user meets a badge milestone.  
- When a milestone is met, the system must award the corresponding badge to the user and store the award timestamp.  
- System must expose an operation to manually award or revoke badges for administrative purposes (e.g., correcting errors or running special campaigns).  
- Awarded badges must be visible in the user profile and retrievable via the badges API endpoints.  

### FR13. List user badges
- System must allow retrieval of all badges awarded to a specific user, including badge details (title, milestone) and award date.  
- System must support pagination of user badges when a user has a large number of awarded badges.  
- System must support filtering user badges by badge type (e.g., exploration, streak) and by time window (e.g., badges earned in the last 30 days).  

## Watchlists
### FR14. Create Watchlist
- Users must be able to create a new watchlist by providing a title.
- Users should be able to add multiple movies to the watchlist after creation.
- The system must validate that the title is not empty.

### FR15. Edit Watchlist
- Users must add or remove movies from watchlists.
- Users must be able to rename a watchlist, as long as the new title does not duplicate another watchlist they own.
- The system must prevent adding the same movie twice.

### FR16. Delete Watchlist
- Users must be able to delete a watchlist they own.
- Deleting a watchlist must also remove all associated movie entries.
- The system must ensure that only the owner can delete their watchlist.

### FR17. Retrieve User Watchlists
- Users must be able to retrieve all their watchlists and their contents.
- Users must be able to retrieve a single watchlist by its ID.
- Users should be able to filter the contents of a watchlist by genre.

## Subscriptions
### FR18. Subscribe to plan
- System must allow users to subscribe to a paid plan that unlocks premium features (e.g., advanced analytics, streaming subscription optimizer, early access to new tools) (up to debate).  
- System must support at least one recurring plan (e.g., monthly) and store subscription start date, plan type and current status.  
- System must validate payment or external billing confirmation before activating a subscription.  

### FR19. Manage subscription plan
- Users must be able to view their current subscription status, including plan type, renewal date and payment status.  
- Users must be able to upgrade, downgrade or cancel their subscription from within the platform.  
- System must ensure that subscription changes are reflected in access control to premium features without requiring user re‑registration.  

### FR20. Premium Access
- System must restrict access to selected premium features (such as detailed dashboards, subscription optimizer and advanced gamification insights) to users with an active premium subscription.  
- For each request to a premium endpoint, the system must validate the user’s subscription status through the Subscriptions service.  
- If the subscription is expired or cancelled, the system must deny access and return an appropriate error, suggesting re‑subscription.  

### FR21. CRUD Subscriptions
- System must provide administrative operations to create, read, update and cancel subscriptions for support and correction purposes.  
- System must log all subscription lifecycle events (creation, renewal, cancellation, plan changes) for auditing and billing reconciliation.  
- System must ensure that subscription records remain consistent with the external payment provider, handling asynchronous callbacks or webhooks when necessary in later phases.

## Recommendation
### FR22. Initial Profile Recommendations
- New users must be able to select preferred genres and genres to avoid during the registration process.
- New users must be able to search and select 3 to 5 reference movies.
- The system must build a preference vector based on the user's explicit genre choices, reference titles, and similarities with other users.
- The system must generate tailored homepage shelves such as "Based on Your Genres", "Based on Your Favourite Titles" for the user's first session.
- Users must be able to filter these initial recommendations based on the streaming platforms they own.

### FR23. Personalized Recommendations
- System must analyze a user’s rating history, preferred genres, and interactions to calculate personalized movie and series recommendations.
- System must order the recommended titles by relevance and probability of user satisfaction.
- System must update recommendations dynamically as the user rates new titles or alters their watchlists.

### FR24. Genre Family Exploration
- System must group movies into "genre families" by analysing genre co-occurrence and overall user consumption patterns.
- System must calculate and categorize each user's consumption into highly explored and underexplored genre families.
- System must generate distinct discovery shelves for the user interface, such as "Comfort Zone" and "Explore Something New"

## Fraud Detection
### FR25. Detect Inconsistent Consumption
- System must continuously monitor user interactions (views, ratings, reviews) to detect anomalous patterns that may indicate fraud, compromised accounts, or bot activity.
- Anomaly detection should consider, among others:
    - sudden spikes in activity within a short period
    - extreme ratings (e.g. 1 or 10) coming from new recent accounts or accounts with very little history
    - unusual device or geographic location patterns
    - coordinated behavior across multiple accounts (e.g., same IP address, similar timings)
    - significant deviations from a user's typical behavior profile (viewing times, preferred genres, rating distribution, etc.)
- System must distinguish between potentially malicious patterns and genuine shifts in taste, using adaptative models where feasible.
- Detected anomalies must be flagged for further analysis or automatic action.

### FR26. Review Fraud Treatment
- When a rating or review is identified as potentially fraudulent (e.g., part of review bombing), the system must quarantine it:
    - Exclude it from public averages, recommendations, and studio analytics.
    - Store quarantine metadata (reason, timestamp, user)
- Quarantined items must be reviewed by administrators, who can either restore them or permanently mark them as fraudulent.
- The system must maintain a log of all fraud detection events and actions taken.

## Studio Analytics
### FR27. Sentiment Analysis
- System must automatically process user text reviews using Natural Language Processing (NLP).
- System must classify each processed review into sentiment categories: positive, negative, or neutral.
- System must aggregate these sentiment metrics to calculate an overall sentiment score for each movie or series.

### FR28. Topic Extraction
- System must analyze reviews to extract frequently mentioned topics (e.g., plot, acting, special effects, pacing).
- System must generate automated summaries highlighting the most frequent strengths and weaknesses mentioned by the audience.

### FR29. User Cluster Analytics 
- System must group users into distinct segments (clusters) based on consumption history, preferred genres, and usage patterns.
- System must correlate and aggregate the extracted sentiments and topics specific to each user segment (e.g., showing how 'Casual Viewers' vs. 'Cinephiles' reacted to the same movie).


# Application Architecture
## Architecture Diagram

```mermaid
flowchart LR

subgraph Client["Frontend (Web/Mobile)"]
    UI[User Interface]
end

subgraph API["Backend API (FastAPI)"]
    UserManagement["User Management"]
    MovieCatalog["Movie Catalog"]
    ReviewSystem["Review System"]
    Badges["Badges"]
    Watchlists["Watchlists"]
    Subscriptions["Subscriptions"]
    Recommendations["Recommendations"]
    StudioAnalytics["Studio Analytics"]
    FraudDetection["Fraud Detection"]
end

subgraph Databases["Databases"]
    DB[(Main Database)]
    DBbackup[(Backup Database)]
end

UI -->|REST/HTTPS| API

API --> |READ/WRITES| DB
DB <--> DBbackup
``` 



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
- The system follows a modular, service‑oriented architecture designed for a cloud‑native environment.
- Each functional domain (movies, ratings, watchlists, analytics, etc.) is implemented as an independent backend service.
- All services are exposed through a unified API Gateway, which acts as the single public entry point.

- This architecture directly reflects the functional requirements defined earlier and supports future deployment on Kubernetes.

### API Gateway
The API Gateway is responsible for:
- Routing incoming REST requests to the appropriate backend service
- Enforcing authentication (OAuth2.0)
- Providing a single stable endpoint for all clients
- Applying request validation and basic rate limiting

This ensures that clients interact with a single, consistent API, regardless of internal service structure.
### Microservices
- Each service corresponds to a functional domain and maps directly to the OpenAPI specification and functional requirements.

| Microservice     | Description                                                             |
| ---------------- | ----------------------------------------------------------------------- |
| User Management  | Registration, authentication, profile updates, OAuth2 integration       |
| Movie Catalog    | Movie CRUD, search, filtering, metadata retrieval                       |
| Review System    | Ratings, reviews and average scores recalculation                       |
| Badges           | Badge definitions, awarding logic, user achievements                    |
| Watchlists       | CRUD watchlists, add/remove movies, filtering                           |
| Subscriptions    | Subscription lifecycle, plan management, premium access control         |
| Recomendation    | Hybrid recommendations, genre families and personalised recommendations |
| Fraud Detection  | Anomaly detection, review bombing mitigation, quarantine logic          |
| Studio Analytics | NLP sentiment analysis, topic extraction, user cluster analytics        |
### Databases
#### Main Database (PostgreSQL or something else)
- responsible for storing data such as users, movies, ratings, watchlists, badges, subscriptions.
- supports high‑frequency reads/writes and ensures data consistency.
#### Backup Databases
- responsible for performing periodic backups to the main database
- ensuring redundancy of the main database for disaster recovery

### Protocols
- **REST/HTTPS** for all client–server communication
- **SQL** for databases 
- **REST** for backend services 
