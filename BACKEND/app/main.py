"""
VITREFLAM - Backend Chatbot Max
Version amelioree avec memoire complete et contexte intelligent
"""

import os
import logging
import uuid
import re
from datetime import datetime, timedelta
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from dotenv import load_dotenv
import httpx
import anthropic

# Charger les variables d'environnement
load_dotenv()

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

# Configuration
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")

# Client Claude
claude: Optional[anthropic.Anthropic] = None

# Headers pour Supabase REST API
SUPABASE_HEADERS = {
    "apikey": SUPABASE_KEY or "",
    "Authorization": f"Bearer {SUPABASE_KEY or ''}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

# System prompt pour Max - Version amelioree
SYSTEM_PROMPT = """Tu es Max, conseiller SAV expert chez Vitreflam, specialiste du verre ceramique sur-mesure pour cheminees et poeles depuis 1985.

## TA PERSONNALITE
- Professionnel, chaleureux et efficace
- Tu connais parfaitement les produits Vitreflam
- Tu te souviens des echanges precedents avec le client
- Tu personnalises tes reponses en fonction du contexte

## TES MISSIONS
1. **SAV** (priorite): Gerer casse, retard, dimensions, remboursement
2. **Conseil**: Aider sur les produits, dimensions, types de verre
3. **Accompagnement**: Guider pour commander sur www.vitreflam.com
4. **Suivi**: Informer sur l'etat des commandes

## PRODUITS VITREFLAM
- Verre ceramique haute temperature (jusqu'a 800°C)
- Dimensions sur-mesure: 50mm a 780mm
- Epaisseurs: 4mm, 5mm (standard poeles/inserts)
- Formes: rectangulaire, carree, avec coins arrondis
- Decoupe precise au mm pres

## ASSURANCES (IMPORTANT)
- **Assurance Transport**: Couvre casse a la livraison, delai 48h pour signaler
- **Assurance Montage**: Couvre casse pendant installation, delai 8 jours

## REGLES DE COMMUNICATION
- 2-3 phrases max, vouvoiement
- Pas d'emojis
- **Gras** pour les infos importantes
- Si le client revient, fais reference a vos echanges precedents
- Ne rejette JAMAIS un client, aide-le quelle que soit sa demande
- Le client PEUT envoyer des photos directement dans ce chat - encourage-le a le faire
- Si tu ne peux pas resoudre, propose contact: contactglassgroup@gmail.com

## PROCEDURES SAV
- Casse transport avec assurance (dans les 48h): Remplacement gratuit apres photos
- Casse transport sans assurance: Remboursement transporteur uniquement
- Casse montage avec assurance (dans les 8j): Remplacement a 50% du prix
- Probleme dimensions: Verifier commande vs recu, refaire si erreur Vitreflam
- Retard livraison: Verifier suivi, proposer geste commercial si > 7 jours"""

# System prompt STRICT pour analyse d'images
IMAGE_ANALYSIS_PROMPT = """Tu es un expert en analyse de dommages sur verre/vitroceramique pour le SAV Vitreflam.

## TA MISSION
Analyser RIGOUREUSEMENT les photos envoyees par les clients pour determiner si le verre est REELLEMENT casse ou endommage.

## REGLES D'ANALYSE STRICTES

### CE QUI CONSTITUE UNE CASSE VALIDE:
- Fissures visibles traversant le verre
- Eclats ou morceaux manquants
- Bris complet en plusieurs morceaux
- Impact visible avec rayonnement de fissures

### CE QUI N'EST PAS UNE CASSE:
- Rayures superficielles
- Traces de doigts ou salete
- Reflets ou jeux de lumiere
- Photo floue ou mal cadree
- Image sans rapport avec du verre
- Verre intact meme s'il y a un emballage abime

### VERIFICATION DE L'EMBALLAGE:
- Si photo d'emballage: verifier s'il est vraiment endommage (trous, deformations, ecrasement)
- Un carton un peu abime ne signifie pas que le verre est casse

## FORMAT DE REPONSE
Tu dois TOUJOURS donner:
1. **VERDICT**: CASSE_CONFIRMEE / CASSE_NON_CONFIRMEE / PHOTO_INSUFFISANTE
2. **CONFIANCE**: Pourcentage de certitude (ex: 85%)
3. **DETAILS**: Ce que tu vois precisement dans l'image
4. **RECOMMANDATION**: Action a prendre

## IMPORTANT
- Sois SCEPTIQUE par defaut
- Ne confirme une casse QUE si tu vois clairement des dommages
- En cas de doute, demande une meilleure photo
- Ne te laisse pas influencer par le message du client
- Base ton analyse UNIQUEMENT sur ce que tu VOIS dans l'image"""


class ChatRequest(BaseModel):
    email: str
    message: str
    session_id: Optional[str] = None
    image_base64: Optional[str] = None
    image_type: Optional[str] = None
    language: Optional[str] = "fr"


# Instructions de langue pour le chatbot
LANGUAGE_INSTRUCTIONS = {
    "fr": "IMPORTANT: Tu dois repondre en FRANCAIS.",
    "en": "IMPORTANT: You MUST respond in ENGLISH.",
    "it": "IMPORTANTE: Devi rispondere in ITALIANO.",
    "es": "IMPORTANTE: Debes responder en ESPANOL.",
    "de": "WICHTIG: Du musst auf DEUTSCH antworten.",
    "zh": "重要：你必须用中文回复。"
}


class ChatResponse(BaseModel):
    response: str
    session_id: str
    status: str
    image_analysis: Optional[dict] = None


# ============================================================
# FONCTIONS SUPABASE
# ============================================================

async def supabase_request(method: str, endpoint: str, data: dict = None) -> dict:
    """Fait une requete HTTP a Supabase REST API"""
    url = f"{SUPABASE_URL}/rest/v1/{endpoint}"

    async with httpx.AsyncClient() as client:
        try:
            if method == "GET":
                response = await client.get(url, headers=SUPABASE_HEADERS, timeout=10.0)
            elif method == "POST":
                response = await client.post(url, headers=SUPABASE_HEADERS, json=data, timeout=10.0)
            elif method == "PATCH":
                response = await client.patch(url, headers=SUPABASE_HEADERS, json=data, timeout=10.0)
            else:
                return {"error": f"Method {method} not supported"}

            if response.status_code >= 400:
                return {"error": f"HTTP {response.status_code}: {response.text}"}

            return response.json() if response.text else {}
        except Exception as e:
            logger.warning(f"Supabase request error: {e}")
            return {"error": str(e)}


async def test_supabase() -> bool:
    """Teste la connexion Supabase"""
    result = await supabase_request("GET", "knowledge_base?select=id&limit=1")
    if "error" in result:
        logger.error(f"Erreur Supabase: {result['error']}")
        return False
    logger.info("Connexion Supabase OK")
    return True


async def get_or_create_client(email: str) -> dict:
    """Recupere ou cree un client dans Supabase"""
    email_clean = email.lower().strip()

    # Chercher le client existant
    result = await supabase_request("GET", f"clients?select=*&email=eq.{email_clean}&limit=1")

    if isinstance(result, list) and len(result) > 0:
        # Client existe, mettre a jour derniere_interaction
        client = result[0]
        await supabase_request(
            "PATCH",
            f"clients?id=eq.{client['id']}",
            {"derniere_interaction": datetime.now().isoformat()}
        )
        logger.info(f"Client existant: {email_clean}")
        return client

    # Creer nouveau client
    new_client = {
        "email": email_clean,
        "segment": "nouveau"
    }

    result = await supabase_request("POST", "clients", new_client)

    if isinstance(result, list) and len(result) > 0:
        logger.info(f"Nouveau client cree: {email_clean}")
        return result[0]

    return {"email": email_clean, "segment": "nouveau"}


async def get_or_create_conversation(client_id: str, session_id: str) -> str:
    """Recupere ou cree une conversation"""

    # Chercher conversation existante pour ce client (en cours)
    result = await supabase_request(
        "GET",
        f"conversations?select=id&client_id=eq.{client_id}&statut=eq.en_cours&order=started_at.desc&limit=1"
    )

    if isinstance(result, list) and len(result) > 0:
        return result[0]["id"]

    # Creer nouvelle conversation
    conv_id = str(uuid.uuid4())
    new_conv = {
        "id": conv_id,
        "client_id": client_id,
        "canal": "chatbot",
        "statut": "en_cours"
    }

    result = await supabase_request("POST", "conversations", new_conv)

    if isinstance(result, list) and len(result) > 0:
        logger.info(f"Nouvelle conversation creee")
        return result[0]["id"]

    return conv_id


async def update_conversation_context(conversation_id: str, intent: str, message: str):
    """Met a jour le contexte de la conversation (intent, sujet, commande)"""
    if not conversation_id:
        return

    updates = {}

    # Mettre a jour l'intent principal
    if intent and intent != "general" and intent != "salutation":
        updates["intent_principal"] = intent

    # Detecter numero de commande dans le message
    import re
    commande_match = re.search(r'(VF-?\d{4}-?\d+|\d{5,})', message.upper())
    if commande_match:
        updates["commande_concernee"] = commande_match.group(1)

    # Detecter le sujet
    msg_lower = message.lower()
    if "cass" in msg_lower or "bris" in msg_lower:
        updates["sujet"] = "Verre cassé"
    elif "retard" in msg_lower or "livraison" in msg_lower:
        updates["sujet"] = "Problème livraison"
    elif "dimension" in msg_lower or "taille" in msg_lower:
        updates["sujet"] = "Problème dimensions"
    elif "rembours" in msg_lower or "annul" in msg_lower:
        updates["sujet"] = "Demande remboursement"
    elif "command" in msg_lower and ("suivi" in msg_lower or "où" in msg_lower):
        updates["sujet"] = "Suivi commande"
    elif "assurance" in msg_lower:
        updates["sujet"] = "Question assurance"

    if updates:
        await supabase_request("PATCH", f"conversations?id=eq.{conversation_id}", updates)
        logger.info(f"Conversation mise a jour: {updates}")


async def save_message(conversation_id: str, role: str, content: str, intent: str = None):
    """Sauvegarde un message dans Supabase"""

    message = {
        "id": str(uuid.uuid4()),
        "conversation_id": conversation_id,
        "role": role,
        "contenu": content[:2000]
    }
    if intent:
        message["intent_detecte"] = intent

    result = await supabase_request("POST", "messages", message)

    if isinstance(result, list) and len(result) > 0:
        logger.info(f"Message sauvegarde ({role})")


async def create_incident(client_id: str, conversation_id: str, incident_type: str, description: str, photo_analysis: dict = None):
    """Cree un incident SAV dans Supabase"""

    # Verifier si un incident similaire existe deja pour ce client (eviter doublons)
    existing = await supabase_request(
        "GET",
        f"incidents?client_id=eq.{client_id}&type_incident=eq.{incident_type}&statut=in.(ouvert,en_cours,en_attente_photos)&limit=1"
    )

    if isinstance(existing, list) and len(existing) > 0:
        logger.info(f"Incident existant trouve, pas de doublon")
        return existing[0]

    incident = {
        "id": str(uuid.uuid4()),
        "client_id": client_id,
        "conversation_id": conversation_id,
        "type_incident": incident_type,
        "description": description[:500] if description else "",
        "statut": "en_attente_photos" if not photo_analysis else "ouvert",
        "photos_recues": photo_analysis is not None,
        "created_at": datetime.now().isoformat()
    }

    if photo_analysis:
        incident["statut"] = "ouvert"
        incident["metadata"] = {
            "photo_verdict": photo_analysis.get("verdict"),
            "photo_confidence": photo_analysis.get("confidence"),
            "photo_analysis": photo_analysis.get("analysis", "")[:500]
        }

    result = await supabase_request("POST", "incidents", incident)

    if isinstance(result, list) and len(result) > 0:
        logger.info(f"Incident cree: {incident_type} (statut: {incident['statut']})")

        # Incrementer nb_incidents du client
        await supabase_request(
            "PATCH",
            f"clients?id=eq.{client_id}",
            {"nb_incidents": (await supabase_request("GET", f"incidents?client_id=eq.{client_id}&select=id"))
             if False else 1}  # Simple increment pour l'instant
        )

        return result[0]

    return None


async def auto_create_incident_if_needed(client_id: str, conversation_id: str, intent: str, message: str):
    """Cree automatiquement un incident si le message indique un probleme"""
    if not client_id or not conversation_id:
        return None

    # Types d'intent qui declenchent un incident
    incident_intents = {
        "casse_transport": "casse_transport",
        "casse_montage": "casse_montage",
        "casse_general": "casse_general",
        "dimensions": "probleme_dimensions",
        "retard": "retard_livraison",
        "remboursement": "demande_remboursement"
    }

    if intent in incident_intents:
        incident_type = incident_intents[intent]
        return await create_incident(client_id, conversation_id, incident_type, message)

    return None


# ============================================================
# DETECTION FRUSTRATION & ESCALADE
# ============================================================

def detect_frustration(message: str) -> dict:
    """Detecte si le client est frustre et son niveau"""
    msg_lower = message.lower()

    # Mots indicateurs de frustration forte
    strong_frustration = [
        "scandale", "honte", "inadmissible", "inacceptable", "avocat", "justice",
        "arnaque", "voleur", "escroc", "plainte", "proces", "rembourse immediat",
        "jamais plus", "pire", "nul", "catastrophe", "honteux"
    ]

    # Mots indicateurs de frustration moyenne
    medium_frustration = [
        "pas normal", "mecontent", "decu", "attends depuis", "toujours rien",
        "ca fait", "encore", "deja dit", "repete", "agace", "enerve", "furieux",
        "responsable", "chef", "superieur", "direction", "reclamation"
    ]

    # Indicateurs typographiques
    has_caps = sum(1 for c in message if c.isupper()) > len(message) * 0.5
    has_multiple_exclamation = message.count('!') >= 2
    has_multiple_question = message.count('?') >= 3

    # Calculer le score
    score = 0
    triggers = []

    for word in strong_frustration:
        if word in msg_lower:
            score += 30
            triggers.append(word)

    for word in medium_frustration:
        if word in msg_lower:
            score += 15
            triggers.append(word)

    if has_caps:
        score += 20
        triggers.append("MAJUSCULES")

    if has_multiple_exclamation:
        score += 10
        triggers.append("!!!")

    if has_multiple_question:
        score += 5
        triggers.append("???")

    # Determiner le niveau
    if score >= 50:
        level = "high"
    elif score >= 25:
        level = "medium"
    else:
        level = "low"

    return {
        "score": min(score, 100),
        "level": level,
        "triggers": triggers,
        "needs_escalation": score >= 50
    }


async def check_and_escalate(conversation_id: str, client_id: str, frustration: dict):
    """Verifie si escalade necessaire et met a jour la conversation"""
    if not frustration.get("needs_escalation"):
        return False

    # Mettre a jour la conversation en escalade
    await supabase_request(
        "PATCH",
        f"conversations?id=eq.{conversation_id}",
        {
            "statut": "escalade",
            "metadata": {
                "frustration_score": frustration["score"],
                "frustration_triggers": frustration["triggers"],
                "escalade_at": datetime.now().isoformat()
            }
        }
    )

    logger.info(f"Conversation escaladee - Score frustration: {frustration['score']}")
    return True


# ============================================================
# CLOTURE AUTOMATIQUE DES CONVERSATIONS
# ============================================================

async def close_inactive_conversations(inactivity_minutes: int = 30):
    """Ferme les conversations inactives depuis X minutes"""

    cutoff_time = (datetime.now() - timedelta(minutes=inactivity_minutes)).isoformat()

    # Trouver les conversations inactives
    # On regarde le dernier message de chaque conversation
    result = await supabase_request(
        "GET",
        f"conversations?select=id,client_id,started_at&statut=eq.en_cours"
    )

    if not isinstance(result, list) or len(result) == 0:
        return 0

    closed_count = 0

    for conv in result:
        conv_id = conv["id"]

        # Verifier le dernier message
        last_msg = await supabase_request(
            "GET",
            f"messages?select=created_at&conversation_id=eq.{conv_id}&order=created_at.desc&limit=1"
        )

        if isinstance(last_msg, list) and len(last_msg) > 0:
            last_msg_time = last_msg[0].get("created_at", "")

            # Si dernier message > 30min, fermer
            if last_msg_time < cutoff_time:
                await close_conversation(conv_id, conv.get("client_id"))
                closed_count += 1

    if closed_count > 0:
        logger.info(f"Conversations fermees pour inactivite: {closed_count}")

    return closed_count


async def close_conversation(conversation_id: str, client_id: str = None):
    """Ferme une conversation et genere un resume"""

    # Generer le resume
    resume = await generate_conversation_summary(conversation_id)

    # Mettre a jour la conversation
    await supabase_request(
        "PATCH",
        f"conversations?id=eq.{conversation_id}",
        {
            "statut": "resolu",
            "ended_at": datetime.now().isoformat(),
            "resume": resume
        }
    )

    logger.info(f"Conversation fermee avec resume")
    return resume


# ============================================================
# GENERATION DE RESUME
# ============================================================

async def generate_conversation_summary(conversation_id: str) -> str:
    """Genere un resume de la conversation avec Claude"""

    # Recuperer tous les messages
    result = await supabase_request(
        "GET",
        f"messages?select=role,contenu&conversation_id=eq.{conversation_id}&order=created_at.asc"
    )

    if not isinstance(result, list) or len(result) == 0:
        return "Conversation vide"

    # Construire le texte de la conversation
    conversation_text = ""
    for msg in result:
        role = "Client" if msg["role"] == "user" else "Max"
        conversation_text += f"{role}: {msg['contenu']}\n"

    # Si pas de Claude, faire un resume simple
    if not claude:
        # Resume basique sans LLM
        nb_messages = len(result)
        client_messages = [m for m in result if m["role"] == "user"]
        first_msg = client_messages[0]["contenu"][:100] if client_messages else ""
        return f"Conversation de {nb_messages} messages. Sujet initial: {first_msg}..."

    # Generer resume avec Claude
    try:
        response = claude.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=200,
            system="""Tu es un assistant qui resume des conversations de service client.
Genere un resume TRES COURT (2-3 phrases max) contenant:
- Le probleme du client (si applicable)
- La solution proposee (si applicable)
- Le statut final (resolu, en attente, escalade)
Pas de formule de politesse, juste les faits.""",
            messages=[
                {"role": "user", "content": f"Resume cette conversation:\n\n{conversation_text}"}
            ]
        )
        return response.content[0].text
    except Exception as e:
        logger.error(f"Erreur generation resume: {e}")
        return f"Conversation de {len(result)} messages"


