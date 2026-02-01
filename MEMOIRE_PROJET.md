# VITREFLAM - Chatbot SAV Max v2.0

## Apercu du Projet

Chatbot SAV intelligent pour Vitreflam (verre ceramique sur-mesure pour cheminees/poeles).
- **Backend**: FastAPI + Claude API (Anthropic)
- **Base de donnees**: Supabase (PostgreSQL)
- **Frontend**: HTML/Tailwind CSS (design neobrutalist)

---

## Structure des Fichiers

```
VITREFLAM/
├── BACKEND/
│   ├── app/
│   │   └── main.py          # Backend principal (FastAPI)
│   ├── static/
│   │   └── index.html       # Frontend chatbot
│   ├── .env                  # Variables d'environnement
│   └── requirements.txt
├── 02_SUPABASE/
│   ├── schema/
│   │   └── SUPABASE_SETUP_V3.sql   # Schema complet
│   └── data/
│       └── KNOWLEDGE_BASE_V2.sql   # Base de connaissances
├── 04_FRONTEND/
│   └── index.html           # Frontend alternatif
└── MEMOIRE_PROJET.md        # Ce fichier
```

---

## Lancer le Serveur

```bash
cd BACKEND
python -B -m uvicorn app.main:app --host 0.0.0.0 --port 8002
```

Acceder au chatbot: `http://localhost:8002`

---

## Variables d'Environnement (.env)

```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJxxx...
ANTHROPIC_API_KEY=sk-ant-xxx...
```

---

## Fonctionnalites Implementees

### 1. Memoire par Email
- Quand un client donne son email, Max charge **tout l'historique** de ses conversations passees
- Fonctionne meme si le client revient 1 mois plus tard
- Stocke dans Supabase: `clients`, `conversations`, `messages`

### 2. Creation Automatique d'Incidents
- Quand un client signale un probleme (casse, retard, dimensions...), un incident est cree automatiquement
- Statut initial: `en_attente_photos`
- Table: `incidents`

### 3. Contexte de Conversation Enrichi
- `intent_principal`: Type de demande detecte (casse_transport, retard, etc.)
- `sujet`: Sujet de la conversation (Verre casse, Probleme livraison, etc.)
- `commande_concernee`: Numero de commande extrait du message

### 4. Detection de Frustration & Escalade
- Analyse les messages pour detecter la frustration (mots-cles, MAJUSCULES, !!!)
- Score de 0 a 100
- Si score >= 50: conversation passee en `escalade`
- Max propose de contacter un responsable

### 5. Cloture Automatique des Conversations
- Conversations inactives > 30 minutes sont fermees automatiquement
- Nettoyage periodique toutes les 5 minutes
- Generation d'un resume automatique avec Claude

### 6. Resume Automatique
- A la fermeture d'une conversation, Claude genere un resume de 2-3 phrases
- Stocke dans le champ `resume` de la table `conversations`

### 7. Analyse d'Images
- Les clients peuvent envoyer des photos de verre casse
- Claude Vision analyse l'image et donne un verdict:
  - `CASSE_CONFIRMEE`: Casse visible, confiance >= 70%
  - `CASSE_NON_CONFIRMEE`: Pas de casse visible
  - `PHOTO_INSUFFISANTE`: Photo floue ou mal cadree

### 8. Knowledge Base
- Recherche dans la base de connaissances Vitreflam
- Procedures SAV, FAQ, infos produits
- Table: `knowledge_base`

---

## Tables Supabase Utilisees

| Table | Description | Remplie |
|-------|-------------|---------|
| `clients` | Infos client (email, segment, nb_commandes) | Oui |
| `conversations` | Conversations avec contexte (intent, sujet, resume) | Oui |
| `messages` | Tous les messages echanges | Oui |
| `incidents` | Problemes signales par les clients | Oui |
| `knowledge_base` | Base de connaissances (procedures, FAQ) | Pre-remplie |

### Tables Non Utilisees (Schema V3 avance)
- `client_assurances`: Utile si integration PrestaShop
- `client_preferences`: Pas necessaire pour le SAV
- `client_memory`: Les messages suffisent
- `produits_client`: Utile si integration e-commerce

---

## Endpoints API

### Chat Principal
```
POST /api/chat
Body: {"email": "client@test.fr", "message": "Mon verre est casse"}
```

