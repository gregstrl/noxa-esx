# Migrations SQL — NOXA

Ce dossier contient les **migrations incrémentales** de la base `noxa`.

## À quoi ça sert

`install.sql` (à la racine) reste **LE fichier unique** qui crée la base et toutes
les tables (idempotent, `CREATE TABLE IF NOT EXISTS`). Il est parfait pour une
**première installation**.

Mais quand une base est **déjà importée** chez un joueur et qu'on doit modifier
une table existante (ajouter une colonne, renommer un champ, créer un index…),
on ne peut pas se contenter de `CREATE TABLE IF NOT EXISTS`. C'est le rôle des
**migrations** : chaque fichier `.sql` numéroté est joué **une seule fois**, dans
l'ordre, par la commande console `install noxa` (ressource `noxa_updater`).

Le suivi se fait dans la table `noxa_migrations` (nom du fichier + date). Une
migration déjà présente dans cette table n'est jamais rejouée.

## Règles

1. **Un fichier = une migration**, nommé `NNN_description.sql` (numéro à 3
   chiffres croissant : `001_…`, `002_…`). L'ordre alphabétique = l'ordre
   d'exécution.
2. **Toujours idempotent** : si la table `noxa_migrations` est perdue et que la
   migration est rejouée, elle ne doit pas casser. Utiliser les gardes
   `INFORMATION_SCHEMA` (voir le template ci-dessous).
3. **Jamais** de `.sql` dispersé dans les ressources. Les migrations vivent
   **ici uniquement**. Les nouvelles tables d'une ressource vont dans
   `install.sql` (section « TABLES CUSTOM NOXA »).
4. Après avoir édité une migration ou `install.sql`, lance `update.sh`
   (ou `update.bat`) : il resynchronise ces fichiers dans
   `resources/noxa_updater/sql/` (le seul endroit que le sandbox FiveM autorise
   à lire), puis tape `install noxa` dans la console serveur.

## Template d'une migration idempotente (ajout de colonne)

```sql
-- 002_ma_table_ma_colonne.sql — ajoute `ma_colonne` à `ma_table` si absente
SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ma_table' AND COLUMN_NAME = 'ma_colonne');
SET @s := IF(@c = 0,
  'ALTER TABLE `ma_table` ADD COLUMN `ma_colonne` VARCHAR(64) NOT NULL DEFAULT ''''',
  'DO 0');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
```

> ℹ️ Les migrations utilisent `PREPARE`/`EXECUTE` (plusieurs requêtes par
> fichier). `noxa_updater` envoie chaque fichier en un seul appel oxmysql :
> la chaîne de connexion **doit** contenir `multipleStatements=true`
> (voir `server.cfg`).
