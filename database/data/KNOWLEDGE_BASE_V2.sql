-- =====================================================
-- VITREFLAM - BASE DE CONNAISSANCES V2
-- Optimisee pour SAV avec regles assurance strictes
-- =====================================================

-- Nettoyer les anciennes donnees si necessaire
-- DELETE FROM knowledge_base WHERE version = 1;

-- =====================================================
-- ASSURANCES (PRIORITE HAUTE)
-- =====================================================

INSERT INTO knowledge_base (contenu, categorie, sous_categorie, tags, source_document, metadata) VALUES

-- Assurance Transport
('ASSURANCE CASSE AU TRANSPORT: Si le client a souscrit l''assurance transport ET que la vitre arrive cassee, il doit envoyer une photo interieure du colis avec le verre, de l''emballage exterieur et de l''etiquette de transport. Nous envoyons une nouvelle vitre. DELAI: declaration sous 2 JOURS apres livraison. Offre valable pour UN SEUL renvoi.',
'assurances', 'transport', ARRAY['casse', 'transport', 'assurance', 'delai'], 'CGV Article L', '{"priorite": 10, "delai_jours": 2, "renvoi_max": 1}'::jsonb),

('SANS ASSURANCE TRANSPORT: Si le client n''a PAS souscrit l''assurance transport et que la vitre arrive cassee, il doit contacter directement le transporteur Colissimo (https://aide.laposte.fr/contact/colissimo) et se soumettre a ses directives. Vitreflam ne peut pas intervenir sans assurance.',
'assurances', 'transport', ARRAY['sans_assurance', 'colissimo', 'reclamation'], 'CGV Article L', '{"priorite": 10, "remplacement": false}'::jsonb),

-- Assurance Montage
('ASSURANCE CASSE AU MONTAGE: Si le client a souscrit l''assurance casse au montage ET qu''il casse la vitre au montage, il doit envoyer des photos detaillees. Nous envoyons une nouvelle vitre et pouvons prodiguer des conseils pour eviter une nouvelle casse. DELAI: declaration sous 8 JOURS apres livraison. Offre valable pour UN SEUL renvoi.',
'assurances', 'montage', ARRAY['casse', 'montage', 'assurance', 'delai'], 'CGV Article L', '{"priorite": 10, "delai_jours": 8, "renvoi_max": 1}'::jsonb),

('SANS ASSURANCE MONTAGE: Si le client n''a PAS souscrit l''assurance montage et qu''il casse la vitre au montage, nous ne pouvons pas remplacer gratuitement. Proposer une remise de 30% sur une nouvelle commande.',
'assurances', 'montage', ARRAY['sans_assurance', 'remise'], 'CGV Article L', '{"priorite": 10, "remplacement": false, "remise_proposee": 30}'::jsonb),

-- =====================================================
-- PROCEDURES CASSE
-- =====================================================

('VITRE CASSEE A LA LIVRAISON - COLIS REFUSE: Si le client a refuse le colis car casse, c''est la bonne procedure. Le colis revient en atelier et une nouvelle vitre sera envoyee dans les plus brefs delais.',
'procedures', 'casse_transport', ARRAY['refuse', 'renvoi', 'gratuit'], 'Procedures SAV', '{"priorite": 9, "action": "renvoi_gratuit"}'::jsonb),

('VITRE CASSEE A LA LIVRAISON - COLIS ACCEPTE SANS VERIFICATION: Si le client a accepte et signe la livraison sans verifier le contenu en presence du livreur, impossible pour nous d''effectuer un recours aupres du transporteur. Le client doit faire une reclamation aupres de La Poste. Proposer remise 30% sur nouvelle commande.',
'procedures', 'casse_transport', ARRAY['accepte', 'sans_verification', 'recours_impossible'], 'Procedures SAV', '{"priorite": 9, "remplacement": false, "remise_proposee": 30}'::jsonb),

('VITRE CASSEE APRES MONTAGE/UTILISATION: Dans la majorite des cas, il s''agit d''une erreur de pose (pattes de support trop serrees) ou d''une porte d''appareil vrilee. Le verre vitroceramique ne se dilate pas, donc si la vitre se fele apres mise en place, c''est un probleme d''installation, pas de la vitre. Proposer remise 30% sur nouvelle commande.',
'procedures', 'casse_montage', ARRAY['utilisation', 'pose', 'erreur_client'], 'Procedures SAV', '{"priorite": 9, "cause_probable": "erreur_pose", "remise_proposee": 30}'::jsonb),

-- =====================================================
-- DIMENSIONS ET ERREURS
-- =====================================================

('ERREUR DIMENSIONS - CLIENT: Si le client a fait une erreur dans la saisie des dimensions commandees, toutes les vitres sont decoupees sur mesure donc pas de remboursement possible. Proposer remise 30% sur nouvelle commande.',
'procedures', 'dimensions', ARRAY['erreur_client', 'saisie', 'remise'], 'Procedures SAV', '{"priorite": 8, "responsabilite": "client", "remise_proposee": 30}'::jsonb),

('VITRE TROP GRANDE - RECOUPE VITRIER: Si les dimensions recues sont plus grandes que souhaitees, le client peut se rapprocher d''un vitrier local pour faire recouper la vitre. Vitreflam rembourse les frais a hauteur de 15 euros TTC maximum sur presentation de facture.',
'procedures', 'dimensions', ARRAY['trop_grande', 'recoupe', 'vitrier', 'remboursement'], 'Procedures SAV', '{"priorite": 8, "remboursement_max_ttc": 15}'::jsonb),

('VITRE TROP PETITE - VERIFICATION: Demander au client les dimensions recues avec photos et metre a cote. Verifier si correspond a la commande. Si erreur atelier Vitreflam: renvoi gratuit. Si erreur client: remise 30% sur nouvelle commande.',
'procedures', 'dimensions', ARRAY['trop_petite', 'verification', 'photos'], 'Procedures SAV', '{"priorite": 8}'::jsonb),

('CONFIRMATION MM OU CM: Les dimensions doivent TOUJOURS etre en millimetres (mm). Si doute sur cm vs mm, demander confirmation au client avant envoi. Les verres Vitreflam sont compris entre 50 et 780 mm.',
'procedures', 'dimensions', ARRAY['millimetres', 'confirmation', 'verification'], 'Procedures SAV', '{"priorite": 8, "unite": "mm", "min": 50, "max": 780}'::jsonb),

('ERREUR ATELIER VITREFLAM: Si les dimensions recues ne correspondent PAS a celles commandees (erreur de notre part), remplacement gratuit. Le client peut renvoyer la vitre avec un gabarit papier, elle sera recoupee et renvoyee.',
'procedures', 'dimensions', ARRAY['erreur_atelier', 'remplacement_gratuit'], 'Procedures SAV', '{"priorite": 8, "responsabilite": "vitreflam", "remplacement": true}'::jsonb),

-- =====================================================
-- LIVRAISON ET SUIVI
-- =====================================================

('SUIVI LIVRAISON: Toutes les livraisons sont effectuees par Colissimo. Suivi disponible sur https://www.laposte.fr/outils/suivre-vos-envois?code=NUMERO. A l''international, parfois un partenaire type TNT prend le relais.',
'livraison', 'suivi', ARRAY['colissimo', 'suivi', 'tracking'], 'Procedures Livraison', '{"priorite": 7, "transporteur": "colissimo"}'::jsonb),

('DELAIS: Fabrication 5-7 jours ouvres. Livraison 2-5 jours apres expedition. Franco de port a partir de 150 euros.',
'livraison', 'delais', ARRAY['fabrication', 'livraison', 'franco'], 'Procedures Livraison', '{"priorite": 7, "fabrication_jours": "5-7", "livraison_jours": "2-5", "franco_euros": 150}'::jsonb),

('COLIS EN POINT RELAIS: Si le colis n''a pas pu etre remis, il est disponible en point relais. A retirer sous 10 jours ouvrables en relais commercant (avec piece d''identite) ou sous 3 jours en consigne.',
'livraison', 'point_relais', ARRAY['retrait', 'relais', 'delai'], 'Procedures Livraison', '{"priorite": 7, "delai_relais_jours": 10, "delai_consigne_jours": 3}'::jsonb),

('RETOUR EXPEDITEUR: Si le colis revient en atelier (adresse incomplete, non retire), il peut etre renvoye moyennant une participation aux frais de port de 12 a 15 euros.',
'livraison', 'retour', ARRAY['retour_expediteur', 'frais_port'], 'Procedures Livraison', '{"priorite": 7, "frais_renvoi_min": 12, "frais_renvoi_max": 15}'::jsonb),

('ADRESSE INCOMPLETE: Si l''adresse communiquee semble incorrecte ou incomplete, demander au client de fournir une adresse de livraison complete.',
'livraison', 'adresse', ARRAY['incomplete', 'incorrecte', 'verification'], 'Procedures Livraison', '{"priorite": 7}'::jsonb),

('COLIS LIVRE MAIS NON RECU: Si le suivi indique livre mais le client n''a pas recu, lui demander de verifier aupres des voisins et de faire une reclamation aupres de La Poste. Demander attestation sur l''honneur avec piece d''identite.',
'livraison', 'litige', ARRAY['livre', 'non_recu', 'reclamation'], 'Procedures Livraison', '{"priorite": 7}'::jsonb),

-- =====================================================
-- PRODUITS VITREFLAM
-- =====================================================

('VERRE CERAMIQUE/VITROCERAMIQUE: Vitreflam ne fabrique QUE du verre ceramique (vitroceramique) resistant jusqu''a 800 degres C. Pas de verre trempe.',
'produits', 'types', ARRAY['ceramique', 'vitroceramique', 'resistance'], 'Info Produits', '{"priorite": 6, "type_unique": "ceramique", "resistance_max_celsius": 800}'::jsonb),

('OPTIONS DISPONIBLES: Verre standard ou autonettoyant. Joint noir en fibre de verre tressee auto-collant 10x2mm inclus sur demande. Pas de percage en atelier.',
'produits', 'options', ARRAY['autonettoyant', 'joint', 'percage'], 'Info Produits', '{"priorite": 6, "joint_dimensions": "10x2mm", "percage": false}'::jsonb),

