# Analyse des risques

Réalisée par **Valentin Auger** (novembre 2026).

> Mise à jour : 13 novembre 2026. Méthode de type AMDEC : pour chaque risque, **G** gravité, **O** probabilité d'apparition, **D** difficulté à le détecter, chacun noté de 1 à 4. **Criticité = G × O × D** (de 1 à 64). Au-dessus de **12**, une action est prévue avant les essais.

| Note | G (gravité) | O (apparition) | D (détection) |
|---|---|---|---|
| 1 | gêne, sans conséquence | très peu probable | détecté tout de suite, automatiquement |
| 2 | panne ou données perdues | possible | détecté par un contrôle prévu |
| 3 | blessure légère ou fuite de données personnelles | probable | détecté seulement en y pensant |
| 4 | blessure grave, brûlure, incendie | presque certain sans précaution | passe inaperçu |

## 1. Sécurité de la personne et du matériel

| Élément | Ce qui peut arriver | Effet | G | O | D | C | Ce qui est déjà prévu | Action restante |
|---|---|---|---|---|---|---|---|---|
| Batterie LiPo | connecteur JST câblé à l'envers | carte détruite, échauffement | 3 | 2 | 3 | **18** | vérification au multimètre avant le premier branchement (protocole, étape 0 ; avertissement sur le schéma) | marquer le + sur le connecteur une fois vérifié |
| Batterie LiPo | court-circuit pendant la soudure de l'interrupteur, gonflement, choc | brûlure, incendie | 4 | 1 | 2 | 8 | soudure sur le fil rouge seul, gaine thermo sur chaque soudure | vérifier que la batterie a un circuit de protection ; ne jamais charger sans surveillance |
| Électrodes reliées à la peau | brassard branché par USB à un PC **raccordé au secteur** pendant une mesure | courant de fuite par la peau en cas de défaut de l'alimentation du PC | 4 | 2 | 3 | **24** | le brassard fonctionne sur batterie | pendant une capture USB : **PC portable débranché du secteur** (ou isolateur USB) ; écrit dans `mesures/` et le protocole |
| Électrodes | irritation de la peau (gel, adhésif, port prolongé) | rougeurs | 2 | 2 | 2 | 8 | électrodes à usage court, peau propre et sèche | les changer à chaque séance, arrêter en cas de gêne |
| Boîtier | arêtes vives, serrage du brassard trop fort | gêne, marques | 1 | 2 | 1 | 2 | boîtier modélisé, congés sur les arêtes, étude RDM (clips, passants, pion du bouchon) | essai porté (protocole, étape 6) |
| Eau (natation) | eau dans le boîtier | carte et batterie détruites, risque électrique dans l'eau | 4 | 4 | 2 | **32** | prototype **non étanche**, dit dans l'appli, le README et le schéma ; essais à sec seulement (protocole, étape 7) | boîtier étanche (joint, passe-câble) avant tout essai dans l'eau, ou ne pas tester dans l'eau |
| Utilisation | la personne prend l'appli pour un avis médical | décision de santé erronée | 3 | 2 | 3 | **18** | « pas un dispositif médical » dans l'appli, le carnet PDF, le README ; conseils par règles, annoncés comme tels | rien de plus pour un prototype |

## 2. Mesure et liaison

| Élément | Ce qui peut arriver | Effet | G | O | D | C | Ce qui est déjà prévu | Action restante |
|---|---|---|---|---|---|---|---|---|
| Signal EMG | électrode décollée, gain trop fort | convertisseur saturé, intensité fausse | 2 | 3 | 1 | 6 | saturation signalée par le brassard (code 1) et affichée dans l'appli | — |
| Calibration | contraction maximale trop faible | toutes les intensités trop hautes, alertes injustifiées | 2 | 3 | 2 | **12** | calibration refusée sous 100 mV (code 3), recalibration à chaque séance conseillée | vérifier pendant les essais que 75 % correspond bien à un effort fort |
| Bruit du secteur (50 Hz) | parasite sur le câble jack | intensité au repos trop haute | 2 | 2 | 2 | 8 | fenêtre RMS de 200 ms, câble court ; contrôle « repos < 10 % » dans la comparaison automatique | torsader les 3 fils soudés |
| Câble jack recyclé | fils inversés à la soudure (pointe / bague / corps) | capteur non alimenté, ou signal sur la mauvaise broche | 2 | 3 | 2 | **12** | repérage au multimètre avant de souder (README du matériel, zoom sur le schéma) | contrôle de continuité après soudure |
| Bluetooth | liaison coupée pendant la séance | mesures perdues | 2 | 3 | 1 | 6 | coupure non comptée comme effort, résumé envoyé quand même ; natation : résumé gardé dans le brassard | — |
| Bluetooth | débit insuffisant (50 mesures/s) | mesures en retard | 1 | 2 | 1 | 2 | paquets groupés acceptés par l'appli (GATT.md) | mesurer pendant les essais |
| Batterie vide en séance | coupure du brassard | séance interrompue | 1 | 2 | 1 | 2 | batterie affichée, alerte sous 10 % (code 2) | mesurer l'autonomie (protocole, étape 6) |
| Firmware | écrit sans la carte, jamais compilé pour l'ESP32 | erreurs à la compilation | 2 | 3 | 1 | 6 | calculs testés sur ordinateur (129 vérifications), firmware complet exécuté avec des imitations des bibliothèques | compiler dans l'IDE Arduino dès la réception |
| Montre MSGM115 | application d'origine encore connectée | montre introuvable ou mesures qui n'arrivent pas | 1 | 3 | 1 | 3 | consigne « forcer l'arrêt de Yoho Sports » dans l'appli, le mode d'emploi et le protocole | — |
| Montre MSGM115 | format retrouvé dans l'appli d'origine, jamais essayé sur la montre | une commande mal comprise (heure sur 24 h, lever du poignet…) | 1 | 2 | 1 | 2 | format testé avec une montre simulée (mêmes octets) ; seules des lectures et des réglages réversibles, la remise à zéro n'est pas proposée dans Athletix-Data | protocole, étape 10 |
| Tension de la montre | prise pour une vraie mesure | fausse confiance | 2 | 2 | 2 | 8 | « estimation, pas une mesure médicale » à chaque affichage | — |

