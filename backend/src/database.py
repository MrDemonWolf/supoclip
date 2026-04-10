import os

from dotenv import load_dotenv
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

# Load environment variables
load_dotenv()

DEFAULT_DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql+asyncpg://localhost:5432/supoclip"
)

_database_url_override: str | None = None
_engine_override: AsyncEngine | None = None
_session_maker_override: async_sessionmaker[AsyncSession] | None = None
_engine: AsyncEngine | None = None
_session_maker: async_sessionmaker[AsyncSession] | None = None


# Base class for all models
class Base(DeclarativeBase):
    pass


def _build_engine(database_url: str) -> AsyncEngine:
    return create_async_engine(
        database_url,
        echo=False,
        pool_size=10,
        max_overflow=20,
        pool_pre_ping=True,
        pool_recycle=3600,
    )


def get_database_url() -> str:
    return _database_url_override or os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL)


def configure_database(
    *,
    database_url: str | None = None,
    engine: AsyncEngine | None = None,
    session_maker: async_sessionmaker[AsyncSession] | None = None,
) -> None:
    global _database_url_override, _engine_override, _session_maker_override
    _database_url_override = database_url
    _engine_override = engine
    _session_maker_override = session_maker


def get_engine() -> AsyncEngine:
    global _engine
    if _engine_override is not None:
        return _engine_override
    if _engine is None:
        _engine = _build_engine(get_database_url())
    return _engine


def get_session_maker() -> async_sessionmaker[AsyncSession]:
    global _session_maker
    if _session_maker_override is not None:
        return _session_maker_override
    if _session_maker is None:
        _session_maker = async_sessionmaker(
            get_engine(),
            class_=AsyncSession,
            expire_on_commit=False,
        )
    return _session_maker


def AsyncSessionLocal() -> AsyncSession:
    return get_session_maker()()


# Dependency to get database session
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


# Initialize database
# Schema is owned by Prisma. Migrations run via `prisma migrate deploy` in the
# migrate service before the backend starts. This function is a no-op DDL-wise.
async def init_db():
    pass


# Close database connections
async def close_db():
    global _engine, _session_maker
    engine = _engine_override or _engine
    if engine is not None:
        await engine.dispose()
    _engine = None
    _session_maker = None


async def reset_database_state() -> None:
    global _database_url_override, _engine_override, _session_maker_override
    await close_db()
    _database_url_override = None
    _engine_override = None
    _session_maker_override = None
