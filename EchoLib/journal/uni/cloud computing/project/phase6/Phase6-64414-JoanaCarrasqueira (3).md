# CC2526 — Phase 6
*Joana Carrasqueira, 64414*  
*branch: jcarrasqueira*

---

## Plan for Phase 7: LLM Integration into Existing Microservices

### Overview

This phase extends the two existing microservices with LLM capabilities using **Google Cloud Vertex AI (Gemini 1.5 Flash)**. The LLM runs at **write time** — when a review is created or updated — and persists its results into the `review_sentiment` and `rating_topics` tables that already exist in the database schema. Read endpoints then aggregate from those tables cheaply, with no LLM call on the read path.

Authentication to Vertex AI uses **GKE Workload Identity** — no API keys, no secrets.

---

## What Changes and Where

### 1. `review-system/` — two changes

**A) New file: `llm_client.py`**

Wraps the Vertex AI SDK. Called after a rating with a non-empty `review` field is saved.

```python
# review-system/llm_client.py

import json
import vertexai
from vertexai.generative_models import GenerativeModel
import os

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
REGION     = os.getenv("GCP_REGION", "europe-west1")

vertexai.init(project=PROJECT_ID, location=REGION)
_model = GenerativeModel("gemini-1.5-flash")

def analyse_review(review_text: str) -> dict:
    """
    Returns {"sentiment": "positive"|"negative"|"neutral", "topics": ["acting", ...]}
    Falls back to {"sentiment": "neutral", "topics": []} on any error.
    """
    prompt = f"""You are a movie review analyst.
Analyse the following review and return a JSON object with exactly two keys:
- "sentiment": one of "positive", "negative", or "neutral"
- "topics": a list of up to 5 short topic strings (e.g. "acting", "plot", "pacing", "special effects", "cinematography")

Review:
{review_text[:500]}

Respond with only valid JSON and nothing else."""

    try:
        response = _model.generate_content(prompt)
        text = response.text.strip().removeprefix("```json").removesuffix("```").strip()
        return json.loads(text)
    except Exception as e:
        print(f"[llm_client] Vertex AI error: {e}")
        return {"sentiment": "neutral", "topics": []}
```

**B) `ratings.py` — hook LLM into create and update**

Two places need touching: `create_rating` (after `db.refresh`) and `update_rating` (after `db.refresh`). Extract the logic into a helper so it is not duplicated.

Add these ORM models to `config.py` first (see section 3 below), then add the helper and hook it in:

```python
# add to ratings.py imports
from config import ReviewSentimentTable, TopicTable, RatingTopicTable
from llm_client import analyse_review
from datetime import timezone

# ── helper ────────────────────────────────────────────────────────────────────
def _persist_llm_analysis(rating_id: int, review_text: str, db: Session):
    """Fire-and-forget: run LLM, write to review_sentiment and rating_topics."""
    if not review_text or not review_text.strip():
        return

    result = analyse_review(review_text)

    # upsert sentiment (delete old row first if this is an update)
    db.query(ReviewSentimentTable)\
      .filter(ReviewSentimentTable.rating_id == rating_id)\
      .delete()

    sentiment_row = ReviewSentimentTable(
        rating_id=rating_id,
        sentiment_label=result.get("sentiment", "neutral"),
        created_at=datetime.now(timezone.utc),
    )
    db.add(sentiment_row)

    # upsert topics
    db.query(RatingTopicTable)\
      .filter(RatingTopicTable.rating_id == rating_id)\
      .delete()

    for topic_name in result.get("topics", []):
        topic_name = topic_name.strip().lower()
        if not topic_name:
            continue
        topic = db.query(TopicTable).filter(TopicTable.name == topic_name).first()
        if not topic:
            topic = TopicTable(name=topic_name)
            db.add(topic)
            db.flush()  # get topic_id before commit

        db.add(RatingTopicTable(rating_id=rating_id, topic_id=topic.topic_id))

    db.commit()
```

Hook it in `create_rating`, right after the final `db.refresh(new_rating)`:

```python
        db.refresh(new_rating)
        # ── LLM analysis (non-blocking, best-effort) ──
        try:
            _persist_llm_analysis(new_rating.rating_id, new_rating.review, db)
        except Exception as e:
            print(f"[LLM] analysis failed for rating {new_rating.rating_id}: {e}")
        return new_rating
```