# ============================================================
# FONCTIONS MEMOIRE AMELIOREES
# ============================================================

async def get_conversation_history(conversation_id: str, limit: int = 10) -> list:
    """Recupere l'historique des messages de la conversation en cours"""
    if not conversation_id:
        return []

    result = await supabase_request(
        "GET",
        f"messages?select=role,contenu&conversation_id=eq.{conversation_id}&order=created_at.asc&limit={limit}"
    )

    if isinstance(result, list) and len(result) > 0:
        history = []
        for msg in result:
            history.append({
                "role": msg["role"],
                "content": msg["contenu"]
            })
        return history

    return []


async def get_client_incidents(client_id: str) -> str:
    """Recupere les incidents passes du client"""
    if not client_id:
        return ""

    result = await supabase_request(
        "GET",
        f"incidents?select=type_incident,statut,description,created_at&client_id=eq.{client_id}&order=created_at.desc&limit=5"
    )

    if not isinstance(result, list) or len(result) == 0:
        return ""

    incidents_text = "\n\n## INCIDENTS PASSES DU CLIENT:\n"
    for inc in result:
        date = inc.get("created_at", "")[:10]
        incidents_text += f"- [{date}] {inc.get('type_incident', 'Inconnu')} - Statut: {inc.get('statut', 'inconnu')}\n"
        if inc.get("description"):
            incidents_text += f"  Detail: {inc['description'][:100]}...\n"

    logger.info(f"Incidents charges: {len(result)}")
    return incidents_text


