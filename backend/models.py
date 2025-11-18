from sqlalchemy import Column, Integer, String, Float, DateTime, Text
from backend.database import Base
import datetime

class PestData(Base):
    __tablename__ = "pest_data"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    field = Column(Integer)
    pest_type = Column(String)
    infestation_level = Column(Float)
    action = Column(String)
    action_quantity = Column(Float)

class ServiceOrder(Base):
    __tablename__ = "service_orders"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    order_data = Column(Text) # Usando Text para armazenar o JSON como string