Same hook in `update_rating`, after `db.refresh(rating)`:

```python
        db.refresh(rating)
        try:
            _persist_llm_analysis(rating.rating_id, rating.review, db)
        except Exception as e:
            print(f"[LLM] analysis failed for rating {rating.rating_id}: {e}")
        return {"status_code": 200, "detail": "Rating updated successfully"}
```

**C) New endpoint in `ratings.py` — movie review summary (read path, no LLM)**

```python
class ReviewSummary(BaseModel):
    movie_id: int
    total_reviews: int
    sentiment_breakdown: dict   # {"positive": 12, "negative": 3, "neutral": 5}
    top_topics: list[str]       # top 5 by frequency

@app.get("/movies/{movie_id}/review-summary", response_model=ReviewSummary)
def get_movie_review_summary(
    movie_id: int = Path(description="The ID of the movie"),
    db: Session = Depends(get_db)
):
    try:
        movie = db.query(Movie).filter(Movie.movie_id == movie_id).first()
        if not movie:
            raise HTTPException(status_code=404, detail="Movie does not exist")

        # ratings that have been analysed
        analysed_rating_ids = (
            db.query(ReviewSentimentTable.rating_id)
            .join(RatingTable, RatingTable.rating_id == ReviewSentimentTable.rating_id)
            .filter(RatingTable.movie_id == movie_id, RatingTable.is_quarantined == False)
            .all()
        )
        analysed_ids = [r.rating_id for r in analysed_rating_ids]

        if not analysed_ids:
            raise HTTPException(status_code=404, detail="No analysed reviews for this movie yet")

        # sentiment breakdown
        from sqlalchemy import func as sqlfunc
        sentiment_rows = (
            db.query(ReviewSentimentTable.sentiment_label, sqlfunc.count())
            .filter(ReviewSentimentTable.rating_id.in_(analysed_ids))
            .group_by(ReviewSentimentTable.sentiment_label)
            .all()
        )
        sentiment_breakdown = {label: count for label, count in sentiment_rows}

        # top topics
        topic_rows = (
            db.query(TopicTable.name, sqlfunc.count(RatingTopicTable.rating_topic_id))
            .join(RatingTopicTable, RatingTopicTable.topic_id == TopicTable.topic_id)
            .filter(RatingTopicTable.rating_id.in_(analysed_ids))
            .group_by(TopicTable.name)
            .order_by(sqlfunc.count(RatingTopicTable.rating_topic_id).desc())
            .limit(5)
            .all()
        )
        top_topics = [name for name, _ in topic_rows]

        return ReviewSummary(
            movie_id=movie_id,
            total_reviews=len(analysed_ids),
            sentiment_breakdown=sentiment_breakdown,
            top_topics=top_topics,
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error generating review summary: {e}")
        raise HTTPException(status_code=500, detail="Error generating review summary")
```

---

### 2. `recommendations/` — one new endpoint

Add `llm_client.py` (same file as review-system, identical content) and a new endpoint in `recommendations.py`.

**New file: `recommendations/llm_client.py`** — exact same content as `review-system/llm_client.py` above, but with a different function:

```python
# recommendations/llm_client.py

import json
import vertexai
from vertexai.generative_models import GenerativeModel
import os

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
REGION     = os.getenv("GCP_REGION", "europe-west1")

vertexai.init(project=PROJECT_ID, location=REGION)
_model = GenerativeModel("gemini-1.5-flash")

def explain_recommendations(liked_genres: list[str], ref_titles: list[str], movies: list[dict]) -> list[str]:
    """
    movies: [{"title": "...", "genres": [...], "score": 4.5}, ...]
    Returns a list of explanation strings, one per movie, in the same order.
    Falls back to empty strings on error.
    """
    numbered = "\n".join(
        f"{i+1}. {m['title']} (genres: {', '.join(m['genres'])}, score: {m['score']:.1f})"
        for i, m in enumerate(movies)
    )
    prompt = f"""You are a movie recommendation assistant.
Explain in one short friendly sentence why each movie was recommended to a user with the following profile.

Liked genres: {', '.join(liked_genres) or 'none specified'}
Reference movies they love: {', '.join(ref_titles) or 'none specified'}

Recommendations:
{numbered}

Respond with only a JSON array of strings, one explanation per movie, in the same order as the list above."""

    try:
        response = _model.generate_content(prompt)
        text = response.text.strip().removeprefix("```json").removesuffix("```").strip()
        explanations = json.loads(text)
        if isinstance(explanations, list):
            return [str(e) for e in explanations]
        return ["" for _ in movies]
    except Exception as e:
        print(f"[llm_client] Vertex AI error: {e}")
        return ["" for _ in movies]
```

