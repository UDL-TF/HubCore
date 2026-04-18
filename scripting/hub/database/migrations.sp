/**
 * HubCore Database Migrations System
 * 
 * Handles schema versioning and database migrations.
 * Each migration is run sequentially from the current version to the target version.
 */

#define HUB_SCHEMA_VERSION 3  // Current target schema version

// Migration state
bool g_MigrationsComplete = false;
int g_CurrentSchemaVersion = 0;

/**
 * Initialize the schema version system.
 * Creates the schema_version table if it doesn't exist.
 */
void Migrations_Init()
{
    char query[512];
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%sschema_version` (`version` INT NOT NULL PRIMARY KEY, `description` VARCHAR(255) NOT NULL, `applied_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE = InnoDB;",
        databasePrefix);
    
    DB.Query(OnSchemaTableCreated, query);
}

/**
 * Callback after schema version table is created.
 */
public void OnSchemaTableCreated(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogToFile(logFile, "[Migrations] Failed to create schema_version table: %s", error);
        SetFailState("[Migrations] Failed to create schema_version table: %s", error);
        return;
    }
    
    LogToFile(logFile, "[Migrations] Schema version table ready.");
    Migrations_CheckCurrentVersion();
}

/**
 * Query the current schema version.
 */
void Migrations_CheckCurrentVersion()
{
    char query[256];
    Format(query, sizeof(query), 
        "SELECT MAX(`version`) FROM `%sschema_version`;",
        databasePrefix);
    
    DB.Query(OnSchemaVersionQueried, query);
}

/**
 * Callback after querying current schema version.
 */
public void OnSchemaVersionQueried(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogToFile(logFile, "[Migrations] Failed to query schema version: %s", error);
        // Assume version 0 if we can't query
        g_CurrentSchemaVersion = 0;
    }
    else if (results.FetchRow())
    {
        g_CurrentSchemaVersion = results.IsFieldNull(0) ? 0 : results.FetchInt(0);
    }
    else
    {
        g_CurrentSchemaVersion = 0;
    }
    
    LogToFile(logFile, "[Migrations] Current schema version: %d, Target: %d", g_CurrentSchemaVersion, HUB_SCHEMA_VERSION);
    
    // Run migrations if needed
    if (g_CurrentSchemaVersion < HUB_SCHEMA_VERSION)
    {
        Migrations_RunMigrations(g_CurrentSchemaVersion, HUB_SCHEMA_VERSION);
    }
    else
    {
        LogToFile(logFile, "[Migrations] Schema is up to date.");
        g_MigrationsComplete = true;
        Migrations_OnComplete();
    }
}

/**
 * Run migrations from current version to target version.
 */
void Migrations_RunMigrations(int fromVersion, int toVersion)
{
    LogToFile(logFile, "[Migrations] Running migrations from v%d to v%d...", fromVersion, toVersion);
    
    // Run each migration sequentially
    for (int v = fromVersion + 1; v <= toVersion; v++)
    {
        switch(v)
        {
            case 1: Migration_V1();
            case 2: Migration_V2();
            case 3: Migration_V3();
            // Add new migrations here as needed
        }
    }
}

/**
 * Migration V1: Create legacy tables (for backwards compatibility)
 * This creates the original table structure for servers that don't have it.
 */
