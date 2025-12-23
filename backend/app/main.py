from fastapi import FastAPI
from app.core.config import settings
from app.api.routes.health import router as health_router

app = FastAPI(title=settings.APP_NAME)

@app.get("/")
def root():
    return {"message": f"Welcome to {settings.APP_NAME}"}

app.include_router(health_router, prefix="/api/health", tags=["health"])
