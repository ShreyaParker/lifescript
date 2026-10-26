from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from app.core.db import get_db

security = HTTPBearer(auto_error=False)

def get_current_user(credentials: HTTPAuthorizationCredentials | None = Depends(security)) -> str:
    if not credentials or credentials.scheme.lower() != "bearer":
        raise HTTPException(401, "Authentication required", headers={"WWW-Authenticate": "Bearer"})
    db = get_db()
    try:
        response = db.auth.get_user(credentials.credentials)
        if response and response.user:
            return str(response.user.id)
    except Exception:
        pass
    raise HTTPException(401, "Invalid or expired access token", headers={"WWW-Authenticate": "Bearer"})