void Migration_V1()
{
    LogToFile(logFile, "[Migrations] Running Migration V1: Legacy tables...");
    
    Transaction txn = new Transaction();
    char query[1024];
    
    // Players table
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%splayers` (`steamid` VARCHAR(32) NOT NULL, `name` VARCHAR(32) NOT NULL, `ip` VARCHAR(32) NOT NULL, PRIMARY KEY (`steamid`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Credits table
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%scredits` (`steamid` VARCHAR(32) NOT NULL, `credits` INT NOT NULL, PRIMARY KEY (`steamid`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Times table
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%stimes` (`steamid` VARCHAR(32) NOT NULL, `daily` INT NOT NULL, PRIMARY KEY (`steamid`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Categories table
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%scategories` (`id` INT NOT NULL AUTO_INCREMENT, `name` VARCHAR(32) NOT NULL, PRIMARY KEY (`id`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Items table
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%sitems` (`id` INT NOT NULL AUTO_INCREMENT, `name` VARCHAR(32) NOT NULL, `description` VARCHAR(128) NOT NULL, `type` VARCHAR(32) NOT NULL, `categoryId` INT NOT NULL, `price` INT NOT NULL, PRIMARY KEY (`id`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Player items table
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%splayer_items` (`steamid` VARCHAR(32) NOT NULL, `itemId` INT NOT NULL, `equiped` BOOLEAN NOT NULL DEFAULT FALSE, PRIMARY KEY (`steamid`, `itemId`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    DB.Execute(txn, OnMigrationV1Success, OnMigrationFailed, 1);
}

public void OnMigrationV1Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    LogToFile(logFile, "[Migrations] Migration V1 completed successfully.");
    Migrations_SetVersion(1, "Legacy tables created");
}

/**
 * Migration V2: Create new unified player table and supporting tables
 */
void Migration_V2()
{
    LogToFile(logFile, "[Migrations] Running Migration V2: New unified schema...");
    
    Transaction txn = new Transaction();
    char query[2048];
    
    // New unified players table with JSON columns
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%splayers_v2` (`id` BIGINT AUTO_INCREMENT PRIMARY KEY, `steamid` VARCHAR(32) NOT NULL UNIQUE, `steamid64` BIGINT UNSIGNED NOT NULL DEFAULT 0, `name` VARCHAR(64) NOT NULL, `ip` VARCHAR(45) NOT NULL, `credits` INT UNSIGNED NOT NULL DEFAULT 0, `first_join` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, `play_time_seconds` INT UNSIGNED NOT NULL DEFAULT 0, `settings` JSON, `cosmetics` JSON, `metadata` JSON, INDEX `idx_steamid64` (`steamid64`), INDEX `idx_last_seen` (`last_seen`), INDEX `idx_credits` (`credits`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Player selections table (replaces cookies)
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%splayer_selections` (`id` BIGINT AUTO_INCREMENT PRIMARY KEY, `steamid` VARCHAR(32) NOT NULL, `selection_type` VARCHAR(32) NOT NULL, `selection_value` VARCHAR(255) NOT NULL, `extra_data` JSON, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, UNIQUE KEY `unique_selection` (`steamid`, `selection_type`), INDEX `idx_steamid` (`steamid`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Audit log table
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%saudit_log` (`id` BIGINT AUTO_INCREMENT PRIMARY KEY, `steamid` VARCHAR(32) NOT NULL, `event_type` VARCHAR(50) NOT NULL, `event_data` JSON NOT NULL, `old_value` JSON, `new_value` JSON, `source` VARCHAR(50) NOT NULL, `ip_address` VARCHAR(45), `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX `idx_steamid` (`steamid`), INDEX `idx_event_type` (`event_type`), INDEX `idx_created_at` (`created_at`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // New categories table (v2)
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%scategories_v2` (`id` INT AUTO_INCREMENT PRIMARY KEY, `name` VARCHAR(64) NOT NULL, `description` VARCHAR(255), `sort_order` INT NOT NULL DEFAULT 0, `is_active` BOOLEAN NOT NULL DEFAULT TRUE, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // New items table (v2) with JSON attributes
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%sitems_v2` (`id` INT AUTO_INCREMENT PRIMARY KEY, `category_id` INT NOT NULL, `name` VARCHAR(64) NOT NULL, `description` VARCHAR(255), `type` VARCHAR(32) NOT NULL, `price` INT UNSIGNED NOT NULL DEFAULT 0, `attributes` JSON, `is_active` BOOLEAN NOT NULL DEFAULT TRUE, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX `idx_category` (`category_id`), INDEX `idx_type` (`type`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // New player items table (v2) with soft delete
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%splayer_items_v2` (`id` BIGINT AUTO_INCREMENT PRIMARY KEY, `steamid` VARCHAR(32) NOT NULL, `item_id` INT NOT NULL, `equipped` BOOLEAN NOT NULL DEFAULT FALSE, `purchase_price` INT UNSIGNED NOT NULL, `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `deleted_at` TIMESTAMP NULL DEFAULT NULL, INDEX `idx_steamid` (`steamid`), INDEX `idx_equipped` (`steamid`, `equipped`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Player timers table (for daily rewards, etc.)
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%splayer_timers` (`id` BIGINT AUTO_INCREMENT PRIMARY KEY, `steamid` VARCHAR(32) NOT NULL, `timer_type` VARCHAR(50) NOT NULL, `last_claimed` TIMESTAMP NOT NULL, `claim_count` INT UNSIGNED NOT NULL DEFAULT 1, UNIQUE KEY `unique_timer` (`steamid`, `timer_type`), INDEX `idx_steamid` (`steamid`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    // Cosmetics configuration table
    Format(query, sizeof(query), 
        "CREATE TABLE IF NOT EXISTS `%scosmetics` (`id` INT AUTO_INCREMENT PRIMARY KEY, `type` VARCHAR(32) NOT NULL, `name` VARCHAR(64) NOT NULL, `display_name` VARCHAR(128), `config` JSON NOT NULL, `sort_order` INT NOT NULL DEFAULT 0, `is_active` BOOLEAN NOT NULL DEFAULT TRUE, `requires_item_id` INT DEFAULT NULL, INDEX `idx_type_active` (`type`, `is_active`, `sort_order`)) ENGINE = InnoDB;",
        databasePrefix);
    txn.AddQuery(query);
    
    DB.Execute(txn, OnMigrationV2TablesSuccess, OnMigrationFailed, 2);
}

public void OnMigrationV2TablesSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    LogToFile(logFile, "[Migrations] Migration V2 tables created. Migrating data...");
    
    // Migrate data from old tables to new tables
    Migrations_MigrateV1ToV2Data();
}

/**
 * Migrate data from v1 tables to v2 tables
 */
void Migrations_MigrateV1ToV2Data()
{
    Transaction txn = new Transaction();
    char query[1024];
    
    // Migrate players data
    Format(query, sizeof(query), 
        "INSERT INTO `%splayers_v2` (`steamid`, `name`, `ip`, `credits`, `settings`, `cosmetics`, `metadata`) SELECT p.`steamid`, p.`name`, p.`ip`, COALESCE(c.`credits`, 0), '{}', '{}', '{}' FROM `%splayers` p LEFT JOIN `%scredits` c ON p.`steamid` = c.`steamid` ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `ip` = VALUES(`ip`);",
        databasePrefix, databasePrefix, databasePrefix);
    txn.AddQuery(query);
    
    // Migrate categories
    Format(query, sizeof(query), 
        "INSERT INTO `%scategories_v2` (`id`, `name`) SELECT `id`, `name` FROM `%scategories` ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);",
        databasePrefix, databasePrefix);
    txn.AddQuery(query);
    
    // Migrate items
    Format(query, sizeof(query), 
        "INSERT INTO `%sitems_v2` (`id`, `category_id`, `name`, `description`, `type`, `price`, `attributes`) SELECT `id`, `categoryId`, `name`, `description`, `type`, `price`, '{}' FROM `%sitems` ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);",
        databasePrefix, databasePrefix);
    txn.AddQuery(query);
    
    // Migrate player items
    Format(query, sizeof(query), 
        "INSERT INTO `%splayer_items_v2` (`steamid`, `item_id`, `equipped`, `purchase_price`) SELECT `steamid`, `itemId`, `equiped`, 0 FROM `%splayer_items` ON DUPLICATE KEY UPDATE `equipped` = VALUES(`equipped`);",
        databasePrefix, databasePrefix);
    txn.AddQuery(query);
    
    // Migrate times to player_timers
    Format(query, sizeof(query), 
        "INSERT INTO `%splayer_timers` (`steamid`, `timer_type`, `last_claimed`) SELECT `steamid`, 'daily', FROM_UNIXTIME(`daily`) FROM `%stimes` WHERE `daily` > 0 ON DUPLICATE KEY UPDATE `last_claimed` = VALUES(`last_claimed`);",
        databasePrefix, databasePrefix);
    txn.AddQuery(query);
    
    DB.Execute(txn, OnMigrationV2DataSuccess, OnMigrationFailed, 2);
}

public void OnMigrationV2DataSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    LogToFile(logFile, "[Migrations] Migration V2 data migration completed successfully.");
    Migrations_SetVersion(2, "Unified schema with JSON columns");
}

/**
 * Migration V3: Add streak column to player_timers table
 */
void Migration_V3()
{
    LogToFile(logFile, "[Migrations] Running Migration V3: Add streak to player_timers...");
    
    char query[512];
    Format(query, sizeof(query),
        "ALTER TABLE `%splayer_timers` ADD COLUMN IF NOT EXISTS `streak` INT UNSIGNED NOT NULL DEFAULT 1;",
        databasePrefix);
    
    DB.Query(OnMigrationV3Success, query);
}

public void OnMigrationV3Success(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogToFile(logFile, "[Migrations] Migration V3 failed: %s", error);
        SetFailState("[Migrations] Migration V3 failed: %s", error);
        return;
    }
    LogToFile(logFile, "[Migrations] Migration V3 completed successfully.");
    Migrations_SetVersion(3, "Add streak column to player_timers");
}

/**
 * Set the schema version after a successful migration.
 */
void Migrations_SetVersion(int version, const char[] description)
{
    char query[512];
    char escapedDesc[256];
    DB.Escape(description, escapedDesc, sizeof(escapedDesc));
    
    Format(query, sizeof(query), 
        "INSERT INTO `%sschema_version` (`version`, `description`) VALUES (%d, '%s') ON DUPLICATE KEY UPDATE `description` = '%s', `applied_at` = CURRENT_TIMESTAMP;",
        databasePrefix, version, escapedDesc, escapedDesc);
    
    DB.Query(OnSchemaVersionSet, query, version);
}

public void OnSchemaVersionSet(Database db, DBResultSet results, const char[] error, int version)
{
    if (results == null)
    {
        LogToFile(logFile, "[Migrations] Failed to set schema version %d: %s", version, error);
        return;
    }
    
    LogToFile(logFile, "[Migrations] Schema version set to %d", version);
    g_CurrentSchemaVersion = version;
    
    // Check if we're done with all migrations
    if (version >= HUB_SCHEMA_VERSION)
    {
        g_MigrationsComplete = true;
        Migrations_OnComplete();
    }
}

/**
 * Called when a migration fails.
 */
public void OnMigrationFailed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogToFile(logFile, "[Migrations] Migration V%d FAILED at query %d: %s", data, failIndex, error);
    SetFailState("[Migrations] Migration failed! Database may be in inconsistent state. Error: %s", error);
}

/**
 * Called when all migrations are complete.
 */
void Migrations_OnComplete()
{
    LogToFile(logFile, "[Migrations] All migrations complete. Schema version: %d", g_CurrentSchemaVersion);
    
    // Load shop categories and items first (global data)
    CoreOnMigrationsComplete();
    
    // Bootstrap all connected players after migrations
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            CoreBootstrapClient(i);
            ShopBootstrapClient(i);
            CreditsBootstrapClient(i);
        }
    }
}

/**
 * Check if migrations are complete.
 */
bool Migrations_IsComplete()
{
    return g_MigrationsComplete;
}

/**
 * Get current schema version.
 */
int Migrations_GetCurrentVersion()
{
    return g_CurrentSchemaVersion;
}
