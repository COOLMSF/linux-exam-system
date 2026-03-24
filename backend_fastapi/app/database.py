from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import settings


dm8_engine = create_engine(settings.dm8_dsn, pool_pre_ping=True, future=True)
mysql_engine = create_engine(settings.mysql_dsn, pool_pre_ping=True, future=True)

DM8SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=dm8_engine)
MySQLSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=mysql_engine)


def get_dm8_db() -> Generator[Session, None, None]:
    db = DM8SessionLocal()
    try:
        yield db
    finally:
        db.close()
