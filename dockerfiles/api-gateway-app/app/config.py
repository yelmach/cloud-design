import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()


class Config:
    GATEWAY_HOST = os.getenv("GATEWAY_HOST")
    GATEWAY_PORT = int(os.getenv("GATEWAY_PORT"))
    
    INVENTORY_API_URL = os.getenv("INVENTORY_API_URL")
    
    RABBITMQ_HOST = os.getenv("RABBITMQ_HOST")
    RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT"))
    RABBITMQ_USER = os.getenv("RABBITMQ_DEFAULT_USER")
    RABBITMQ_PASSWORD = os.getenv("RABBITMQ_DEFAULT_PASS")
    RABBITMQ_QUEUE =  os.getenv("RABBITMQ_QUEUE")
