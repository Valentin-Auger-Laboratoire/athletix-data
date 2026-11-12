-- Athletix-Data — migration 004 : tracé GPS, séries en musculation, envoi différé sans doublon.
-- À lancer APRÈS 003_contexte_telephone.sql :
--   mysql -u root athletix-pro < migrations/004_trace_series_hors_ligne.sql
-- Le script peut être relancé sans erreur.

USE `athletix-pro`;

ALTER TABLE sessions_entrainement
  -- Tracé du parcours : JSON [[latitude, longitude, secondes, intensité %], …], 500 points au plus,
  -- début et fin déjà retirés par l'application (200 m) pour ne pas révéler le domicile.
  ADD COLUMN IF NOT EXISTS trace_gps    MEDIUMTEXT  NULL AFTER mode_adapte,
  -- Identifiant tiré par le téléphone : une séance renvoyée après une coupure réseau
  -- n'est pas enregistrée deux fois.
  ADD COLUMN IF NOT EXISTS client_uuid  CHAR(36)    NULL AFTER trace_gps;

ALTER TABLE sessions_entrainement
  ADD UNIQUE INDEX IF NOT EXISTS uq_session_client (user_id, client_uuid);

ALTER TABLE resultats_emg
  -- Séries : groupes de contractions séparés d'au moins 20 s de repos (musculation)
  ADD COLUMN IF NOT EXISTS nb_series SMALLINT UNSIGNED NULL AFTER nb_contractions;
