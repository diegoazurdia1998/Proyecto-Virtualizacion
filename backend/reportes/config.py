import os

class Config:
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME", "db_reportes")
    DB_USER = os.getenv("DB_USER", "usr_reportes")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "rep_pass123")
    INVENTARIO_SERVICE_URL = os.getenv("INVENTARIO_SERVICE_URL", "http://api-inventario:5000")
    PEDIDOS_SERVICE_URL = os.getenv("PEDIDOS_SERVICE_URL", "http://api-pedidos:5000")