async def get_client_full_history(client_id: str) -> str:
    """Charge l'historique complet des conversations du client"""
    if not client_id:
        return ""

    # Recuperer les 5 dernieres conversations
    convs = await supabase_request(
        "GET",
        f"conversations?select=id,started_at&client_id=eq.{client_id}&order=started_at.desc&limit=5"
    )

    if not isinstance(convs, list) or len(convs) == 0:
        return ""

    # Recuperer les messages de ces conversations
    all_messages = []
    for conv in convs:
        msgs = await supabase_request(
            "GET",
            f"messages?select=role,contenu,created_at&conversation_id=eq.{conv['id']}&order=created_at.desc&limit=10"
        )
        if isinstance(msgs, list):
            all_messages.extend(msgs)

    if not all_messages:
        return ""

    # Trier par date et garder les 20 derniers
    all_messages.sort(key=lambda x: x.get("created_at", ""))
    recent = all_messages[-20:]

    # Construire le resume
    history_text = "\n\n## HISTORIQUE DES ECHANGES PRECEDENTS:\n"
    for msg in recent:
        role = "Client" if msg["role"] == "user" else "Max"
        content = msg['contenu'][:120] + "..." if len(msg['contenu']) > 120 else msg['contenu']
        history_text += f"- {role}: {content}\n"

    history_text += "\n(Utilise cet historique pour personnaliser ta reponse et faire reference aux echanges precedents si pertinent)"

    logger.info(f"Historique client charge: {len(recent)} messages")
    return history_text


