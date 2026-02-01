# Workflow V3 - Oliver SAV Chatbot

## Architecture du Workflow

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    WORKFLOW V3                                           │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                    ┌──────────────────┐
                    │  1. Webhook SAV  │
                    │  POST /vitreflam │
                    │     -sav-v3      │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ 2. Validate &    │
                    │    Extract       │
                    │ - Email check    │
                    │ - Intent detect  │
                    │ - Commande ID    │
                    └────────┬─────────┘
                             │
                    ┌────────┴────────┐
                    │  3. Check Error │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
         [ERROR]                       [SUCCESS]
              │                             │
              ▼                             ▼
    ┌─────────────────┐           ┌─────────────────┐
    │ 15. Respond     │           │ 4. Upsert       │
    │     Error       │           │    Client       │
    └─────────────────┘           └────────┬────────┘
                                           │
                          ┌────────────────┼────────────────┐
                          │                │                │
                          ▼                ▼                │
              ┌─────────────────┐  ┌─────────────────┐      │
              │ 5. Get Client   │  │ 6. Generate     │      │
              │    Context V3   │  │    Embedding    │      │
              │ (Supabase RPC)  │  │ (OpenAI)        │      │
              └────────┬────────┘  └────────┬────────┘      │
                       │                    │               │
                       ▼                    ▼               │
              ┌─────────────────┐  ┌─────────────────┐      │
              │ 8. Need         │  │ 7. Hybrid       │      │
              │ Assurance       │  │    Search KB    │      │
              │ Check?          │  │ (Semantic+KW)   │      │
              └────────┬────────┘  └────────┬────────┘      │
                       │                    │               │
          ┌────────────┴────────────┐       │               │
          │                         │       │               │
     [CASSE]                   [OTHER]      │               │
          │                         │       │               │
          ▼                         ▼       │               │
┌─────────────────┐      ┌─────────────────┐│               │
│ 9. Check        │      │ 16. Skip        ││               │
│    Assurance    │      │     Assurance   ││               │
│ (Supabase RPC)  │      │                 ││               │
└────────┬────────┘      └────────┬────────┘│               │
         │                        │         │               │
         └────────────┬───────────┘         │               │
                      │                     │               │
                      ▼                     │               │
              ┌─────────────────────────────┴───────────────┐
              │           10. Build Context & Prompt        │
              │  - Client info + assurances + KB results    │
              │  - Optimized system prompt                  │
              │  - Conversation history (max 6 messages)    │
              └─────────────────────┬───────────────────────┘
                                    │
                                    ▼
                          ┌─────────────────┐
                          │ 11. Call Claude │
                          │     API         │
                          │ (Sonnet 4)      │
                          └────────┬────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │ 12. Process     │
                          │     Response    │
                          │ - Extract text  │
                          │ - Count tokens  │
                          └────────┬────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
          ┌─────────────────┐           ┌─────────────────┐
          │ 14. Respond     │           │ 13. Save        │
          │     Success     │           │     Messages    │
          │ (JSON response) │           │ (Async to DB)   │
          └─────────────────┘           └─────────────────┘
```

## Fonctionnalites V3

### 1. Validation Intelligente
- Validation email avec regex
- Detection d'intent automatique:
  - `casse_transport` - Vitre cassee a la livraison
  - `casse_montage` - Vitre cassee au montage
  - `dimensions` - Probleme de dimensions
  - `suivi` - Suivi de commande
  - `remboursement` - Demande de remboursement
  - `assurance` - Question sur assurance
- Extraction automatique du numero de commande

### 2. Hybrid Search (Semantic + Keyword)
- Recherche semantique via embeddings (70%)
- Recherche par mots-cles via tsvector (30%)
- Fusion RRF (Reciprocal Rank Fusion)
- Meilleure pertinence des resultats

### 3. Verification Assurance Automatique
- Check automatique si intent = casse
- Verifie si assurance souscrite
- Verifie si dans les delais (2j transport, 8j montage)
- Verifie si deja utilisee
- Injecte l'info dans le contexte Claude

### 4. Contexte Client Enrichi
- Informations client (segment, risk_score)
- Assurances actives avec dates
- Incidents en cours
- Commandes recentes avec statut assurance
- Preferences client
- Memoire long terme

### 5. Optimisation Tokens
- Max 6 messages dans l'historique
- System prompt optimise (~800 tokens)
- Max 500 tokens pour la reponse
- Tracking des tokens utilises

## Variables d'Environnement Requises

```bash
# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbG...

# OpenAI (embeddings)
OPENAI_API_KEY=sk-...

# Anthropic (Claude)
ANTHROPIC_API_KEY=sk-ant-api03-...
```

## Fonctions Supabase Requises

Le workflow V3 necessite ces fonctions RPC:

1. `upsert_client(p_email)` - Creer/maj client
2. `get_client_context_v3(p_email)` - Contexte complet
3. `hybrid_search_knowledge(query_text, query_embedding, ...)` - Recherche hybride
4. `check_client_assurance(p_client_email, p_commande_id, p_type)` - Verif assurance

## Comparaison V2 vs V3

| Aspect | V2 | V3 |
|--------|----|----|
| Recherche KB | Semantic only | **Hybrid (semantic + keyword)** |
| Check assurance | Manuel | **Automatique** |
| Intent detection | Non | **Oui** |
| Context window | Tout l'historique | **Max 6 messages** |
| Token tracking | Non | **Oui** |
| Routage intelligent | Non | **Oui (IF nodes)** |
| Sauvegarde messages | Sync | **Async** |

## Endpoints

### POST /webhook/vitreflam-sav-v3

**Request:**
```json
{
  "email": "client@example.com",
  "message": "Ma vitre est arrivee cassee",
  "session_id": "uuid-optional",
  "conversation_history": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

**Response:**
```json
{
  "response": "Je comprends votre situation...",
  "session_id": "uuid",
  "status": "success",
  "metadata": {
    "intent": "casse_transport",
    "hasAssurance": true,
    "isWithinDeadline": true,
    "clientSegment": "regulier",
    "tokensUsed": 450,
    "messageCount": 3
  }
}
```

## Performance

- Latence moyenne: 2-4 secondes
- Tokens moyens: 400-600 par requete
- Cout estime: ~$0.003 par conversation (10 messages)

## Troubleshooting

### Erreur "Assurance not found"
- Verifier que la table `client_assurances` est populee
- Verifier le format du `commande_id`

### Hybrid search retourne 0 resultats
- Verifier que les embeddings sont generes dans `knowledge_base`
- Verifier que `fts_vector` est populee
- Verifier que `actif = true`

### Claude timeout
- Augmenter le timeout (defaut: 30s)
- Reduire `max_tokens` si necessaire
