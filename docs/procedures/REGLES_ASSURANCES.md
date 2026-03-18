# Regles Assurances Vitreflam

## Resume Rapide

```
┌─────────────────────────────────────────────────────────────┐
│                    ASSURANCE TRANSPORT                       │
│                    Delai: 2 JOURS                           │
├─────────────────────────────────────────────────────────────┤
│  AVEC assurance + dans delai → Photos → Remplacement (1x)   │
│  AVEC assurance + HORS delai → Remise 30%                   │
│  SANS assurance → Contacter Colissimo (pas de remise)        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    ASSURANCE MONTAGE                         │
│                    Delai: 8 JOURS                           │
├─────────────────────────────────────────────────────────────┤
│  AVEC assurance + dans delai → Photos → Remplacement (1x)   │
│  AVEC assurance + HORS delai → Remise 30%                   │
│  SANS assurance → Remise 30% (cause: erreur pose)           │
└─────────────────────────────────────────────────────────────┘
```

---

## Arbre de Decision

### Client dit: "Ma vitre est cassee"

```
1. QUAND est-elle cassee?
   │
   ├─► A la LIVRAISON (colis endommage)
   │   │
   │   └─► Avez-vous souscrit l'assurance TRANSPORT?
   │       │
   │       ├─► OUI
   │       │   └─► Declaration dans les 2 jours?
   │       │       ├─► OUI → Demander photos → REMPLACEMENT
   │       │       └─► NON → REMISE 30%
   │       │
   │       └─► NON
   │           └─► Contacter Colissimo:
   │               https://aide.laposte.fr/contact/colissimo
   │
   ├─► Au MONTAGE
   │   │
   │   └─► Avez-vous souscrit l'assurance MONTAGE?
   │       │
   │       ├─► OUI
   │       │   └─► Declaration dans les 8 jours?
   │       │       ├─► OUI → Demander photos → REMPLACEMENT
   │       │       └─► NON → REMISE 30%
   │       │
   │       └─► NON
   │           └─► Expliquer cause probable (pose)
   │               → REMISE 30%
   │
   └─► APRES utilisation
       │
       └─► Cause: probleme installation (pattes serrees)
           → REMISE 30% (jamais remplacement)
```

---

## Photos Requises

### Pour Assurance Transport (3 photos obligatoires)
1. Photo interieure du colis avec le verre casse
2. Photo de l'emballage exterieur
3. Photo de l'etiquette de transport

### Pour Assurance Montage
1. Photos detaillees de la vitre cassee
2. Si possible, photo de l'installation

---

## Calcul des Delais

### Assurance Transport
```
Date livraison: 15 janvier
Delai: +2 jours
Date limite declaration: 17 janvier 23h59
```

### Assurance Montage
```
Date livraison: 15 janvier
Delai: +8 jours
Date limite declaration: 23 janvier 23h59
```

---

## Conditions d'Utilisation

- **1 seul renvoi** par assurance
- Assurance liee a une commande specifique
- Non transferable a une autre commande
- Non cumulable

---

## Reponses Types

### Client AVEC assurance + dans delai
> "Vous avez bien souscrit l'assurance [transport/montage]. Merci de m'envoyer les photos demandees a contactglassgroup@gmail.com et nous procedons au remplacement."

### Client AVEC assurance + HORS delai
> "Je suis desole, le delai de declaration de [2/8] jours est depasse. En geste commercial, je peux vous proposer une remise de 30% sur une nouvelle commande."

### Client SANS assurance transport
> "Sans assurance transport, nous ne pouvons malheureusement pas intervenir. Je vous invite a contacter directement Colissimo pour effectuer une reclamation: https://aide.laposte.fr/contact/colissimo"

### Client SANS assurance montage
> "La casse au montage est generalement due aux pattes de fixation trop serrees. Sans assurance montage, je peux vous proposer une remise de 30% sur une nouvelle commande."

---

## CGV - Article L (Reference)

### Assurance casse au transport
> "Si vous avez contracte l'assurance transport et que votre vitre arrive cassee a la livraison, vous n'avez qu'a nous envoyer une photo interieure du colis avec le verre ainsi que de l'emballage exterieur et de l'etiquette de transport et nous vous enverrons une nouvelle vitre. Offre valable pour un seul renvoi, declaration sous 2 jours apres livraison."

### Assurance casse au montage
> "Si vous avez contracte l'assurance casse au montage et que vous la cassez au montage, envoyez nous des photos detaillees et nous vous enverrons une nouvelle vitre (le cas echeant en fonction des photos, nous pourrions vous prodiguer des conseils pour eviter une nouvelle casse). Offre valable pour un seul renvoi, declaration sous 8 jours apres livraison."

### Sans assurance transport
> "Si vous n'avez pas contracte l'assurance transport et que votre vitre arrive cassee vous devrez contacter le transporteur Colissimo et vous soumettre a ses directives."
