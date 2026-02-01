# Vitreflam - Chatbot SAV Oliver

Chatbot IA pour le Service Apres-Vente Vitreflam (verre ceramique sur-mesure depuis 1985).

## Structure du Projet

```
VITREFLAM/
│
├── README.md                    # Ce fichier
├── .env.example                 # Template variables d'environnement
│
├── 01_DOCUMENTATION_SAV/        # Documentation metier
│   ├── README.md
│   ├── procedures/
│   │   ├── PROCEDURES_SAV_COMPLETE.md
│   │   └── REGLES_ASSURANCES.md
│   ├── sources/                 # Documents originaux Vitreflam
│   └── guides/                  # Guides et analyses
│
├── 02_SUPABASE/                 # Base de donnees
│   ├── README.md
│   ├── schema/
│   │   ├── SUPABASE_SETUP_V1.sql    # Archive
│   │   └── SUPABASE_SETUP_V3.sql    # A utiliser
│   ├── data/
│   │   ├── KNOWLEDGE_BASE_V1.sql    # Archive
│   │   └── KNOWLEDGE_BASE_V2.sql    # A utiliser
│   └── scripts/
│       ├── populate_embeddings.py
│       └── requirements.txt
│
├── 03_N8N/                      # Workflows
│   ├── README.md
│   ├── workflows/
│   │   ├── WORKFLOW_V3.json         # A utiliser
│   │   └── archive/                 # Anciennes versions
│   └── docs/
│       └── ARCHITECTURE_WORKFLOW.md
│
├── 04_FRONTEND/                 # Interface chat
│   ├── README.md
│   └── index.html
│
└── 05_SCRIPTS/                  # Utilitaires
    ├── README.md
    └── extraction/              # Scripts PowerShell
```

---

## Quick Start

### 1. Configuration

```bash
cp .env.example .env
# Editer .env avec vos credentials
```

### 2. Supabase

```bash
# Dans Supabase SQL Editor:
# 1. Executer 02_SUPABASE/schema/SUPABASE_SETUP_V3.sql
# 2. Executer 02_SUPABASE/data/KNOWLEDGE_BASE_V2.sql

# Generer les embeddings:
cd 02_SUPABASE/scripts
pip install -r requirements.txt
python populate_embeddings.py
```

### 3. n8n

1. Importer `03_N8N/workflows/WORKFLOW_V3.json`
2. Configurer les variables d'environnement
3. Activer le workflow
4. Noter l'URL du webhook

### 4. Frontend

1. Modifier l'URL webhook dans `04_FRONTEND/index.html`
2. Deployer sur votre serveur

---

## Fonctionnalites

### Chatbot Oliver

- **Detection d'intent** automatique (casse, suivi, dimensions...)
- **Verification assurance** automatique avec delais
- **Hybrid Search** (semantic + keyword)
- **Memoire client** hierarchique (court/moyen/long terme)
- **Strategie defensive** (regles CGV strictes)

### Regles Assurances

| Type | Delai | Action |
|------|-------|--------|
| Transport | 2 jours | Photos → Remplacement (1x) |
| Montage | 8 jours | Photos → Remplacement (1x) |
| Sans assurance | - | Remise 30% max |

### Gestes Commerciaux

| Situation | Remise Max |
|-----------|------------|
| Incident non couvert | 30% nouvelle commande |
| Retard 3-5j | 5% |
| Retard >5j | 10% |
| Max sans escalade | 15% |

---

## Stack Technique

| Composant | Technologie |
|-----------|-------------|
| Frontend | HTML/CSS/JS |
| Backend | n8n |
| Database | Supabase (PostgreSQL + pgvector) |
| AI | Claude API (Anthropic) |
| Embeddings | OpenAI text-embedding-3-small |

---

## Variables d'Environnement

```bash
# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbG...

# OpenAI (embeddings)
OPENAI_API_KEY=sk-...

# Anthropic (Claude)
ANTHROPIC_API_KEY=sk-ant-api03-...
```

---

## Contact

- **Email SAV:** contactglassgroup@gmail.com
- **Site:** https://www.vitreflam.com

---

## Versions

| Version | Date | Description |
|---------|------|-------------|
| V1 | - | Version initiale (Louis) |
| V2 | - | Renommage Oliver, regles assurance |
| V3 | - | Hybrid search, memoire hierarchique |
