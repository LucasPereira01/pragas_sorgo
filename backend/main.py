from fastapi import FastAPI, WebSocket, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import asyncio
import random
import json
import datetime
from backend import crud, models, schemas
from backend.database import SessionLocal, engine

models.Base.metadata.create_all(bind=engine)

print("Starting Sorghum Pest Control Expert System Backend...")
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Base de Conhecimento de Pragas e Controles ---
PEST_KNOWLEDGE_BASE = {
    "Lagarta-do-cartucho": {
        "scientific_name": "Spodoptera frugiperda",
        "levels": {
            "leve": { "method": "Controle Biológico", "agent": "Trichogramma", "efficacy": 0.45, "task_type": "tractor" },
            "moderada": { "method": "Controle Microbiológico", "agent": "Bacillus thuringiensis", "efficacy": 0.28, "task_type": "tractor" },
            "alta": { "method": "Integrado (Bio + Micro)", "agent": "Trichogramma + B. thuringiensis", "efficacy": 0.73, "task_type": "tractor" }
        }
    },
    "Pulgão-verde": {
        "scientific_name": "Schizaphis graminum",
        "levels": {
            "leve": { "method": "Controle Biológico", "agent": "Joaninhas", "efficacy": 0.45, "task_type": "tractor" },
            "moderada": { "method": "Controle Biológico", "agent": "Joaninhas (liberação massiva)", "efficacy": 0.50, "task_type": "tractor" },
            "alta": { "method": "Controle Biológico", "agent": "Joaninhas (liberação massiva)", "efficacy": 0.50, "task_type": "tractor" }
        }
    },
    "Mosca-do-sorgo": {
        "scientific_name": "Stenodiplosis sorghicola",
        "levels": {
            "leve": { "method": "Controle Físico-Mecânico", "agent": "Armadilhas com feromônio", "efficacy": 0.18, "task_type": "person" },
            "moderada": { "method": "Controle Biológico", "agent": "Parasitoides", "efficacy": 0.45, "task_type": "tractor" },
            "alta": { "method": "Integrado (Bio + Físico)", "agent": "Parasitoides + Armadilhas", "efficacy": 0.63, "task_type": "both" }
        }
    },
    "Percevejos-da-panícula": {
        "scientific_name": "Oebalus spp.",
        "levels": {
            "leve": { "method": "Controle Biológico", "agent": "Parasitoides de ovos (Telenomus podisi)", "efficacy": 0.45, "task_type": "tractor" },
            "moderada": { "method": "Controle Biológico", "agent": "Parasitoides de ovos (liberação massiva)", "efficacy": 0.50, "task_type": "tractor" },
            "alta": { "method": "Controle Biológico", "agent": "Parasitoides de ovos (liberação massiva)", "efficacy": 0.50, "task_type": "tractor" }
        }
    },
    "Broca-da-cana": {
        "scientific_name": "Diatraea spp.",
        "levels": {
            "leve": { "method": "Controle Microbiológico", "agent": "Baculovírus", "efficacy": 0.28, "task_type": "tractor" },
            "moderada": { "method": "Controle Microbiológico", "agent": "Baculovírus (aplicação reforçada)", "efficacy": 0.30, "task_type": "tractor" },
            "alta": { "method": "Integrado (Micro + Bio)", "agent": "Baculovírus + Trichogramma", "efficacy": 0.70, "task_type": "tractor" }
        }
    },
    "Larva-arame": {
        "scientific_name": "Conoderus scalaris",
        "levels": { # Ação é sempre preventiva/cultural
            "leve": { "method": "Controle Cultural", "agent": "Rotação de culturas", "efficacy": 0.18, "task_type": "person" },
            "moderada": { "method": "Controle Cultural", "agent": "Rotação de culturas", "efficacy": 0.18, "task_type": "person" },
            "alta": { "method": "Controle Cultural", "agent": "Rotação de culturas", "efficacy": 0.18, "task_type": "person" }
        }
    }
}

# --- Motor de Decisão ---
def generate_service_order(pest_type, infestation_level):
    if pest_type not in PEST_KNOWLEDGE_BASE:
        return { "action": "None", "details": "Praga não reconhecida." }

    pest_info = PEST_KNOWLEDGE_BASE[pest_type]
    
    level = "leve"
    if infestation_level > 0.7:
        level = "alta"
    elif infestation_level > 0.3:
        level = "moderada"

    decision = pest_info["levels"][level]
    
    service_order = {
        "pest_detected": pest_type,
        "infestation_level": infestation_level,
        "infestation_severity": level,
        "worker_task": None,
        "tractor_task": None,
    }

    task_details = {
        "method": decision["method"],
        "agent": decision["agent"],
        "efficacy": decision["efficacy"]
    }

    if decision["task_type"] == "person":
        service_order["worker_task"] = task_details
    elif decision["task_type"] == "tractor":
        service_order["tractor_task"] = task_details
    elif decision["task_type"] == "both":
        service_order["worker_task"] = { "method": "Controle Físico-Mecânico", "agent": "Instalar Armadilhas com feromônio", "efficacy": 0.18 }
        service_order["tractor_task"] = { "method": "Controle Biológico", "agent": "Liberar Parasitoides", "efficacy": 0.45 }

    if service_order["worker_task"] or service_order["tractor_task"]:
        service_order["action"] = "Execute"
    else:
        service_order["action"] = "None"

    return service_order

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, db: Session = Depends(get_db)):
    await websocket.accept()
    print("WebSocket connection established")
    
    while True:
        try:
            field = random.randint(1, 4)
            pest_type = random.choice(list(PEST_KNOWLEDGE_BASE.keys()))
            infestation_level = round(random.uniform(0.05, 0.95), 2)

            service_order = generate_service_order(pest_type, infestation_level)
            
            service_order["field"] = field
            service_order["timestamp"] = datetime.datetime.utcnow().isoformat()

            # Salva a ordem de serviço no banco de dados
            order_to_save = schemas.ServiceOrderCreate(order_data=json.dumps(service_order))
            crud.create_service_order(db=db, service_order=order_to_save)
            
            await websocket.send_text(json.dumps(service_order))
            print(f"Sent and saved service order for field {field}: {pest_type} ({infestation_level*100:.1f}%)")

            await asyncio.sleep(30)
            
        except Exception as e:
            print(f"Error in WebSocket loop: {e}")
            break
            
    print("WebSocket connection closed")

@app.get("/reports", response_model=list[schemas.ServiceOrder])
def get_reports(db: Session = Depends(get_db)):
    return crud.get_service_orders(db)