async def search_knowledge_base(query: str) -> str:
    """Recherche dans la knowledge base avec scoring ameliore"""
    result = await supabase_request("GET", "knowledge_base?select=contenu,categorie,titre&actif=eq.true&limit=30")

    if "error" in result or not isinstance(result, list):
        return ""

    # Mots cles importants pour le scoring
    keywords = query.lower().split()

    # Mots cles prioritaires pour le SAV
    priority_keywords = ["casse", "casser", "brise", "fissure", "assurance", "transport", "montage",
                         "rembours", "livraison", "retard", "dimension", "taille", "commande"]

    relevant = []
    for entry in result:
        content_lower = entry.get("contenu", "").lower()
        titre_lower = entry.get("titre", "").lower()
        categorie = entry.get("categorie", "").lower()

        # Score de base
        score = sum(1 for kw in keywords if kw in content_lower or kw in titre_lower)

        # Bonus pour mots prioritaires
        score += sum(2 for kw in priority_keywords if kw in query.lower() and kw in content_lower)

        # Bonus pour categorie SAV si question SAV
        if any(kw in query.lower() for kw in ["casse", "probleme", "aide", "assurance"]):
            if "sav" in categorie or "procedure" in categorie:
                score += 3

        if score > 0:
            relevant.append((score, entry))

    relevant.sort(key=lambda x: x[0], reverse=True)
    top_results = relevant[:4]

    if not top_results:
        return ""

    context = "\n\n## BASE DE CONNAISSANCES VITREFLAM:\n"
    for score, entry in top_results:
        titre = entry.get('titre', entry.get('categorie', 'Info'))
        context += f"### {titre}\n{entry.get('contenu', '')}\n\n"

    logger.info(f"KB: {len(top_results)} resultats pertinents")
    return context


