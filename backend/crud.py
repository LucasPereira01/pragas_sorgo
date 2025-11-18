from sqlalchemy.orm import Session
from sqlalchemy import desc
from backend import models, schemas

def get_pest_data(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.PestData).offset(skip).limit(limit).all()

def create_pest_data(db: Session, pest_data: schemas.PestData):
    db_pest_data = models.PestData(**pest_data.dict())
    db.add(db_pest_data)
    db.commit()
    db.refresh(db_pest_data)
    return db_pest_data

# --- Novas funções para Ordens de Serviço ---

def create_service_order(db: Session, service_order: schemas.ServiceOrderCreate):
    db_service_order = models.ServiceOrder(order_data=service_order.order_data)
    db.add(db_service_order)
    db.commit()
    db.refresh(db_service_order)
    return db_service_order

def get_service_orders(db: Session, skip: int = 0, limit: int = 100):
    # Retorna as ordens mais recentes primeiro
    return db.query(models.ServiceOrder).order_by(desc(models.ServiceOrder.timestamp)).offset(skip).limit(limit).all()
