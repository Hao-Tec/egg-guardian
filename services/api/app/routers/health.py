"""Health check and root endpoints."""

from pathlib import Path
from fastapi import APIRouter
from fastapi.responses import FileResponse, RedirectResponse

router = APIRouter(tags=["Health"])

STATIC_DIR = Path(__file__).parent.parent / "static"


@router.get("/", include_in_schema=False)
async def root():
    """Redirect root to API documentation."""
    return RedirectResponse(url="/docs")


@router.get("/favicon.ico", include_in_schema=False)
async def favicon():
    """Serve favicon."""
    favicon_path = STATIC_DIR / "favicon.png"
    if favicon_path.exists():
        return FileResponse(favicon_path, media_type="image/png")
    return RedirectResponse(url="/docs")


@router.get("/healthz")
async def health_check():
    """
    Health check endpoint.
    
    Returns 200 OK if the service is healthy.
    """
    return {"status": "healthy"}
