# n8n - Workflows Vitreflam

## Structure

```
03_N8N/
├── README.md                          # Ce fichier
├── workflows/
│   ├── archive/
│   │   ├── WORKFLOW_V1.json           # Version initiale (archive)
│   │   └── WORKFLOW_V2.json           # Version 2 (archive)
│   └── WORKFLOW_V3.json               # Version actuelle (a utiliser)
└── docs/
    └── ARCHITECTURE_WORKFLOW.md       # Documentation technique
```

## Workflow V3 - Oliver SAV

### Caracteristiques
- Detection d'intent automatique
- Hybrid Search (semantic + keyword)
- Verification assurance automatique
- Contexte client enrichi
- Optimisation tokens (max 6 messages)
- Sauvegarde asynchrone

### Architecture

```
[Webhook] → [Validate] → [Upsert Client]
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
            [Get Context V3]    [Generate Embedding]
                    │                   │
                    ▼                   ▼
            [Need Assurance?]   [Hybrid Search KB]
                    │                   │
         ┌──────────┴──────────┐        │
         ▼                     ▼        │
  [Check Assurance]      [Skip]         │
         │                     │        │
         └──────────┬──────────┘        │
                    ▼                   │
            [Build Context & Prompt] ◄──┘
                    │
                    ▼
            [Call Claude API]
                    │
                    ▼
            [Process Response]
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
  [Respond Success]    [Save Messages]
```

## Installation

### 1. Importer le workflow
1. Ouvrir n8n
2. Aller dans Workflows > Import
3. Selectionner `workflows/WORKFLOW_V3.json`

### 2. Configurer les credentials
Dans n8n > Settings > Environment Variables:

```bash
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbG...
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-api03-...
```

### 3. Activer le workflow
- Cliquer sur "Active" en haut a droite
- Noter l'URL du webhook

### 4. Mettre a jour le frontend
Modifier l'URL du webhook dans `04_FRONTEND/index.html`

## Endpoints

### POST /webhook/vitreflam-sav-v3

**Request:**
```json
{
  "email": "client@example.com",
  "message": "Ma vitre est cassee",
  "session_id": "uuid-optional",
  "conversation_history": []
}
```

**Response:**
```json
{
  "response": "Je comprends...",
  "session_id": "uuid",
  "status": "success",
  "metadata": {
    "intent": "casse_transport",
    "hasAssurance": true,
    "tokensUsed": 450
  }
}
```

## Intents Detectes

| Intent | Declencheur |
|--------|-------------|
| `casse_transport` | "cassee" + "livraison" |
| `casse_montage` | "cassee" + "montage" |
| `casse_general` | "cassee" seul |
| `dimensions` | "dimension", "taille", "mesure" |
| `suivi` | "suivi", "commande", "livraison" |
| `remboursement` | "rembours", "avoir" |
| `assurance` | "assurance" |

## Performance

- Latence: 2-4 secondes
- Tokens: 400-600 par requete
- Cout: ~$0.003 par conversation (10 messages)

## Troubleshooting

### Erreur 401 Supabase
- Verifier `SUPABASE_SERVICE_KEY`
- Verifier que RLS est configure

### Erreur Claude timeout
- Augmenter timeout (defaut 30s)
- Reduire max_tokens

### Hybrid search 0 resultats
- Verifier embeddings dans knowledge_base
- Verifier fts_vector populee
- Verifier actif = true
