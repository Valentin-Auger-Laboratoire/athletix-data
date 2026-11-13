# Mesurer la fatigue du muscle : la fréquence médiane

Travail de **Valentin Auger** (novembre 2026), préparé avant de recevoir le matériel.

## Pourquoi

L'intensité (la valeur efficace du signal, en % de la contraction maximale) dit **combien** le muscle travaille, pas **s'il fatigue**. Pour un même effort, un muscle fatigué peut même montrer une intensité plus forte, parce qu'il recrute plus de fibres : c'est pour ça que l'ancien « indice de fatigue » de l'application n'était qu'un repère expérimental.

L'indicateur classique de la fatigue en électromyographie de surface est la **fréquence médiane** du spectre du signal (MDF, *median frequency*) : la fréquence qui partage la puissance du signal en deux moitiés égales. Quand le muscle fatigue, ses fibres conduisent le signal électrique moins vite, le spectre glisse vers les basses fréquences et **la fréquence médiane baisse**. Une baisse de 10 à 30 % au cours d'un effort qui fatigue est un ordre de grandeur courant. C'est aussi la première piste issue de la rencontre avec la patiente atteinte de sclérose en plaques (la fatigue est le symptôme le plus fréquent de la maladie).

## Ce qu'il faut côté matériel

L'enveloppe (sortie ENV du MyoWare 2.0) est lissée : elle n'a plus de contenu fréquentiel. Il faut le **signal brut** (sortie RAW). Le MyoWare 2.0 Link Shield a un interrupteur **OUTPUT** à trois positions (ENV, RECT, RAW) qui choisit le signal envoyé sur la pointe du jack (guide SparkFun du MyoWare 2.0). **Aucune pièce en plus n'est nécessaire** : on déplace l'interrupteur sur RAW et on le dit au brassard depuis l'application (écran « Brassard », « Brut + fatigue »).

