import os
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

class Config:
    BILLING_HOST = os.getenv("BILLING_HOST")
    BILLING_PORT = int(os.getenv("BILLING_PORT"))

    DB_HOST = os.getenv("BILLING_DB_HOST")
    DB_PORT = int(os.getenv("BILLING_DB_PORT"))
    DB_NAME = os.getenv("BILLING_DB_NAME")
    DB_USER = os.getenv("BILLING_DB_USER")
    DB_PASSWORD = os.getenv("BILLING_DB_PASSWORD")
    
    RABBITMQ_HOST = os.getenv("RABBITMQ_HOST")
    RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT"))
    RABBITMQ_USER = os.getenv("RABBITMQ_DEFAULT_USER")
    RABBITMQ_PASSWORD = os.getenv("RABBITMQ_DEFAULT_PASS")
    RABBITMQ_QUEUE = os.getenv("RABBITMQ_QUEUE")

    SQLALCHEMY_DATABASE_URI = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
