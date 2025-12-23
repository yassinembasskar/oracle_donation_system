from fastapi import APIRouter
from ..schemas.donation import DonationCreate, DonationRead

router = APIRouter()


# Liste fictive pour simuler la base de données au début
FAKE_DB = []


@router.get("/", response_model=list[DonationRead])
async def list_donations():
    """Retourne la liste des dons (en mémoire pour l'instant)."""
    return FAKE_DB


@router.post("/", response_model=DonationRead)
async def create_donation(donation: DonationCreate):
    """Crée un don (stocké en mémoire pour l'instant)."""
    new_donation = DonationRead(
        id=len(FAKE_DB) + 1,
        donor_name=donation.donor_name,
        amount=donation.amount,
        currency=donation.currency,
        message=donation.message,
    )
    FAKE_DB.append(new_donation)
    return new_donation