### Sante & Stats
```
GET /api/health          # Verification serveur
GET /api/stats           # Stats de la base
```

### Conversations
```
GET /api/conversations/active              # Liste conversations actives
POST /api/conversation/{id}/close          # Fermer manuellement
POST /api/conversations/cleanup?inactivity_minutes=30  # Nettoyage manuel
```

### Incidents
```
GET /api/incidents/open   # Liste incidents ouverts
```

### Client
```
GET /api/client/{email}   # Infos d'un client + incidents
```

---

## System Prompt (Max)

```
Tu es Max, conseiller SAV expert chez Vitreflam, specialiste du verre ceramique
sur-mesure pour cheminees et poeles depuis 1985.

MISSIONS:
1. SAV (priorite): Gerer casse, retard, dimensions, remboursement
2. Conseil: Aider sur les produits, dimensions, types de verre
3. Accompagnement: Guider pour commander sur www.vitreflam.com

ASSURANCES:
- Transport: Couvre casse livraison, delai 48h
- Montage: Couvre casse installation, delai 8 jours

REGLES:
- 2-3 phrases max, vouvoiement, pas d'emojis
- **Gras** pour les infos importantes
- Le client peut envoyer des photos directement dans le chat
- Contact: contactglassgroup@gmail.com
```

---

## Detection d'Intent

| Intent | Declencheurs |
|--------|--------------|
| `casse_transport` | casse + livraison/reception/colis |
| `casse_montage` | casse + montage/installation/pose |
| `casse_general` | casse seul |
| `dimensions` | dimension/taille/mesure/petit/grand |
| `suivi` | suivi/commande/livraison/tracking |
| `remboursement` | rembours/avoir/annul |
| `retard` | retard/attends/toujours pas |
| `assurance` | assurance |
| `question_produit` | verre/ceramique/epaisseur |
| `salutation` | bonjour/salut/hello |

---

## Detection de Frustration

### Mots Declencheurs Forts (+30 points)
scandale, honte, inadmissible, avocat, arnaque, plainte, proces

### Mots Declencheurs Moyens (+15 points)
mecontent, decu, attends depuis, toujours rien, responsable, chef

### Indicateurs Typographiques
- MAJUSCULES (>50% du message): +20 points
- !!! (>= 2): +10 points
- ??? (>= 3): +5 points

### Niveaux
- Low: < 25 points
- Medium: 25-49 points
- High: >= 50 points (declanche escalade)

---

## Ameliorations Futures Possibles

### Priorite Haute
- [ ] Mettre a jour le frontend pour le bon port (8002)
- [ ] Score de satisfaction client (feedback)
- [ ] Dashboard admin (stats, incidents, escalades)

### Priorite Moyenne
- [ ] Notifications email quand incident cree
- [ ] Integration PrestaShop (vraies commandes)
- [ ] Multi-langue (anglais, espagnol)

### Priorite Basse
- [ ] Rate limiting (anti-abus)
- [ ] Embeddings vectoriels (recherche semantique)
- [ ] Tests automatises

---

## Commandes Utiles

### Tuer le serveur sur un port
```bash
netstat -ano | findstr :8002
taskkill /F /PID <PID>
```

### Verifier les conversations dans Supabase
```bash
curl -s "https://xxx.supabase.co/rest/v1/conversations?select=*&limit=5" \
  -H "apikey: YOUR_KEY" \
  -H "Authorization: Bearer YOUR_KEY"
```

### Tester le chatbot
```bash
curl -X POST http://localhost:8002/api/chat \
  -H "Content-Type: application/json" \
  -d '{"email": "test@test.fr", "message": "Bonjour"}'
```

---

## Notes Importantes

1. **Port**: Le serveur tourne sur le port **8002** (8000 et 8001 parfois bloques sur Windows)

2. **Nettoyage au demarrage**: Au lancement, le serveur ferme automatiquement toutes les conversations inactives et genere des resumes

3. **Cout API**: Chaque resume utilise Claude (~200 tokens). Attention si beaucoup de conversations.

4. **Frontend**: Le fichier `static/index.html` doit pointer vers le bon port dans le code JavaScript.

---

## Derniere Mise a Jour

Date: 31 janvier 2026
Version: Max v2.0
Auteur: Claude Code (Opus 4.5)
