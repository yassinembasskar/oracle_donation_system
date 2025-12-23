from pydantic import BaseModel, Field


class DonationBase(BaseModel):
    donor_name: str = Field(..., example="Alice")
    amount: float = Field(..., gt=0, example=100.0)
    currency: str = Field(..., example="EUR")
    message: str | None = Field(default=None, example="Pour les enfants")


class DonationCreate(DonationBase):
    """Données reçues du front-end pour créer un don."""
    pass


class DonationRead(DonationBase):
    """Données renvoyées au front-end après création / lecture."""
    id: int = Field(..., example=1)
