-- ============================================================
-- NOXA Phone — tables (ESX Legacy / oxmysql)
-- Importer après legacy.sql. Idempotent (IF NOT EXISTS).
-- ============================================================

-- Contacts du répertoire (propres à chaque joueur)
CREATE TABLE IF NOT EXISTS `noxa_phone_contacts` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(60) NOT NULL,          -- identifier ESX du propriétaire
  `display` VARCHAR(64) NOT NULL,        -- nom affiché
  `number` VARCHAR(20) NOT NULL,         -- numéro du contact
  `favorite` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Messages (SMS) entre numéros
CREATE TABLE IF NOT EXISTS `noxa_phone_messages` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `sender` VARCHAR(20) NOT NULL,         -- numéro émetteur
  `receiver` VARCHAR(20) NOT NULL,       -- numéro destinataire
  `message` TEXT NOT NULL,
  `is_read` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sender` (`sender`),
  KEY `idx_receiver` (`receiver`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Canari (réseau social public type Twitter)
CREATE TABLE IF NOT EXISTS `noxa_phone_tweets` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `author_id` VARCHAR(60) NOT NULL,      -- identifier ESX de l'auteur
  `author_name` VARCHAR(64) NOT NULL,
  `handle` VARCHAR(32) NOT NULL,
  `message` TEXT NOT NULL,
  `likes` INT(11) NOT NULL DEFAULT 0,
  `retweets` INT(11) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
