### Group
Joana Carrasqueira, 64414
Leonor Silva, 59811
Tiago Pereira, 55854
Tiago Pina, 66101

# Project description
TODO: insert project brief description


- imbd - principal 
- movielens 
- netflix

## Datasets 
### Main Datasets : IMDb Non-Commercial Datasets
- **URL:** https://datasets.imdbws.com/
- **Format:** .tsv (UTF-8)
- **Date of release:** March 18, 2024 (updates daily)

- dataset

### Auxiliary datasets
#### dataset name
- **URL:** 
- **Topic:**
- **Size:**
- **Format:**
- **Date of release:**

#### dataset name
- **URL:**
- **Topic:**
- **Size:**
- **Format:**
- **Date of release:**

## Business Capabilities
### BC1. Subscriptions System
- **Description:** A subscription plan with two tiers (free or premium), would provide direct revenue with the higher tier option. Users with premium plan would have access to functionalities such as advanced statistics for watching habits and beta access to new functionalities.
- **Source of income:** Monthly or yearly subscriptions (premium).

### BC2. Advertising in Search
- **Description:** Inclusion of adds in recommendation system, where studios or streaming services can promote their releases in specific segments (search engine) based on user's history and preferences. 
- **Source of income:** ?

###  BC3. Engagement Badges System
- **Description:** Exclusive badges on completing milestones of usage of the platform, such ass certain amount of ratings made, exploring new genres of content, and creating watchlists.
- **Source of income:** Increase in retention and time spent, reinforcing the value of other capabilities (advertising, premium features). Potential sale of this module as a white-label solution to other content platforms.

###  BC4. Analytics to Studios and Producers
- **Description:** Advanced analytics dashboard providing insights into genre trends (average popularity over time), actor performance (average revenue per film, average rating, number of appearances), and the correlation between budget and revenue. Enables data-driven decision-making for content investment, casting, and distribution strategies.
- **Source of income:** Premium subscription model for studios and production companies. Customized reports and data exports.

###  BC5. Smart Intelligent Review System
- **Description:** AI-powered system that performs automatic sentiment analysis (classifying reviews as positive, negative, or neutral), generates summaries of the most frequent strengths and weaknesses mentioned in reviews, and identifies recurring topics using techniques such as LDA. Helps both users and industry professionals quickly extract meaningful insights from large volumes of text.
- **Source of income:** Increased user engagement and retention (boosting advertising and premium value). Premium access to advanced review insights.

## Use Cases
### UC1. Hybrid Initial Profile Creation (Genres + Reference Titles)
- **actor:**  Newly registered user.
- **problem:** A new user wants relevant recommendations immediately but has no viewing history on the platform.
- **description:**
	1.  During registration, the user selects preferred genres and genres to avoid through a simple checklist interface.
	2. Optionally, the user searches for and selects 3–5 movies or TV shows they consider personal references (*“I love this movie”*).
	3. The system builds a preference vector that combines explicit genre information with inferred patterns derived from the selected reference titles and from similar users.
	4. In the first session after registration, the user receives a homepage organized into distinct shelves: *“Based on Your Genres”*, *“Based on Your Favourite Titles”*, and, if applicable, filtered by the streaming platforms the user has indicated they own.
- **expected outcome:** Initial recommendations with strong accuracy and diversity, reducing the cold-start problem and increasing the likelihood that the user finds appealing content during their first interaction with the platform.

### UC2. Guided Exploration by Genre Families
- **actor:**  Registered user.
- **problem:** The user tends to remain stuck in the same types of content and struggles to discover interesting variations within and around the genres they enjoy.
- **description:**
	1. The system analyses the database of movies and TV shows and identifies *“genre families”* based on genre co-occurrence and consumption patterns (e.g., action + sci-fi + superheroes; drama + biography; horror + psychological thriller).
	2. For each user, it calculates which genre families are highly explored (high consumption and strong ratings) and which related families remain underexplored, also considering the behaviour of similar users.
	3. The interface presents shelves such as *“Comfort Zone"*, *“More of the Same, but Different”*, and *“Explore Something New”*, each containing recommendations ranked by the probability of user satisfaction and filtered according to the streaming platforms the user owns.
- **expected outcome:** A discovery experience that gently encourages users to step slightly outside their comfort zone in a controlled way, increasing content diversity without sacrificing relevance.

### UC3. Inconsistent Consumption Flow Detection System
- **actor:**  Platform (security team, data science team).
- **problem:** Sudden changes and atypical consumption or rating patterns may indicate fraud, compromised accounts, or noise that harms the quality of recommendations and the reliability of metrics presented to studios.
- **description:** 
	1. For each user, the system maintains a routine profile that includes typical viewing times, most-used devices, rating distribution, and most frequent genres.
	2. Anomaly detection algorithms continuously monitor new interactions (views, ratings, reviews) to identify inconsistent flows, such as sudden spikes in completely different genres, sequences of extreme ratings within a short period, or usage from unusual devices or locations.
	3. The system distinguishes between potentially malicious patterns (e.g., coordinated review bombing across many new users) and genuine shifts in taste (gradual and consistent changes over time), applying adaptive rules and models.
	4. Depending on the type of anomaly, it takes actions such as quarantining certain interactions so they do not affect public metrics, requesting additional user verification, or adjusting the weight of certain genres in the profile to reflect a real evolution of interests.
- **expected outcome:** Greater robustness of recommendations and internal statistics, protection against fraud, and the ability to track the natural evolution of user preferences without overreacting to isolated behaviour.

### Sentiment and Topic Dashboard by User Segment
- **actor:**  Studios, production companies, marketing teams, and content strategy teams.
- **problem:**
- **description:**
- **expected outcome:**
### Use case
- **actor:**  Newly registered user.
- **problem:**
- **description:**
- **expected outcome:**