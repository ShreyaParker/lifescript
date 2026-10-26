# Manual probe: may access external services and write development data.
if __name__ == "__main__":
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.security import get_current_user
    import uuid
    
    # Override the auth dependency so we can test the 500 error
    app.dependency_overrides[get_current_user] = lambda: str(uuid.uuid4())
    
    client = TestClient(app)
    
    response = client.post("/journal/submit", json={"content": "Today I spent about 2 hours watching a long YouTube crash course on Neural Networks and building deep learning models, but I got overwhelmed by the matrix calculus math halfway through. I ended up opening Instagram and procrastinating for the rest of the afternoon. I didn't get any coding practice done on my laptop, which frustrates me because I really want to master AI engineering before my MCA semester ends. On a positive note, I drank 3 liters of water today and went for a short 20-minute evening walk to clear my head."})
    print(response.status_code)
    print(response.json())
