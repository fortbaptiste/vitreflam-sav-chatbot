# Rapport de Test - Oliver v3.0

Hello Fabien, j'espere que tu vas bien !

J'ai lance des tests automatiques sur Oliver pour verifier que tout fonctionne correctement apres les modifications qu'on a faites suite a notre dernier call. Voila le resultat sur **9 conversations completes** (30 echanges chacune, soit **270 echanges au total**).

---

## Resultat Global

| | |
|---|---|
| **Conversations testees** | 9 sur 9 reussies |
| **Echanges total** | 270 |
| **Echanges reussis** | 270 (100%) |
| **Erreurs** | 0 |
| **Temps moyen par reponse** | ~6.5 secondes |
| **Duree totale du test** | ~30 minutes |

**Verdict : Oliver repond a 100% sans aucun bug ni plantage.**

---

## Les 9 scenarios testes

| # | Scenario | Resultat | Temps moyen/reponse |
|---|----------|----------|---------------------|
| 1 | Casse transport **avec** assurance | 30/30 OK | 6.4s |
| 2 | Casse transport **sans** assurance | 30/30 OK | 6.6s |
| 3 | Casse montage **avec** assurance | 30/30 OK | 7.0s |
| 4 | Casse montage **sans** assurance | 30/30 OK | 6.6s |
| 5 | Probleme de dimensions | 30/30 OK | 6.2s |
| 6 | Suivi de commande | 30/30 OK | 6.9s |
| 7 | Client tres frustre (escalade) | 30/30 OK | 7.2s |
| 8 | Question produit simple | 30/30 OK | 6.1s |
| 9 | Client anglophone (casse transport) | 30/30 OK | 6.3s |

---

## Ce qu'on a corrige (recap de notre call)

Voici chaque point qu'on avait discute et comment Oliver se comporte maintenant :

---

### 1. Les boutons "Casse livraison / Casse montage / Suivi" ont ete supprimes

On en avait parle : ca donnait le baton pour se faire battre. C'est fait, le client arrive directement sur le chat et discute avec Oliver, sans suggestions de problemes.

---

### 2. Oliver est plus directif et ferme

**Avant** : Oliver etait trop gentil, il acceptait tout.

**Maintenant** : Il suspecte d'abord une erreur du client, puis il rassure.

Exemple concret (conversation 1 - casse transport) :

> **Client** : "Ma vitre est arrivee cassee ce matin"
>
> **Oliver** : "Avez-vous verifie l'etat de la vitre **en presence du livreur** et avez-vous souscrit a l'**assurance transport** ?"

> **Client** : "Non je n'ai pas verifie devant le livreur"
>
> **Oliver** : "C'est dommage, il fallait **absolument verifier en presence du livreur** pour faciliter les reclamations."

Il met la pression, puis rassure ensuite. C'est exactement ce qu'on voulait.

---

### 3. Les reponses sont plus courtes et concises

**Avant** : Oliver faisait des pavees de 4-5 phrases avec des listes.

**Maintenant** : 1 a 2 phrases maximum. Il va droit au but.

Exemple (conversation 8 - question produit) :

> **Client** : "Quelle epaisseur me conseillez-vous ?"
>
> **Oliver** : "Pour un insert, je recommande le **5mm** - c'est plus resistant aux chocs thermiques."

Pas de blabla, juste l'info utile.

---

### 4. Assurance montage corrigee : remplacement GRATUIT (plus 50%)

**Avant** : Oliver disait "remplacement a 50% du prix".

**Maintenant** : Il dit bien **remplacement gratuit**.

Exemple (conversation 3 - casse montage avec assurance) :

> **Client** : "D'accord donc le remplacement est gratuit ?"
>
> **Oliver** : "Oui, avec votre assurance montage le **remplacement sera gratuit**. Mais j'ai absolument besoin de vos photos du verre casse."

---

### 5. Oliver previent que le remplacement est valable une seule fois

Comme on en avait discute : le client doit savoir que c'est un one-shot.

Exemple (conversation 3) :

> **Client** : "Et si je la casse encore au montage ?"
>
> **Oliver** : "Si vous cassez le remplacement, **vous ne pourrez plus beneficier de l'assurance montage** car elle est valable **une seule fois par commande**."

---

### 6. Oliver rappelle l'assurance habitation du client

C'etait un point important : rappeler au client que son assurance maison peut le couvrir.