## 3. Données et serveur

| Élément | Ce qui peut arriver | Effet | G | O | D | C | Ce qui est déjà prévu | Action restante |
|---|---|---|---|---|---|---|---|---|
| Données de santé | fuite de la base | données personnelles exposées | 3 | 2 | 3 | **18** | mots de passe hachés, jetons stockés hachés, requêtes préparées, résumé seulement (jamais le signal brut), consentement, export et suppression du compte | HTTPS (tunnel ngrok) dès l'hébergement ; pas de vraies données de santé pendant le projet |
| Jeton de session | lu sur un réseau en HTTP | accès au compte | 3 | 2 | 3 | **18** | HTTP réservé au réseau local du prototype | n'utiliser que l'adresse HTTPS de ngrok |
| Mot de passe | essais en grand nombre | compte forcé | 3 | 1 | 3 | 9 | mot de passe redemandé pour supprimer le compte ; essais limités côté serveur (migration 006 : 5 par compte en 15 min, réponse 429) | — |
| Tracé GPS | domicile visible | vie privée | 3 | 2 | 2 | **12** | 200 premiers et derniers mètres non enregistrés, position météo arrondie à ~1 km | — |
| Classement | séance déclarée « mesurée » sans brassard | triche | 1 | 2 | 3 | 6 | séances simulées exclues | signature des résumés par le brassard (plus tard) |
| Séance sans réseau | perte ou doublon | séance perdue ou comptée deux fois | 2 | 2 | 1 | 4 | gardée sur le téléphone, renvoyée sans doublon (identifiant unique, testé) | — |

## 4. Projet

| Élément | Ce qui peut arriver | Effet | G | O | D | C | Ce qui est déjà prévu | Action restante |
|---|---|---|---|---|---|---|---|---|
| Matériel | livré en retard (commandé en novembre) | essais repoussés, prototype incomplet à la soutenance | 3 | 3 | 1 | 9 | tout ce qui ne dépend pas des pièces est fait ; protocole et comparaison automatique prêts ; brassard simulé pour la démo | prévenir l'encadrant tôt si la livraison dépasse janvier |
| Pièces | manquantes à la réception (câble, électrodes) | montage bloqué | 2 | 3 | 1 | 6 | solutions sans commande : câble audio recyclé, électrodes ECG standard | inventaire dès la réception |
| Carte | détruite pendant les essais | plus de prototype | 3 | 1 | 1 | 3 | ordre des étapes du protocole (batterie vérifiée avant tout) | — |
| Équipe | travail mal réparti, disponibilités | retard | 2 | 3 | 2 | **12** | rôles écrits, répartition dans la feuille de route, Gantt | point d'avancement à chaque jalon |

## Actions prioritaires (criticité de 12 ou plus)

1. **Eau** (32) : pas d'essai dans l'eau sans boîtier étanche.
2. **Isolation pendant une capture USB** (24) : PC portable débranché du secteur, ou isolateur USB.
3. **Polarité de la batterie** (18) : vérification au multimètre avant le premier branchement.
4. **Données et jeton** (18) : HTTPS par ngrok, données fictives pendant le projet.
5. **Usage médical** (18) : avertissements déjà en place, à garder.
6. **Calibration, câble jack, tracé GPS, équipe** (12) : contrôles prévus dans le protocole et la feuille de route.
