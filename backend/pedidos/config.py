import os

class Config:
    DB_HOST = os.getenv("DB_HOST", "db")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME", "db_pedidos")
    DB_USER = os.getenv("DB_USER", "usr_pedidos")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "ped_pass123")
    INVENTARIO_SERVICE_URL = os.getenv("INVENTARIO_SERVICE_URL", "http://api-inventario:5000")