Exemple (conversation 2 - sans assurance transport) :

> **Client** : "J'ai une assurance habitation oui"
>
> **Oliver** : "Parfait ! Transmettez votre facture a votre **assurance habitation**, ils prennent souvent en charge ce type de sinistre."

Il le fait aussi de maniere proactive quand le client n'en parle pas :

> **Oliver** : "Avez-vous pense a transmettre votre facture a votre **assurance habitation** ? La plupart des contrats couvrent ce type de sinistre."

---

### 7. Oliver rappelle de verifier en presence du livreur

A chaque casse transport, Oliver rappelle cette regle importante.

Exemple (conversation 1) :

> **Oliver** : "Avez-vous verifie l'etat de la vitre **en presence du livreur** ?"

Exemple (conversation 9 - en anglais) :

> **Oliver** : "Did you check the glass condition **in the presence of the delivery driver** when you received it?"

Ca marche dans toutes les langues.

---

### 8. Sans assurance : Colissimo + remise 30%

**Avant** : Oliver ne proposait pas grand chose sans assurance.

**Maintenant** : Il oriente vers Colissimo ET propose la remise.

Exemple (conversation 2 - sans assurance transport) :

> **Client** : "Qu'est-ce que vous pouvez faire pour moi ?"
>
> **Oliver** : "Sans assurance transport, je peux vous proposer une **remise de 30%** sur votre prochaine commande. Pour la casse elle-meme, il faut contacter **Colissimo** directement."

---

### 9. Problemes de dimensions : Oliver escalade rapidement par mail

**Avant** : Oliver essayait de resoudre les dimensions tout seul.

**Maintenant** : Il redirige vers l'equipe.

Exemple (conversation 5) :

> **Client** : "J'ai mesure la vitre recue c'est 420x310mm au lieu de 400x300mm"
>
> **Oliver** : "Il y a effectivement un ecart de **20mm sur chaque dimension**. Pour verifier votre commande, merci de nous ecrire a **contactglassgroup@gmail.com** avec votre numero de commande et les mesures constatees."

Il ne promet rien, il laisse l'equipe humaine decider. C'est exactement ce qu'on voulait.

---

### 10. Client frustre : Oliver gere bien l'escalade

On a teste avec un client qui dit "SCANDALE", "avocat", "INADMISSIBLE" en majuscules.

Exemple (conversation 7) :

> **Client** : "C'EST INADMISSIBLE !!! CA FAIT 3 SEMAINES QUE J'ATTENDS"
>
> **Oliver** : "Je comprends votre mecontentement. Pouvez-vous me dire precisement ce qui s'est passe ?"

> **Client** : "Je vais contacter mon avocat"
>
> **Oliver** : "**Monsieur, calmez-vous.** Je suis la pour resoudre votre probleme maintenant."

> **Client** : "Je veux parler a un responsable IMMEDIATEMENT"
>
> **Oliver** : "**Tres bien, je vais escalader votre dossier.** Ecrivez a **contactglassgroup@gmail.com** pour une prise en charge personnalisee."

Il reste ferme, ne panique pas, et oriente vers le mail quand ca devient trop complexe.

---

### 11. Le multilingue fonctionne

Le test en anglais (conversation 9) montre qu'Oliver repond parfaitement en anglais avec les memes regles metier.

---

## Points a surveiller

Quelques observations pendant les tests :

1. **Oliver insiste beaucoup sur les photos** - Quand le client dit qu'il va envoyer des photos mais ne le fait pas dans le chat, Oliver le rappelle a chaque message. C'est bien mais parfois repetitif.

2. **Temps de reponse** - Environ 6-7 secondes en moyenne. Ca sera plus rapide quand on sera sur un plan payant (la c'est le free tier).

3. **Oliver ne promet rien sur les dimensions** - Il redirige systematiquement vers l'equipe par mail, il ne s'engage jamais. C'est parfait.

4. **Le rappel "une seule fois par commande"** - Oliver le mentionne bien mais parfois un peu tard dans la conversation. On pourra ajuster.

---

## Prochaines etapes

- Integration Colissimo (en attente de leur reponse)
- Acces PrestaShop pour matcher les assurances clients
- Ajouter plus de langues quand tu auras la liste
- Ajuster le comportement apres retour terrain en periode creuse

---

A mardi prochain pour le prochain point !

Baptiste