Le signal brut est centré sur la moitié de l'alimentation (environ 1,65 V). Si le brassard est réglé sur RAW mais que le signal tourne autour de 0 V, l'interrupteur est sans doute resté sur ENV : le brassard le signale (code d'erreur 5) et l'application affiche « mets l'interrupteur sur RAW ».

## Le calcul (firmware 1.2, `calcul_fatigue.h`)

| Étape | Choix | Pourquoi |
|---|---|---|
| Échantillonnage | 2 000 Hz (au lieu de 500 Hz en ENV) | l'EMG de surface va jusqu'à ~450 Hz : il faut échantillonner à plus du double (Shannon) |
| Composante continue | filtre passe-haut du 1er ordre (coupure ≈ 1,6 Hz) | retire le ~1,65 V autour duquel le signal brut est centré |
| Intensité | valeur efficace sur 200 ms (400 échantillons), en % de la référence calibrée en RAW | même principe qu'en ENV ; la référence n'a pas la même échelle, d'où une nouvelle calibration |
| Fenêtre d'analyse | 1 024 échantillons = 0,512 s, fenêtre de Hann | 2 résultats par seconde ; Hann limite les fuites d'un pic vers les cases voisines |
| Spectre | FFT radix 2 écrite à la main (pas de bibliothèque) | vérifiée par l'égalité de Parseval et sur des sinus |
| Bande utile | 20–450 Hz, **sans 45–55 Hz** | bande de l'EMG de surface ; le secteur à 50 Hz peut être très fort, et la fenêtre de Hann l'étale sur ±2 cases (±4 Hz) |
| Fréquence médiane | case où la puissance cumulée atteint la moitié, interpolée dans la case | précision meilleure que la largeur d'une case (1,95 Hz) |
| Repos | pas de valeur si l'intensité moyenne de la fenêtre est sous 20 % | au repos, le spectre n'est que du bruit : la valeur ne voudrait rien dire |

Sur la carte, la FFT tourne dans une **tâche FreeRTOS séparée sur le cœur 0**, pendant que `loop()` continue d'échantillonner sur le cœur 1. Les deux cœurs échangent par des **files FreeRTOS** (une fenêtre à analyser, un résultat), et le tampon en cours d'analyse n'est jamais réécrit. Le firmware compte les échantillons pris chaque seconde et écrit un avertissement sur le port USB s'il en manque plus de 3 % (`loop()` trop lente). Il écrit aussi chaque résultat sur le port USB (`F,ms,MDF,MNF`) pour les essais.

## Dans l'application

- **Écran « Brassard »** : choix « Enveloppe » ou « Brut + fatigue », avec le rappel de déplacer l'interrupteur et de recalibrer.
- **Séance en direct** : fréquence médiane actuelle, celle du début, et l'écart en % (vert, orange au-delà de −5 %, rouge au-delà de −10 %).
- **Fin de séance** (`suivi_fatigue.dart`) : une droite est ajustée sur toutes les valeurs (moindres carrés) ; on en tire la MDF du début, celle de la fin et la **baisse en %**, plus une courbe (une valeur par bloc de 30 s). Au moins 20 valeurs sur 60 s, sinon rien n'est envoyé. La droite lisse le bruit d'une fenêtre à l'autre, ce que ne ferait pas « première valeur contre dernière ».
- **Détail d'une séance** : courbe de la fréquence médiane, tendance en pointillés, interprétation. **Carnet PDF et CSV** pour les soignants : colonnes de la fréquence médiane.
- **Serveur** : migration 005 (`mdf_debut_hz`, `mdf_fin_hz`, `baisse_mdf_pct`, `courbe_mdf`).
- **Démo** : les séances de musculation de la démo ont une fatigue mesurée (données inventées). Le brassard simulé, lui, fabrique un vrai signal brut (bruit filtré dont le spectre glisse quand la fatigue simulée monte) et le passe dans la **même** analyse que le firmware (copie en Dart).

## Ce qui a été vérifié, sans la carte

| Test | Ce qu'il vérifie | Résultat |
|---|---|---|
| `tests/firmware/test_calcul_fatigue.cpp` (34 vérifications) | FFT (pic, Parseval), sinus seuls et mélangés, 50 Hz et hors bande ignorés, composante continue, bruit filtré comparé à la médiane **théorique** (à 3 Hz près, 4 spectres), fatigue simulée, format du paquet | ✅ |
| `tests/firmware/test_firmware_complet.cpp` (28 vérifications) | le firmware **entier** (setup, loop, commandes Bluetooth, tâche d'analyse) exécuté sur ordinateur avec des imitations des bibliothèques ESP32 et un muscle simulé : séance ENV, calibration RAW, 2 fréquences par seconde, pas de valeur au repos, baisse avec la fatigue (148 → 127 Hz), interrupteur mal placé détecté, rythme de 2 000 échantillons/s, natation | ✅, aussi sans erreur sous ThreadSanitizer et AddressSanitizer |
| `test/fatigue_test.dart` (17 tests) | copie Dart : **même résultat que le C++** sur le même signal (142,21 Hz), suivi de la fatigue, brassard simulé en RAW | ✅ |
| `tests/api/test_api.sh` | enregistrement et relecture de la fatigue, valeurs invalides refusées, export RGPD | ✅ |

## Limites (à vérifier avec le vrai brassard)

- Le programme n'a **pas encore été compilé pour l'ESP32** (les outils Arduino ne sont pas accessibles depuis l'environnement de travail) : les imitations reprennent les mêmes fonctions, mais la première compilation dans l'Arduino IDE peut demander de petites corrections.
- Le temps de `analogReadMilliVolts` sur l'ESP32-S3 doit permettre 2 000 lectures par seconde : le firmware le contrôle et le signale.
- Les signaux de test sont des **bruits filtrés** qui ressemblent à de l'EMG, pas de vrais muscles. Les valeurs réelles de la fréquence médiane (souvent 60 à 130 Hz sur le biceps) seront mesurées à la réception.
- La fréquence médiane dépend aussi de l'exercice, de la température du muscle et de la position des électrodes : on compare une séance à elle-même (début / fin), pas deux personnes entre elles.
- Repère d'un prototype étudiant, **pas un dispositif médical**.
