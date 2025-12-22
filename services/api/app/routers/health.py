"""Health check and root endpoints."""

from fastapi import APIRouter
from fastapi.responses import RedirectResponse

router = APIRouter(tags=["Health"])


@router.get("/", include_in_schema=False)
async def root():
    """Redirect root to API documentation."""
    return RedirectResponse(url="/docs")


@router.get("/healthz")
async def health_check():
    """
    Health check endpoint.
    
    Returns 200 OK if the service is healthy.
    """
    return {"status": "healthy"}
