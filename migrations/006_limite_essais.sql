-- Athletix-Data — migration 006 : limite du nombre d'essais (connexion, renvoi du code, suppression du compte).
-- À lancer APRÈS 005_fatigue_frequence.sql :
--   mysql -u root athletix-pro < migrations/006_limite_essais.sql
-- Le script peut être relancé sans erreur.
-- Pas de donnée personnelle en clair : `cle` est une empreinte SHA-256 (de l'e-mail en minuscules,
-- de l'adresse IP ou du numéro de compte). Les lignes de plus d'un jour sont effacées automatiquement.

USE `athletix-pro`;

CREATE TABLE IF NOT EXISTS tentatives (
  id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  action  VARCHAR(20)  NOT NULL,          -- 'connexion', 'connexion_ip', 'renvoi_code', 'suppression'
  cle     CHAR(64)     NOT NULL,          -- SHA-256
  quand   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_tentatives (action, cle, quand),
  INDEX idx_tentatives_quand (quand)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
