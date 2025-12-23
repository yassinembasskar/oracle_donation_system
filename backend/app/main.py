from fastapi import FastAPI
from .routers import donations  # on créera le fichier juste après

app = FastAPI(
    title="Oracle Donation Backend",
    description="API pour le système de dons (Oracle + FastAPI).",
    version="0.1.0",
)


@app.get("/")
async def root():
    return {"message": "Backend Oracle Donation System fonctionnel"}


# Inclure les routes de donations (même si elles sont simples au début)
app.include_router(donations.router, prefix="/donations", tags=["donations"])
