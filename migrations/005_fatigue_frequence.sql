-- Athletix-Data — migration 005 : fatigue mesurée par la fréquence médiane du signal brut.
-- À lancer APRÈS 004_trace_series_hors_ligne.sql :
--   mysql -u root athletix-pro < migrations/005_fatigue_frequence.sql
-- Le script peut être relancé sans erreur.
-- Ces colonnes ne sont remplies que si le brassard lisait le signal brut (source RAW, firmware 1.2) :
-- voir hardware/firmware-brassard/FATIGUE.md.

USE `athletix-pro`;

ALTER TABLE resultats_emg
  -- Fréquence médiane au début et à la fin de la séance (droite ajustée sur les valeurs), en Hz
  ADD COLUMN IF NOT EXISTS mdf_debut_hz   DECIMAL(5,1) NULL AFTER courbe,
  ADD COLUMN IF NOT EXISTS mdf_fin_hz     DECIMAL(5,1) NULL AFTER mdf_debut_hz,
  -- Baisse entre le début et la fin, en % (positive = fatigue)
  ADD COLUMN IF NOT EXISTS baisse_mdf_pct DECIMAL(5,1) NULL AFTER mdf_fin_hz,
  -- Courbe : fréquence médiane moyenne par bloc de 30 s, JSON [Hz, …] (0 = bloc sans effort), 200 valeurs au plus
  ADD COLUMN IF NOT EXISTS courbe_mdf     TEXT         NULL AFTER baisse_mdf_pct;
