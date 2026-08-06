import asyncio
import sys
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

sys.path.insert(0, r'C:\Users\Habeeb\Lockin\egg-guardian\services\api')

from app.main import app
from app.database import Base, get_db

TEST_DATABASE_URL = 'sqlite+aiosqlite:///:memory:'
engine = create_async_engine(TEST_DATABASE_URL, connect_args={'check_same_thread': False}, poolclass=StaticPool)
TestingSessionLocal = sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

async def override_get_db():
    async with TestingSessionLocal() as session:
        yield session

async def run():
    # create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as ac:
        payload = {"email": "dupe@example.com", "password": "testpass123", "full_name": "Dupe User", "job_role": "Tester"}
        r1 = await ac.post('/api/v1/auth/register', json=payload)
        print('first status', r1.status_code, 'body', r1.text)
        r2 = await ac.post('/api/v1/auth/register', json=payload)
        print('second status', r2.status_code, 'body', r2.text)

    app.dependency_overrides.clear()

if __name__ == '__main__':
    asyncio.run(run())
