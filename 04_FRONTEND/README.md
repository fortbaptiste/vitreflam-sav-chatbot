# Frontend - Chatbot Oliver SAV

## Fichiers

```
04_FRONTEND/
├── README.md      # Ce fichier
└── index.html     # Interface chat
```

## Interface

L'interface chat permet aux clients d'interagir avec Oliver, le conseiller SAV.

### Fonctionnalites

- Chat en temps reel avec Oliver
- Boutons rapides SAV:
  - Casse livraison
  - Casse montage
  - Suivi commande
  - Probleme dimensions
- Validation email obligatoire
- Historique conversation
- Persistance locale de l'email

### Configuration

Modifier l'URL du webhook dans le fichier `index.html`:

```javascript
// Ligne ~455
value="https://n8n.baptisten8n.online/webhook/vitreflam-sav-v3"
```

### Deploiement

Le fichier `index.html` peut etre:

1. **Heberge sur un CDN** (Netlify, Vercel, Cloudflare Pages)
2. **Integre dans le site Vitreflam** (page contact ou post-commande)
3. **Deploye sur serveur web** (Apache, Nginx)

### Style

- Couleur principale: `#E74C3C` (rouge Vitreflam)
- Police: Open Sans
- Responsive design

### Securite

- Validation email cote client
- Echappement HTML des messages
- CORS configure dans n8n
