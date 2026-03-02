## Use Cases

Pick 3–4 of these as **your personal contributions** for Phase 1. Each maps to one of the business capabilities above.

## UC1: Search titles

**Actor:** User  
**Goal:** Find movies or TV shows matching criteria.  
**Description:** User enters a search term or filters by type (movie/series), genre, year range, or minimum rating. System returns paginated results showing title, type, year, genres, average rating, and vote count.  
**Business capability:** Title catalog & search.

## UC2: View title details

**Actor:** User  
**Goal:** Get complete information about a specific title.  
**Description:** User requests details for a title by ID. System displays title, type, year(s)/seasons, runtime/episode count, genres, main cast/crew, average rating, vote count, and basic plot summary (if available).  
**Business capability:** Title catalog & search.

## UC3: Rate and review a title

**Actor:** Logged-in user  
**Goal:** Share opinion and contribute to public aggregates.  
**Description:** User submits a rating (1-10 scale) and optional text review for a title. System stores the review, recalculates the title's average rating and vote count, and makes it visible publicly.  
**Business capability:** Ratings & public reviews.

## UC4: Manage personal watchlist

**Actor:** Logged-in user  
**Goal:** Track viewing plans across movies and series.  
**Description:** User adds/removes titles from personal lists ("Watchlist", "Currently watching", "Finished"). System persists the lists and allows retrieval/filtering by type or genre.  
**Business capability:** Personal watchlists & libraries.

## UC5: Get personalized recommendations

**Actor:** Logged-in user  
**Goal:** Discover new content based on viewing history.  
**Description:** User requests recommendations. System analyzes their ratings and watch history to return 10-20 unrated titles (mix of movies/series) ranked by predicted preference.  
**Business capability:** Personalized recommendations.

## UC6: Browse discovery lists

**Actor:** User  
**Goal:** Explore popular or curated content.  
**Description:** User views pre-computed lists like "Top rated movies", "Trending TV shows", or "Best of genre X". System returns titles ranked by aggregate ratings and recency metrics from the dataset.  
**Business capability:** Discovery & trends analytics.