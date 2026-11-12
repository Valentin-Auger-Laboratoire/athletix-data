-- Athletix-Data — migration 002 : nettoyage des tables remplacées par le modèle EMG.
-- À lancer APRÈS 001_brassard_emg.sql :
--   mysql -u root athletix-pro < migrations/002_score_et_nettoyage.sql
-- Le script peut être relancé sans erreur.

USE `athletix-pro`;

-- D1 (voir architecture/MCD_MLD.md) : les scores « force, vitesse… » ne venaient d'aucune mesure
-- et l'application ne les remplissait jamais. Le classement est maintenant calculé à partir
-- de resultats_emg (voir backend/get_classement.php).
DROP TABLE IF EXISTS performances;

-- D3 : l'état du brassard est porté par la table brassards (batterie, dernière synchronisation),
-- mise à jour par l'application à chaque calibration ou séance.
DROP TABLE IF EXISTS hardware_status;

-- Accélère l'historique et le classement (séances d'un utilisateur, par date)
CREATE INDEX IF NOT EXISTS idx_sessions_user_debut ON sessions_entrainement (user_id, debut);
