-- Athletix-Data : structure de la base (vide) + 1 compte de démonstration fictif.
-- Import : phpMyAdmin > Importer, ou  mysql -u root < database.sql

CREATE DATABASE IF NOT EXISTS `athletix-pro` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `athletix-pro`;

CREATE TABLE users (
  id                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pseudo                VARCHAR(50)  NOT NULL,
  email                 VARCHAR(190) NOT NULL UNIQUE,
  password_hash         VARCHAR(255) NOT NULL,
  sport                 VARCHAR(50)  NOT NULL DEFAULT '',
  verified              TINYINT(1)   NOT NULL DEFAULT 0,
  verification_code     CHAR(6)      NULL,
  verification_expires  DATETIME     NULL,
  verification_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Jetons de session : seul le hash SHA-256 du jeton est stocké
CREATE TABLE auth_tokens (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  token_hash  CHAR(64)     NOT NULL UNIQUE,
  expires_at  DATETIME     NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Profils du questionnaire (une ligne par mise à jour pour garder l'historique)
CREATE TABLE profil_ia (
  id                         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id                    INT UNSIGNED NOT NULL,
  objectif_principal         VARCHAR(50)  NOT NULL,
  niveau_sportif             VARCHAR(30)  NOT NULL,
  poids                      SMALLINT UNSIGNED NOT NULL,
  taille                     SMALLINT UNSIGNED NOT NULL,
  frequence                  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  pathologies_blessures      VARCHAR(50)  NOT NULL DEFAULT 'Aucune',
  qualite_sommeil            VARCHAR(20)  NOT NULL,
  niveau_stress              TINYINT UNSIGNED NOT NULL DEFAULT 5,
  antecedents_cardio_perso   TINYINT(1)   NOT NULL DEFAULT 0,
  antecedents_cardio_famille TINYINT(1)   NOT NULL DEFAULT 0,
  created_at                 DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE sessions_entrainement (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE performances (
  id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  session_id         INT UNSIGNED NOT NULL,
  user_id            INT UNSIGNED NOT NULL,
  score_force        TINYINT UNSIGNED NOT NULL DEFAULT 0,
  score_endurance    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  score_vitesse      TINYINT UNSIGNED NOT NULL DEFAULT 0,
  score_technique    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  score_recuperation TINYINT UNSIGNED NOT NULL DEFAULT 0,
  FOREIGN KEY (session_id) REFERENCES sessions_entrainement(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- État du brassard, une ligne par utilisateur (écrite par update_hardware.php)
CREATE TABLE hardware_status (
  user_id          INT UNSIGNED PRIMARY KEY,
  connecte         TINYINT(1)   NOT NULL DEFAULT 0,
  batterie_niveau  TINYINT UNSIGNED NULL,
  derniere_synchro DATETIME     NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Compte de démonstration FICTIF (déjà vérifié)
--   email : demo@exemple.com   mot de passe : demo1234
INSERT INTO users (pseudo, email, password_hash, sport, verified) VALUES
  ('Demo', 'demo@exemple.com', '$2y$10$FzUh9m0bE0KhAb5rcCRlkuxw68iAFDPOwkNc2E5fSCNjsSVEsL.ta', 'Endurance & Cardio', 1);