async def update_client_summary(client_id: str, conversation_summary: str):
    """Met a jour le resume du client apres une conversation"""
    if not client_id:
        return

    # Recuperer les notes existantes
    result = await supabase_request("GET", f"clients?select=notes_importantes&id=eq.{client_id}&limit=1")

    current_notes = ""
    if isinstance(result, list) and len(result) > 0:
        current_notes = result[0].get("notes_importantes", "") or ""

    # Ajouter le nouveau resume (garder les 500 derniers caracteres)
    new_notes = f"{current_notes}\n[{datetime.now().strftime('%d/%m/%Y')}] {conversation_summary}"
    new_notes = new_notes[-500:]

    await supabase_request(
        "PATCH",
        f"clients?id=eq.{client_id}",
        {"notes_importantes": new_notes}
    )


def detect_intent(message: str) -> str:
    """Detecte l'intent du message avec plus de precision"""
    msg_lower = message.lower()

    # Casse
    if any(word in msg_lower for word in ["cass", "bris", "fissur", "eclat", "abim"]):
        if any(word in msg_lower for word in ["livr", "recept", "colis", "transport", "arriv"]):
            return "casse_transport"
        elif any(word in msg_lower for word in ["mont", "install", "pose", "mis"]):
            return "casse_montage"
        return "casse_general"

    # Dimensions
    elif any(word in msg_lower for word in ["dimension", "taille", "mesure", "petit", "grand", "mm", "centimetre"]):
        return "dimensions"

    # Suivi commande
    elif any(word in msg_lower for word in ["suivi", "commande", "livraison", "ou en est", "numero", "tracking"]):
        return "suivi"

    # Remboursement
    elif any(word in msg_lower for word in ["rembours", "avoir", "annul", "argent"]):
        return "remboursement"

    # Assurance
    elif any(word in msg_lower for word in ["assurance"]):
        return "assurance"

    # Retard
    elif any(word in msg_lower for word in ["retard", "attends", "toujours pas", "en retard"]):
        return "retard"

    # Question produit
    elif any(word in msg_lower for word in ["verre", "ceramique", "epaisseur", "type", "quel", "comment"]):
        return "question_produit"

    # Salutation
    elif any(word in msg_lower for word in ["bonjour", "salut", "hello", "bonsoir"]):
        return "salutation"

    return "general"


