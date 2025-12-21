"""Health check endpoint."""

from fastapi import APIRouter

router = APIRouter(tags=["Health"])


@router.get("/healthz")
async def health_check():
    """
    Health check endpoint.
    
    Returns 200 OK if the service is healthy.
    """
    return {"status": "healthy"}