('POSE AUTONETTOYANT: L''etiquette autocollante indique que le cote traite doit etre positionne a l''exterieur du foyer (cote piece, pas cote feu) pour garantir la fonctionnalite autonettoyante.',
'produits', 'installation', ARRAY['autonettoyant', 'pose', 'orientation'], 'Conseils Techniques', '{"priorite": 6}'::jsonb),

('GARANTIE: 2 ans sur les produits fabriques. La garantie couvre les defauts de fabrication, pas les erreurs de pose ou casses.',
'produits', 'garantie', ARRAY['garantie', 'defaut', 'fabrication'], 'CGV', '{"priorite": 6, "duree_ans": 2}'::jsonb),

-- =====================================================
-- CGV ET RETRACTATION
-- =====================================================

('DROIT DE RETRACTATION: Conformement a l''article L.221-28 du Code de la consommation, le droit de retractation ne peut etre exerce pour les biens confectionnes selon les specifications du consommateur. Tous les produits Vitreflam sont sur mesure donc AUCUNE annulation ni remboursement n''est possible.',
'cgv', 'retractation', ARRAY['retractation', 'sur_mesure', 'annulation'], 'CGV Article K', '{"priorite": 9, "retractation_possible": false}'::jsonb),

('VALIDATION COMMANDE: Lors de la validation, le client accepte la commande et l''integralite des CGV. Vitreflam ne peut etre tenu responsable des erreurs sur les informations fournies par le client (coordonnees, dimensions).',
'cgv', 'validation', ARRAY['validation', 'responsabilite', 'erreur_client'], 'CGV Article C', '{"priorite": 8}'::jsonb),

('POLITIQUE RENVOI: Notre politique est le renvoi d''un verre des lors que celui-ci a subi des dommages de notre fait. Mais les produits sur mesure ne sont pas remboursables.',
'cgv', 'renvoi', ARRAY['renvoi', 'politique', 'sur_mesure'], 'CGV', '{"priorite": 8}'::jsonb),

-- =====================================================
-- GESTES COMMERCIAUX
-- =====================================================

('REMISE 30% NOUVELLE COMMANDE: En cas d''incident non couvert par assurance ou erreur client, proposer une remise de 30% sur une nouvelle commande. La remise est enregistree et appliquee automatiquement sur le prochain panier. Valable 1 an.',
'commercial', 'remise', ARRAY['remise', '30_pourcent', 'incident'], 'Politique Commerciale', '{"priorite": 7, "remise_pourcent": 30, "validite_mois": 12}'::jsonb),

('COMPENSATION RETARD FABRICATION: Retard 3-5 jours: remise 5%. Retard superieur a 5 jours: remise 10%. Maximum 15% sans escalade.',
'commercial', 'compensation', ARRAY['retard', 'compensation', 'remise'], 'Politique Commerciale', '{"priorite": 7, "retard_3_5j": 5, "retard_5j_plus": 10, "max_sans_escalade": 15}'::jsonb),

('REMBOURSEMENT JOINT: Si le joint livre ne correspond pas au joint d''origine du client, remboursement du montant du joint (environ 7.90 euros).',
'commercial', 'remboursement', ARRAY['joint', 'remboursement'], 'Politique Commerciale', '{"priorite": 6, "montant_joint": 7.90}'::jsonb),

('REMBOURSEMENT DIFFERENCE AUTO-STANDARD: Si l''atelier a envoye un verre standard au lieu d''autonettoyant, rembourser la difference de prix.',
'commercial', 'remboursement', ARRAY['autonettoyant', 'standard', 'difference'], 'Politique Commerciale', '{"priorite": 6}'::jsonb),

-- =====================================================
-- CONTACTS ET ADRESSES
-- =====================================================

('ADRESSE RETOUR COLIS: Sarl Cosse & Co, La Rafette, 27 rue Gutenberg, 33450 Saint Loubes, FRANCE',
'contact', 'adresse', ARRAY['retour', 'adresse', 'atelier'], 'Info Contact', '{"priorite": 5}'::jsonb),

('EMAIL SAV: contactglassgroup@gmail.com - Pour envoi de photos, factures, reclamations.',
'contact', 'email', ARRAY['email', 'sav', 'photos'], 'Info Contact', '{"priorite": 5}'::jsonb),

('LIEN RECLAMATION COLISSIMO: https://aide.laposte.fr/contact/colissimo - Pour les clients sans assurance transport ou problemes de livraison.',
'contact', 'colissimo', ARRAY['colissimo', 'reclamation', 'lien'], 'Info Contact', '{"priorite": 5}'::jsonb),

('PAIEMENT SUMUP: Les paiements complementaires (frais de port, difference de prix) se font via lien Sumup envoye par le service financier.',
'contact', 'paiement', ARRAY['sumup', 'paiement', 'complement'], 'Info Contact', '{"priorite": 5}'::jsonb);

-- =====================================================
-- MISE A JOUR DU TIMESTAMP
-- =====================================================
UPDATE knowledge_base SET updated_at = NOW(), version = 2 WHERE version IS NULL OR version < 2;