# ============================================================
# CONSTRUCTION DU CONTEXTE COMPLET
# ============================================================

async def build_full_context(client: dict, client_id: str, message: str) -> str:
    """Construit le contexte complet pour Claude"""

    context_parts = []

    # 1. Infos client de base
    client_info = f"""
## PROFIL CLIENT:
- Email: {client.get('email')}
- Segment: {client.get('segment', 'nouveau')}
- Commandes passees: {client.get('nb_commandes', 0)}
- Incidents precedents: {client.get('nb_incidents', 0)}"""

    # Notes importantes si presentes
    notes = client.get('notes_importantes')
    if notes:
        client_info += f"\n- Notes: {notes}"

    context_parts.append(client_info)

    # 2. Historique des conversations
    history = await get_client_full_history(client_id)
    if history:
        context_parts.append(history)

    # 3. Incidents passes
    incidents = await get_client_incidents(client_id)
    if incidents:
        context_parts.append(incidents)

    # 4. Knowledge base
    kb = await search_knowledge_base(message)
    if kb:
        context_parts.append(kb)

    return "\n".join(context_parts)


# ============================================================
# ANALYSE D'IMAGES
# ============================================================

def analyze_image_with_claude(image_base64: str, image_type: str, user_message: str) -> dict:
    """Analyse une image avec Claude Vision de maniere STRICTE"""

    if not claude:
        return {"error": "Claude non configure"}

    media_type = image_type if image_type else "image/jpeg"
    if "png" in media_type.lower():
        media_type = "image/png"
    elif "gif" in media_type.lower():
        media_type = "image/gif"
    elif "webp" in media_type.lower():
        media_type = "image/webp"
    else:
        media_type = "image/jpeg"

    try:
        response = claude.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1000,
            system=IMAGE_ANALYSIS_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_base64
                            }
                        },
                        {
                            "type": "text",
                            "text": f"Message du client: '{user_message}'\n\nAnalyse cette image de maniere STRICTE."
                        }
                    ]
                }
            ]
        )

        analysis_text = response.content[0].text

        verdict = "INCONNU"
        confidence = 0

        if "CASSE_CONFIRMEE" in analysis_text.upper():
            verdict = "CASSE_CONFIRMEE"
        elif "CASSE_NON_CONFIRMEE" in analysis_text.upper():
            verdict = "CASSE_NON_CONFIRMEE"
        elif "PHOTO_INSUFFISANTE" in analysis_text.upper():
            verdict = "PHOTO_INSUFFISANTE"

        confidence_match = re.search(r'(\d{1,3})\s*%', analysis_text)
        if confidence_match:
            confidence = int(confidence_match.group(1))

        return {
            "verdict": verdict,
            "confidence": confidence,
            "analysis": analysis_text,
            "is_valid_claim": verdict == "CASSE_CONFIRMEE" and confidence >= 70
        }

    except Exception as e:
        logger.error(f"Erreur analyse image: {e}")
        return {"error": str(e)}


def generate_response_with_image_context(user_message: str, image_analysis: dict, full_context: str, language: str = "fr") -> str:
    """Genere une reponse en tenant compte de l'analyse d'image"""

    verdict = image_analysis.get("verdict", "INCONNU")
    confidence = image_analysis.get("confidence", 0)
    analysis = image_analysis.get("analysis", "")
    is_valid = image_analysis.get("is_valid_claim", False)

    image_context = f"""

## ANALYSE DE LA PHOTO ENVOYEE:
- **Verdict**: {verdict}
- **Confiance**: {confidence}%
- **Details**: {analysis[:500]}

## INSTRUCTIONS:
"""

    if verdict == "CASSE_CONFIRMEE" and is_valid:
        image_context += """
- La casse est CONFIRMEE visuellement
- Procede avec la procedure de remplacement SI assurance et delais respectes
- Demande date de livraison et confirmation assurance avant de promettre un remplacement
"""
    elif verdict == "CASSE_NON_CONFIRMEE":
        image_context += """
- La photo NE MONTRE PAS de casse evidente
- Sois poli mais ferme: explique que tu ne vois pas de dommage
- Demande une nouvelle photo plus claire
- Ne propose PAS de remplacement
"""
    elif verdict == "PHOTO_INSUFFISANTE":
        image_context += """
- La photo n'est pas suffisante
- Demande une nouvelle photo: bien eclairee, nette, montrant le verre et les dommages
"""
    else:
        image_context += """
- Probleme avec l'analyse
- Demande au client de renvoyer une photo claire
"""

    lang_instruction = LANGUAGE_INSTRUCTIONS.get(language, LANGUAGE_INSTRUCTIONS["fr"])
    full_system = f"{lang_instruction}\n\n{SYSTEM_PROMPT}{full_context}{image_context}"

    try:
        response = claude.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=500,
            system=full_system,
            messages=[
                {"role": "user", "content": user_message}
            ]
        )
        return response.content[0].text
    except Exception as e:
        logger.error(f"Erreur generation reponse: {e}")
        return "Une erreur s'est produite. Veuillez reessayer."


