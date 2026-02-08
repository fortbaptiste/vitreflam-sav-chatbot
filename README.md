# Vitreflam - Chatbot SAV Oliver v3.0

Chatbot IA pour le Service Apres-Vente Vitreflam (verre ceramique sur-mesure depuis 1985).

Backend Python natif (FastAPI + Claude API) deploye sur Render.

---

## Structure du Projet

```
VITREFLAM/
├── README.md                 # Ce fichier
├── .env.example              # Template variables d'environnement
├── .gitignore
├── render.yaml               # Configuration deploiement Render
│
├── BACKEND/                  # Application principale
│   ├── .env                  # Variables d'environnement (non commite)
│   ├── requirements.txt      # Dependances Python
│   ├── app/
│   │   └── main.py           # Coeur de l'application (FastAPI + Claude)
│   └── static/
│       └── index.html        # Interface chat frontend
│
├── database/                 # Base de donnees Supabase
│   ├── schema/
│   │   └── SUPABASE_SETUP_V3.sql    # Schema complet (tables + fonctions)
│   ├── data/
│   │   └── KNOWLEDGE_BASE_V2.sql    # Base de connaissances SAV
│   └── scripts/
│       ├── populate_embeddings.py    # Generation des embeddings
│       └── requirements.txt
│
└── docs/                     # Documentation
    ├── procedures/
    │   ├── PROCEDURES_SAV_COMPLETE.md
    │   └── REGLES_ASSURANCES.md
    ├── guides/
    │   ├── ANALYSE_COMPLETE_VITREFLAM.md
    │   └── informationvitreflam.txt
    └── RAPPORT_TEST_OLIVER_V3.md    # Rapport de test (270 echanges, 100%)
```

---

## Stack Technique

| Composant | Technologie |
|-----------|-------------|
| Backend | Python / FastAPI |
| Frontend | HTML / CSS / JS (servi par FastAPI) |
| IA | Claude API (Anthropic) - claude-sonnet |
| Database | Supabase (PostgreSQL + pgvector) |
| Deploiement | Render (Frankfurt, free tier) |

---

## Fonctionnalites Oliver v3.0

- **Detection d'intent** automatique (casse transport/montage, suivi, dimensions)
- **Strategie defensive** : suspecte d'abord, rassure ensuite
- **Verification assurance** avec regles strictes (transport/montage/sans)
- **Memoire client** persistante (court/moyen/long terme)
- **Analyse d'images** via Claude Vision (photos de casse)
- **Escalade automatique** vers email quand necessaire
- **Multilingue** : FR, EN, IT, ES, DE, ZH
- **Reponses concises** : 1-2 phrases maximum

### Regles Assurances

| Type | Delai | Action |
|------|-------|--------|
| Transport (avec assurance) | 48h apres reception | Remplacement gratuit (1 seule fois) |
| Montage (avec assurance) | 8 jours | Remplacement gratuit (1 seule fois) |
| Sans assurance | - | Colissimo + remise 30% max |

---

## Quick Start

### 1. Configuration

```bash
cp .env.example BACKEND/.env
# Editer BACKEND/.env avec vos credentials
```

### 2. Supabase

```sql
-- Dans Supabase SQL Editor:
-- 1. Executer database/schema/SUPABASE_SETUP_V3.sql
-- 2. Executer database/data/KNOWLEDGE_BASE_V2.sql
```

### 3. Lancer le serveur

```bash
cd BACKEND
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Ouvrir http://localhost:8000 pour acceder au chat.

---

## Deploiement Render

Le fichier `render.yaml` configure le deploiement automatique sur Render (region Frankfurt).

---

## Contact

- **Email SAV:** contactglassgroup@gmail.com
- **Site:** https://www.vitreflam.com
