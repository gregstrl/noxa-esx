-- =====================================================================
--  001_phone_contacts_display.sql
--  Exemple concret (réf. BUG-10) : garantir la colonne `display` sur
--  `noxa_phone_contacts` pour les bases legacy importées avant le renommage
--  `name` -> `display`. 100% idempotent : ne fait rien si déjà conforme.
-- =====================================================================

-- 1) Si l'ancienne colonne `name` existe encore et que `display` n'existe pas,
--    on renomme `name` -> `display`.
SET @has_name := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'noxa_phone_contacts' AND COLUMN_NAME = 'name');
SET @has_display := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'noxa_phone_contacts' AND COLUMN_NAME = 'display');
SET @sql_rename := IF(@has_name = 1 AND @has_display = 0,
  'ALTER TABLE `noxa_phone_contacts` CHANGE `name` `display` VARCHAR(64) NOT NULL',
  'DO 0');
PREPARE st_rename FROM @sql_rename; EXECUTE st_rename; DEALLOCATE PREPARE st_rename;

-- 2) Si ni `name` ni `display` n'existent (table créée autrement), on ajoute
--    `display` proprement.
SET @has_display2 := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'noxa_phone_contacts' AND COLUMN_NAME = 'display');
SET @table_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'noxa_phone_contacts');
SET @sql_add := IF(@table_exists = 1 AND @has_display2 = 0,
  'ALTER TABLE `noxa_phone_contacts` ADD COLUMN `display` VARCHAR(64) NOT NULL DEFAULT ''''',
  'DO 0');
PREPARE st_add FROM @sql_add; EXECUTE st_add; DEALLOCATE PREPARE st_add;
