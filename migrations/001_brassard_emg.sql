-- Athletix-Data — migration 001 : brassard EMG, calibrations et résultats de séance.
-- Voir architecture/MCD_MLD.md. À lancer APRÈS database.sql :
--   mysql -u root athletix-pro < migrations/001_brassard_emg.sql
-- Le script peut être relancé sans erreur (syntaxe IF NOT EXISTS de MariaDB, fournie avec XAMPP).

USE `athletix-pro`;

-- Un brassard est un objet : il existe même sans propriétaire (user_id NULL).
-- Il est identifié par le numéro de série lu en Bluetooth (caractéristique GATT 0x2A25).
CREATE TABLE IF NOT EXISTS brassards (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id          INT UNSIGNED NULL,
  numero_serie     VARCHAR(32)  NOT NULL UNIQUE,
  firmware         VARCHAR(20)  NULL,
  batterie_niveau  TINYINT UNSIGNED NULL,
  derniere_synchro DATETIME     NULL,
  created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Une ligne par calibration : la force varie d'un jour à l'autre, on garde l'historique.
CREATE TABLE IF NOT EXISTS calibrations (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  brassard_id INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NOT NULL,
  ref_mvc_mv  SMALLINT UNSIGNED NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (brassard_id) REFERENCES brassards(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)     REFERENCES users(id)     ON DELETE CASCADE
) ENGINE=InnoDB;

-- Une séance sait maintenant quoi, quand, avec quel brassard, et si les données sont simulées.
ALTER TABLE sessions_entrainement
  ADD COLUMN IF NOT EXISTS brassard_id      INT UNSIGNED NULL AFTER user_id,
  ADD COLUMN IF NOT EXISTS discipline       VARCHAR(50)  NULL AFTER brassard_id,
  ADD COLUMN IF NOT EXISTS debut            DATETIME     NULL AFTER discipline,
  ADD COLUMN IF NOT EXISTS fin              DATETIME     NULL AFTER debut,
  ADD COLUMN IF NOT EXISTS donnees_simulees TINYINT(1)   NOT NULL DEFAULT 0 AFTER fin;

ALTER TABLE sessions_entrainement
  ADD CONSTRAINT fk_session_brassard FOREIGN KEY IF NOT EXISTS (brassard_id)
      REFERENCES brassards(id) ON DELETE SET NULL;

-- Résumé EMG d'une séance. session_id est la clé primaire : au plus un résumé par séance.
-- On ne stocke PAS le signal à 50 Hz (volume et RGPD), seulement ce résumé.
CREATE TABLE IF NOT EXISTS resultats_emg (
  session_id             INT UNSIGNED PRIMARY KEY,
  duree_s                SMALLINT UNSIGNED NOT NULL,
  nb_echantillons        INT UNSIGNED      NOT NULL DEFAULT 0,
  intensite_moyenne_pct  TINYINT UNSIGNED  NOT NULL,
  intensite_max_pct      TINYINT UNSIGNED  NOT NULL,
  temps_effort_intense_s SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  nb_alertes             SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ref_mvc_mv             SMALLINT UNSIGNED NULL,
  FOREIGN KEY (session_id) REFERENCES sessions_entrainement(id) ON DELETE CASCADE
) ENGINE=InnoDB;