**New endpoint in `recommendations.py`:**

```python
# add to recommendations.py imports
from llm_client import explain_recommendations

class RecommendationExplained(BaseModel):
    movie_id: int
    title: str
    explanation: str

@app.get("/recommendations/{user_id}/explained", response_model=List[RecommendationExplained])
async def get_recommendations_explained(
    user_id: int,
    db: Session = Depends(get_db),
    review: ReviewGrpcClient = Depends(get_review_client),
):
    # re-use existing algorithm to get the top-5
    recs = await get_recommendations(user_id, db, review)  # returns List[Recommendation]

    if not recs:
        return []

    # build context for the LLM
    liked_genres = [
        db.query(Genre).filter(Genre.genre_id == p.genre_id).first().name
        for p in db.query(UserPreferenceTable)
                   .filter(UserPreferenceTable.user_id == user_id,
                           UserPreferenceTable.preference_type == "like").all()
        if db.query(Genre).filter(Genre.genre_id == p.genre_id).first()
    ]

    ref_titles = [
        m.movie_title
        for ref in db.query(UserReferenceMovieTable)
                     .filter(UserReferenceMovieTable.user_id == user_id).all()
        for m in [db.query(Movie).filter(Movie.movie_id == ref.movie_id).first()]
        if m
    ]

    movies_ctx = []
    for rec in recs:
        movie = db.query(Movie).filter(Movie.movie_id == rec.movie_id).first()
        genre_names = [g.name for g in movie.genres] if movie else []
        movies_ctx.append({"title": rec.title, "genres": genre_names, "score": 0.0})

    explanations = explain_recommendations(liked_genres, ref_titles, movies_ctx)

    return [
        RecommendationExplained(
            movie_id=rec.movie_id,
            title=rec.title,
            explanation=explanations[i] if i < len(explanations) else "",
        )
        for i, rec in enumerate(recs)
    ]
```

---

### 3. `config.py` (review-system) — add three ORM models

Append to `review-system/config.py`:

```python
from sqlalchemy import Numeric

class ReviewSentimentTable(Base):
    __tablename__ = "review_sentiment"

    sentiment_id  = Column(Integer, primary_key=True, index=True)
    rating_id     = Column(Integer, ForeignKey("ratings.rating_id"), nullable=False)
    sentiment_label = Column(String(20), nullable=False)
    sentiment_score = Column(Numeric(4, 3), nullable=True)
    created_at    = Column(DateTime, nullable=False)

class TopicTable(Base):
    __tablename__ = "topics"

    topic_id = Column(Integer, primary_key=True, index=True)
    name     = Column(String(100), unique=True, nullable=False)

class RatingTopicTable(Base):
    __tablename__ = "rating_topics"

    rating_topic_id = Column(Integer, primary_key=True, index=True)
    rating_id       = Column(Integer, ForeignKey("ratings.rating_id"), nullable=False)
    topic_id        = Column(Integer, ForeignKey("topics.topic_id"), nullable=False)
    relevance_score = Column(Numeric(4, 3), nullable=True)
```

---

### 4. `requirements.txt` — add Vertex AI SDK to both services

In both `review-system/requirements.txt` and `recommendations/requirements.txt`, add:

```
google-cloud-aiplatform==1.71.1
```

---

### 5. `.env.example` — add two new variables

```
GCP_PROJECT_ID=your-gcp-project-id
GCP_REGION=europe-west1
```

These are non-sensitive so they can go in the **ConfigMap** (`k8s/00-configmap.yaml`) rather than a Secret:

```yaml
# add to k8s/00-configmap.yaml
GCP_PROJECT_ID: "your-gcp-project-id"
GCP_REGION: "europe-west1"
```

And reference them in the Deployment env sections of `k8s/09-reviews-service.yaml` and `k8s/10-recommendations-service.yaml`:

```yaml
- name: GCP_PROJECT_ID
  valueFrom:
    configMapKeyRef:
      name: group8-config
      key: GCP_PROJECT_ID
- name: GCP_REGION
  valueFrom:
    configMapKeyRef:
      name: group8-config
      key: GCP_REGION
```

---

## GCP Setup Commands (run once before deploying)

```bash
# 1. enable Vertex AI
gcloud services enable aiplatform.googleapis.com

# 2. create the service account
gcloud iam service-accounts create review-intelligence-sa \
  --display-name="Review Intelligence SA"

# 3. grant only what is needed
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="serviceAccount:review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# 4. bind Workload Identity to the review-system pod's KSA
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/reviews-service-ksa]"

# 5. bind Workload Identity to the recommendations pod's KSA
gcloud iam service-accounts add-iam-policy-binding \
  review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<PROJECT_ID>.svc.id.goog[group8/recommendations-service-ksa]"
```

Then annotate each KSA (add this annotation to the `metadata` in your existing KSA manifests, or patch inline):

```bash
kubectl annotate serviceaccount reviews-service-ksa \
  iam.gke.io/gcp-service-account=review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  -n group8

kubectl annotate serviceaccount recommendations-service-ksa \
  iam.gke.io/gcp-service-account=review-intelligence-sa@<PROJECT_ID>.iam.gserviceaccount.com \
  -n group8
```

---

## Rebuild and Redeploy

```bash
# review service
docker build -t jrcarrasqueira/review-system:v2.0 ./review-system
docker push jrcarrasqueira/review-system:v2.0
kubectl set image deployment/reviews-service \
  reviews-service=jrcarrasqueira/review-system:v2.0 -n group8

# recommendations service
docker build -t jrcarrasqueira/recommendations:v2.0 ./recommendations
docker push jrcarrasqueira/recommendations:v2.0
kubectl set image deployment/recommendations-service \
  recommendations-service=jrcarrasqueira/recommendations:v2.0 -n group8

# apply updated configmap
kubectl apply -f k8s/00-configmap.yaml

# verify rollout
kubectl rollout status deployment/reviews-service -n group8
kubectl rollout status deployment/recommendations-service -n group8
```

---

## Quick Smoke Test

```bash
# port-forward review service
kubectl port-forward svc/reviews-service 8003:8003 -n group8

# create a rating with a review text
curl -X POST http://localhost:8003/movies/1/ratings \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "rating": 4.0, "review": "Great cinematography and a gripping plot, though the pacing was slow in the second act."}'

# read the summary (after the LLM has written to review_sentiment and rating_topics)
curl http://localhost:8003/movies/1/review-summary

# port-forward recommendations service
kubectl port-forward svc/recommendations-service 8004:8004 -n group8

# get explained recommendations
curl http://localhost:8004/recommendations/1/explained
```

---

## Summary of Files Changed

| File | Change |
|---|---|
| `review-system/llm_client.py` | **new** — Vertex AI wrapper, `analyse_review()` |
| `review-system/ratings.py` | add `_persist_llm_analysis` helper, hook into `create_rating` and `update_rating`, add `GET /movies/{id}/review-summary` |
| `review-system/config.py` | add `ReviewSentimentTable`, `TopicTable`, `RatingTopicTable` ORM models |
| `review-system/requirements.txt` | add `google-cloud-aiplatform` |
| `recommendations/llm_client.py` | **new** — Vertex AI wrapper, `explain_recommendations()` |
| `recommendations/recommendations.py` | add `GET /recommendations/{user_id}/explained` endpoint |
| `recommendations/requirements.txt` | add `google-cloud-aiplatform` |
| `k8s/00-configmap.yaml` | add `GCP_PROJECT_ID` and `GCP_REGION` |
| `k8s/09-reviews-service.yaml` | reference new configmap keys in env |
| `k8s/10-recommendations-service.yaml` | reference new configmap keys in env |