# ============================================================
# APP FASTAPI
# ============================================================

import asyncio

async def periodic_cleanup():
    """Tache de fond pour fermer les conversations inactives"""
    while True:
        await asyncio.sleep(300)  # Toutes les 5 minutes
        try:
            closed = await close_inactive_conversations(30)
            if closed > 0:
                logger.info(f"Nettoyage periodique: {closed} conversation(s) fermee(s)")
        except Exception as e:
            logger.error(f"Erreur nettoyage periodique: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialisation au demarrage"""
    global claude

    logger.info("="*60)
    logger.info("VITREFLAM - Chatbot Max v2.0")
    logger.info("="*60)

    if ANTHROPIC_API_KEY:
        try:
            claude = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
            logger.info("Connexion Anthropic OK")
        except Exception as e:
            logger.error(f"Erreur Anthropic: {e}")
    else:
        logger.error("ANTHROPIC_API_KEY manquante")

    await test_supabase()

    # Nettoyage initial des conversations inactives
    closed = await close_inactive_conversations(30)
    logger.info(f"Nettoyage initial: {closed} conversation(s) fermee(s)")

    # Lancer la tache de nettoyage periodique
    cleanup_task = asyncio.create_task(periodic_cleanup())

    logger.info("="*60)
    logger.info("Serveur pret - Memoire complete + Nettoyage auto actif")
    logger.info("="*60)

    yield

    # Arreter la tache de nettoyage
    cleanup_task.cancel()
    logger.info("Arret du serveur")


app = FastAPI(title="Vitreflam - Max v2.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def serve_frontend():
    """Sert le frontend HTML"""
    return FileResponse("static/index.html")


@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Endpoint principal du chatbot avec memoire complete"""

    logger.info(f"Message de {request.email}: {request.message[:50]}...")

    has_image = request.image_base64 is not None
    if has_image:
        logger.info(f"Image jointe detectee")

    if not claude:
        raise HTTPException(status_code=500, detail="Claude non configure")

    # 1. Recuperer ou creer le client
    client = await get_or_create_client(request.email)
    client_id = client.get("id")

    # 2. Recuperer ou creer la conversation
    session_id = request.session_id or request.email
    conversation_id = None
    if client_id:
        conversation_id = await get_or_create_conversation(client_id, session_id)

    # 3. Detecter l'intent
    intent = detect_intent(request.message)
    logger.info(f"Intent: {intent}")

    # 3b. Detecter la frustration du client
    frustration = detect_frustration(request.message)
    needs_escalation = False
    if frustration["level"] != "low":
        logger.info(f"Frustration detectee: {frustration['level']} (score: {frustration['score']})")
        if frustration["needs_escalation"] and conversation_id:
            needs_escalation = await check_and_escalate(conversation_id, client_id, frustration)

    # 3c. Mettre a jour le contexte de la conversation (intent, sujet, commande)
    if conversation_id:
        await update_conversation_context(conversation_id, intent, request.message)

    # 3d. Creer automatiquement un incident si probleme detecte
    if client_id and conversation_id:
        await auto_create_incident_if_needed(client_id, conversation_id, intent, request.message)

    # 4. Construire le contexte complet (client + historique + incidents + KB)
    full_context = await build_full_context(client, client_id, request.message)

    # 4b. Ajouter contexte frustration si necessaire
    if frustration["level"] != "low":
        full_context += f"\n\n## ATTENTION - CLIENT FRUSTRE:\n- Niveau: {frustration['level']}\n- Score: {frustration['score']}/100\n- Declencheurs: {', '.join(frustration['triggers'])}\n- Sois particulierement empathique et propose des solutions concretes"

    if needs_escalation:
        full_context += "\n- ESCALADE NECESSAIRE: Propose au client de le mettre en contact avec un responsable par email a contactglassgroup@gmail.com"

    # 5. Traiter selon presence d'image ou non
    image_analysis = None
    if has_image:
        logger.info("Analyse de l'image...")
        image_analysis = analyze_image_with_claude(
            request.image_base64,
            request.image_type,
            request.message
        )

        if "error" not in image_analysis:
            logger.info(f"Analyse: {image_analysis['verdict']} ({image_analysis['confidence']}%)")

            # Creer incident si casse detectee
            if image_analysis.get("is_valid_claim") and client_id:
                await create_incident(
                    client_id,
                    conversation_id,
                    intent if "casse" in intent else "casse_general",
                    request.message,
                    image_analysis
                )

        assistant_response = generate_response_with_image_context(
            request.message,
            image_analysis,
            full_context,
            request.language
        )
    else:
        # Reponse normale sans image
        lang_instruction = LANGUAGE_INSTRUCTIONS.get(request.language, LANGUAGE_INSTRUCTIONS["fr"])
        full_system = f"{lang_instruction}\n\n{SYSTEM_PROMPT}{full_context}"

        # Charger l'historique de la conversation en cours
        history = await get_conversation_history(conversation_id)
        history.append({"role": "user", "content": request.message})

        try:
            response = claude.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=500,
                system=full_system,
                messages=history
            )
            assistant_response = response.content[0].text
        except Exception as e:
            logger.error(f"Erreur Claude: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    # 6. Sauvegarder les messages
    if conversation_id:
        await save_message(conversation_id, "user", request.message, intent)
        await save_message(conversation_id, "assistant", assistant_response)

    logger.info(f"Reponse: {assistant_response[:80]}...")

    return ChatResponse(
        response=assistant_response,
        session_id=session_id,
        status="success",
        image_analysis=image_analysis
    )


@app.get("/api/health")
async def health():
    """Verification de sante"""
    return {
        "status": "ok",
        "version": "2.0",
        "anthropic": claude is not None,
        "supabase_url": SUPABASE_URL is not None,
        "timestamp": datetime.now().isoformat()
    }


@app.get("/api/stats")
async def stats():
    """Statistiques de la base"""
    clients = await supabase_request("GET", "clients?select=id")
    conversations = await supabase_request("GET", "conversations?select=id")
    messages = await supabase_request("GET", "messages?select=id")
    incidents = await supabase_request("GET", "incidents?select=id")

    return {
        "clients": len(clients) if isinstance(clients, list) else 0,
        "conversations": len(conversations) if isinstance(conversations, list) else 0,
        "messages": len(messages) if isinstance(messages, list) else 0,
        "incidents": len(incidents) if isinstance(incidents, list) else 0
    }


@app.get("/api/client/{email}")
async def get_client_info(email: str):
    """Recupere les infos d'un client"""
    client = await get_or_create_client(email)
    client_id = client.get("id")

    incidents = await supabase_request(
        "GET",
        f"incidents?select=*&client_id=eq.{client_id}&order=created_at.desc&limit=10"
    )

    return {
        "client": client,
        "incidents": incidents if isinstance(incidents, list) else []
    }


@app.post("/api/conversation/{conversation_id}/close")
async def close_conversation_endpoint(conversation_id: str):
    """Ferme manuellement une conversation et genere un resume"""
    resume = await close_conversation(conversation_id)
    return {
        "status": "closed",
        "conversation_id": conversation_id,
        "resume": resume
    }


@app.post("/api/conversations/cleanup")
async def cleanup_conversations(inactivity_minutes: int = 30):
    """Ferme toutes les conversations inactives"""
    closed_count = await close_inactive_conversations(inactivity_minutes)
    return {
        "status": "ok",
        "closed_count": closed_count,
        "inactivity_threshold_minutes": inactivity_minutes
    }


@app.get("/api/conversations/active")
async def get_active_conversations():
    """Liste les conversations actives"""
    result = await supabase_request(
        "GET",
        "conversations?select=id,client_id,intent_principal,sujet,commande_concernee,statut,nb_messages,started_at&statut=in.(en_cours,escalade)&order=started_at.desc&limit=50"
    )

    # Enrichir avec email client
    conversations = []
    if isinstance(result, list):
        for conv in result:
            client = await supabase_request(
                "GET",
                f"clients?select=email&id=eq.{conv['client_id']}&limit=1"
            )
            conv["client_email"] = client[0]["email"] if isinstance(client, list) and client else "inconnu"
            conversations.append(conv)

    return {
        "count": len(conversations),
        "conversations": conversations
    }


@app.get("/api/incidents/open")
async def get_open_incidents():
    """Liste les incidents ouverts"""
    result = await supabase_request(
        "GET",
        "incidents?select=id,client_id,type_incident,description,statut,photos_recues,created_at&statut=in.(ouvert,en_cours,en_attente_photos)&order=created_at.desc&limit=50"
    )

    # Enrichir avec email client
    incidents = []
    if isinstance(result, list):
        for inc in result:
            client = await supabase_request(
                "GET",
                f"clients?select=email&id=eq.{inc['client_id']}&limit=1"
            )
            inc["client_email"] = client[0]["email"] if isinstance(client, list) and client else "inconnu"
            incidents.append(inc)

    return {
        "count": len(incidents),
        "incidents": incidents
    }


# Servir les fichiers statiques
app.mount("/static", StaticFiles(directory="static"), name="static")
