-- Athletix-Data — migration 003 : contexte de la séance, mesures du téléphone, courbe résumée.
-- À lancer APRÈS 002_score_et_nettoyage.sql :
--   mysql -u root athletix-pro < migrations/003_contexte_telephone.sql
-- Le script peut être relancé sans erreur.

USE `athletix-pro`;

-- Mesures du téléphone et contexte saisi en fin de séance (tous facultatifs)
ALTER TABLE sessions_entrainement
  ADD COLUMN IF NOT EXISTS distance_m        INT UNSIGNED      NULL AFTER donnees_simulees,   -- GPS
  ADD COLUMN IF NOT EXISTS denivele_m        SMALLINT UNSIGNED NULL AFTER distance_m,         -- GPS, montée cumulée
  ADD COLUMN IF NOT EXISTS vitesse_moy_kmh   DECIMAL(4,1)      NULL AFTER denivele_m,
  ADD COLUMN IF NOT EXISTS nb_pas            INT UNSIGNED      NULL AFTER vitesse_moy_kmh,    -- accéléromètre
  ADD COLUMN IF NOT EXISTS fc_moy            TINYINT UNSIGNED  NULL AFTER nb_pas,             -- ceinture cardio
  ADD COLUMN IF NOT EXISTS fc_max            TINYINT UNSIGNED  NULL AFTER fc_moy,
  ADD COLUMN IF NOT EXISTS temperature_c     DECIMAL(4,1)      NULL AFTER fc_max,             -- météo
  ADD COLUMN IF NOT EXISTS humidite_pct      TINYINT UNSIGNED  NULL AFTER temperature_c,
  ADD COLUMN IF NOT EXISTS meteo_code        SMALLINT UNSIGNED NULL AFTER humidite_pct,       -- code WMO (Open-Meteo)
  ADD COLUMN IF NOT EXISTS ressenti_fatigue  TINYINT UNSIGNED  NULL AFTER meteo_code,         -- 0 à 10
  ADD COLUMN IF NOT EXISTS douleur           TINYINT UNSIGNED  NULL AFTER ressenti_fatigue,   -- 0 à 10
  ADD COLUMN IF NOT EXISTS sommeil           VARCHAR(20)       NULL AFTER douleur,            -- nuit précédente
  ADD COLUMN IF NOT EXISTS commentaire       VARCHAR(500)      NULL AFTER sommeil,
  ADD COLUMN IF NOT EXISTS mode_adapte       TINYINT(1)        NOT NULL DEFAULT 0 AFTER commentaire;

-- Résumé EMG enrichi. La courbe est un RÉSUMÉ (une valeur d'intensité toutes les 5 s),
-- pas le signal à 50 Hz : on garde la règle « on ne stocke pas le signal brut ».
ALTER TABLE resultats_emg
  ADD COLUMN IF NOT EXISTS temps_zone_repos_s     SMALLINT UNSIGNED NULL AFTER nb_alertes,   -- < 20 %
  ADD COLUMN IF NOT EXISTS temps_zone_moderee_s   SMALLINT UNSIGNED NULL AFTER temps_zone_repos_s,   -- 20–50 %
  ADD COLUMN IF NOT EXISTS temps_zone_soutenue_s  SMALLINT UNSIGNED NULL AFTER temps_zone_moderee_s, -- 50–75 %
  ADD COLUMN IF NOT EXISTS nb_contractions        SMALLINT UNSIGNED NULL AFTER temps_zone_soutenue_s,
  ADD COLUMN IF NOT EXISTS indice_fatigue_pct     SMALLINT          NULL AFTER nb_contractions,       -- dérive, expérimental
  ADD COLUMN IF NOT EXISTS courbe                 TEXT              NULL AFTER indice_fatigue_pct;    -- JSON [entiers 0–255]
