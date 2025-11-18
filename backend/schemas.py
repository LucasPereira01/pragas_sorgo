from pydantic import BaseModel, field_validator
import datetime
import json
from typing import Dict, Any

class PestData(BaseModel):
    timestamp: datetime.datetime
    field: int
    pest_type: str
    infestation_level: float
    action: str
    action_quantity: float

    class Config:
        from_attributes = True

# Schema para criação, recebe a ordem de serviço como string JSON
class ServiceOrderCreate(BaseModel):
    order_data: str

# Schema para leitura, converte a string JSON de volta para um dicionário
class ServiceOrder(BaseModel):
    id: int
    timestamp: datetime.datetime
    order_data: Dict[str, Any]

    @field_validator('order_data', mode='before')
    @classmethod
    def parse_json_string(cls, value):
        if isinstance(value, str):
            return json.loads(value)
        return value

    class Config:
        from_attributes = True
