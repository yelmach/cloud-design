import os
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

class Config:
    INVENTORY_HOST = os.getenv("INVENTORY_HOST")
    INVENTORY_PORT = int(os.getenv("INVENTORY_PORT"))

    DB_HOST = os.getenv("INVENTORY_DB_HOST")
    DB_PORT = os.getenv("INVENTORY_DB_PORT")
    DB_NAME = os.getenv("INVENTORY_DB_NAME")
    DB_USER = os.getenv("INVENTORY_DB_USER")
    DB_PASSWORD = os.getenv("INVENTORY_DB_PASSWORD")

    SQLALCHEMY_DATABASE_URI = (f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}")