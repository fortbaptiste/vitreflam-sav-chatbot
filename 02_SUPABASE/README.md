# Supabase - Base de Donnees Vitreflam

## Structure

```
02_SUPABASE/
├── README.md                          # Ce fichier
├── schema/
│   ├── SUPABASE_SETUP_V1.sql          # Schema initial (archive)
│   └── SUPABASE_SETUP_V3.sql          # Schema actuel (a utiliser)
├── data/
│   ├── KNOWLEDGE_BASE_V1.sql          # KB initiale (archive)
│   └── KNOWLEDGE_BASE_V2.sql          # KB actuelle (a utiliser)
└── scripts/
    ├── populate_embeddings.py         # Generer les embeddings
    └── requirements.txt               # Dependances Python
```

## Installation

### 1. Creer le projet Supabase
1. Aller sur https://supabase.com
2. Creer un nouveau projet
3. Noter l'URL et les cles API

### 2. Activer pgvector
```sql
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;
```

### 3. Executer le schema
Dans SQL Editor, executer `schema/SUPABASE_SETUP_V3.sql`

### 4. Peupler la knowledge base
Executer `data/KNOWLEDGE_BASE_V2.sql`

### 5. Generer les embeddings
```bash
cd scripts
pip install -r requirements.txt
python populate_embeddings.py
```

## Schema V3 - Tables

### Tables Client
| Table | Description |
|-------|-------------|
| `clients` | Profils clients avec segment et risk_score |
| `client_assurances` | Assurances souscrites par commande |
| `client_preferences` | Preferences persistantes |
| `client_memory` | Memoire hierarchique (short/medium/long) |

### Tables Conversation
| Table | Description |
|-------|-------------|
| `conversations` | Sessions de chat avec resume |
| `messages` | Messages avec embeddings |

### Tables SAV
| Table | Description |
|-------|-------------|
| `incidents` | Tickets SAV avec lien assurance |
| `produits_client` | Commandes avec assurances |

### Tables RAG
| Table | Description |
|-------|-------------|
| `knowledge_base` | Base connaissances avec hybrid search |

## Fonctions RPC

### Client
- `upsert_client(p_email)` - Creer/maj client
- `get_client_context_v3(p_email)` - Contexte complet

### Recherche
- `hybrid_search_knowledge(query_text, query_embedding, ...)` - Recherche hybride
- `search_client_memory(p_client_id, p_query_embedding, ...)` - Recherche memoire

### Assurance
- `check_client_assurance(p_client_email, p_commande_id, p_type)` - Verification

### Memoire
- `add_client_memory(...)` - Ajouter memoire
- `cleanup_expired_memory()` - Nettoyage auto

## Variables d'Environnement

```bash
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJhbG...
SUPABASE_SERVICE_KEY=eyJhbG...
```

## Hybrid Search

Le schema V3 combine:
- **Recherche semantique** (pgvector) - 70%
- **Recherche keyword** (tsvector) - 30%
- **Fusion RRF** (Reciprocal Rank Fusion)

```sql
-- Exemple d'utilisation
SELECT * FROM hybrid_search_knowledge(
    'vitre cassee transport',           -- query_text
    '[0.1, 0.2, ...]'::vector(1536),   -- query_embedding
    5,                                  -- match_count
    0.7,                                -- semantic_weight
    0.3                                 -- keyword_weight
);
```

## Memoire Hierarchique

```
SHORT (1 jour)   → Contexte conversation
MEDIUM (30 jours) → Resume sessions recentes
LONG (permanent)  → Preferences, historique incidents
```
