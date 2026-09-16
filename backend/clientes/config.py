import os

class Config:
    DB_HOST = os.getenv("DB_HOST", "db")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME", "db_clientes")
    DB_USER = os.getenv("DB_USER", "usr_clientes")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "")