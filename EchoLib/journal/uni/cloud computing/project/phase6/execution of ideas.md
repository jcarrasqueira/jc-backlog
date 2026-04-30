Executing both options is an ambitious and incredibly strong move for Phase 6. It hits multiple grading criteria perfectly: **Event-Driven Architecture (Option 1)** and **Al Agents/LLMs (Option 2)**.

Since you already have a solid Docker and Kubernetes setup, here is the technical blueprint to execute both features without breaking your existing architecture.

---

### Part 1: Event-Driven LLM Sentiment & Topic Extraction

This introduces an asynchronous background worker and a message broker to process reviews.

**1. The Message Broker (RabbitMQ)**

You need a queue to hold reviews until the LLM is ready to process them. RabbitMQ is perfect for this.

- **Docker Compose:** Add a RabbitMQ container to your `docker-compose.yml`.
    
- **Kubernetes:** You will eventually create an `11-rabbitmq.yaml` deployment and service.
    

**2. Update the Review Service (The Producer)**

When a user submits a review, the Review Service saves it to PostgreSQL and then immediately publishes an event to RabbitMQ. It does _not_ wait for the LLM.

- **Action:** Modify your `POST /movies/{movie_id}/ratings` endpoint.
    
- **Python implementation:** Use the `pika` library to send a message.
    

Python

```
import pika
import json

def publish_review_event(rating_id, review_text):
    connection = pika.BlockingConnection(pika.ConnectionParameters('rabbitmq'))
    channel = connection.channel()
    channel.queue_declare(queue='review_analysis')
    
    event = {"rating_id": rating_id, "text": review_text}
    channel.basic_publish(exchange='', routing_key='review_analysis', body=json.dumps(event))
    connection.close()
```

**3. Build the LLM Worker (The Consumer)**

This is a brand new, isolated Python microservice (`llm-worker`).

- **Action:** Create a script that listens to the `review_analysis` queue.
    
- **LLM Integration:** When a message arrives, send the `review_text` to an LLM. Since this is a student project and hosting a local LLM in K8s requires heavy GPU resources, the easiest path is to use a free API tier (like Groq, Gemini API, or OpenAI) to do the processing.
    
- **Prompting:** _"Analyze this movie review: '[TEXT]'. Respond strictly with a JSON object containing 'sentiment' (Positive, Negative, Neutral) and 'topics' (a list of 1-3 keywords)."_
    
- **Database Update:** The worker parses the JSON response and executes an `UPDATE ratings SET sentiment = 'x', topics = 'y' WHERE id = rating_id;` directly to PostgreSQL.
    

**4. Database Update**

- Update your `init.sql` (and Phase 5 dump file) to include `sentiment VARCHAR(50)` and `topics TEXT[]` (or JSONB) columns in the `ratings` table.
    

---

### Part 2: Conversational Recommendations (RAG-Lite)

This upgrades your Recommendation Service to accept natural language prompts and translates them into database queries.

**1. Update the Recommendation Service API**

- **Action:** Add a new endpoint `POST /recommendations/chat`.
    
- **Request Body:** `{"user_id": 123, "query": "I'm looking for a dark, mind-bending sci-fi movie."}`
    

**2. The LLM Agent (Translating Text to Metadata)**

Instead of doing complex vector embeddings (which is overkill for this phase), use the LLM to act as a translation agent.

- **Prompting:** When the user sends their query, the Recommendation Service sends a prompt to the LLM:
    
    - _"The user wants a movie recommendation. Their query is: '[QUERY]'. Based on this, extract the genres they want, the genres they don't want, and the general mood. Return ONLY a JSON object: `{"include_genres": [], "exclude_genres": []}`."_
        

**3. Merge with Your Existing Algorithm**

Once the LLM returns the JSON of extracted genres, feed that directly into the fantastic scoring algorithm you already built in Phase 4!

- If the LLM extracts "Sci-Fi" and "Thriller", artificially boost those genres in your weighted scoring system (e.g., +3.0 points) for this specific request.
    
- Fetch the top 5 movies from PostgreSQL based on these newly weighted scores and return them to the user.
    

---

### Summary of What to Deliver for Phase 6

To fulfill the requirements for the Phase 6 markdown deliverable, you should document:

1. **Use Cases:** Explain the two new features (Async Review Analysis & AI Chat Recommendations).
    
2. **Requirements:** Mention Event-Driven decoupling, async processing, and LLM text-to-JSON extraction.
    
3. **Technical Architecture:** Diagram showing the new RabbitMQ component, the LLM Worker, and the external LLM API calls.
    
4. **Deployment Plan:** Detail the new Dockerfile for the worker, the RabbitMQ K8s deployment, and updating your ConfigMaps to include external LLM API keys securely (using Secrets).
    

Which part of this stack feels like the biggest unknown for you right now—setting up the RabbitMQ message broker, or wiring up the Python code for the LLM prompts?