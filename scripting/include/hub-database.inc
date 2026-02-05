/**
 * HubCore Database Include
 * 
 * Provides the HubDB methodmap and database-related definitions.
 * Include this file for database operations in external plugins.
 */

#if defined _hub_database_included
 #endinput
#endif
#define _hub_database_included

// Selection type constants
#define SELECTION_TAG              "tag"
#define SELECTION_TRAIL            "trail"
#define SELECTION_FOOTPRINT        "footprint"
#define SELECTION_SPAWN_PARTICLE   "spawn_particle"
#define SELECTION_TAG_COLOR        "tag_color"
#define SELECTION_NAME_COLOR       "name_color"
#define SELECTION_CHAT_COLOR       "chat_color"

// Cosmetic type constants (for hub_cosmetics table)
#define COSMETIC_TYPE_TAG          "tag"
#define COSMETIC_TYPE_TRAIL        "trail"
#define COSMETIC_TYPE_FOOTPRINT    "footprint"
#define COSMETIC_TYPE_PARTICLE     "spawn_particle"
#define COSMETIC_TYPE_NAME_COLOR   "name_color"
#define COSMETIC_TYPE_CHAT_COLOR   "chat_color"

// Item type constants (for shop items)
#define ITEM_TYPE_TAG              "tag"
#define ITEM_TYPE_TRAIL            "trail"
#define ITEM_TYPE_FOOTPRINT        "footprint"
#define ITEM_TYPE_PARTICLE         "spawn_particle"
#define ITEM_TYPE_NAME_COLOR       "name_color"
#define ITEM_TYPE_CHAT_COLOR       "chat_color"
#define ITEM_TYPE_TAG_COLOR        "tag_color"
#define ITEM_TYPE_CONSUMABLE       "consumable"
#define ITEM_TYPE_CREDITS          "credits"

// Timer type constants
#define TIMER_TYPE_DAILY           "daily"
#define TIMER_TYPE_WEEKLY          "weekly"
#define TIMER_TYPE_MONTHLY         "monthly"

/**
 * Check if migrations are complete.
 * 
 * @return  True if all database migrations have completed.
 */
native bool Hub_IsDatabaseReady();

/**
 * Get the current schema version.
 * 
 * @return  Current database schema version number.
 */
native int Hub_GetSchemaVersion();

/**
 * Get a player's selection value.
 * 
 * @param client        Client index
 * @param selectionType Selection type constant (SELECTION_*)
 * @param buffer        Buffer to store selection value
 * @param maxlen        Maximum buffer length
 * @return              True if selection exists, false otherwise
 */
native bool Hub_GetPlayerSelection(int client, const char[] selectionType, char[] buffer, int maxlen);

/**
 * Set a player's selection value.
 * 
 * @param client        Client index
 * @param selectionType Selection type constant (SELECTION_*)
 * @param value         Selection value
 * @param extraData     Optional JSON extra data
 * @return              True on success, false on failure
 */
native bool Hub_SetPlayerSelection(int client, const char[] selectionType, const char[] value, const char[] extraData = "{}");

/**
 * Clear a player's selection.
 * 
 * @param client        Client index
 * @param selectionType Selection type constant (SELECTION_*)
 * @return              True on success, false on failure
 */
native bool Hub_ClearPlayerSelection(int client, const char[] selectionType);

/**
 * Get a player's setting value (boolean).
 * 
 * @param client       Client index
 * @param settingKey   Setting key name
 * @param defaultValue Default value if setting doesn't exist
 * @return             Setting value
 */
native bool Hub_GetPlayerSettingBool(int client, const char[] settingKey, bool defaultValue = false);

/**
 * Set a player's setting value (boolean).
 * 
 * @param client      Client index
 * @param settingKey  Setting key name
 * @param value       Setting value
 */
native void Hub_SetPlayerSettingBool(int client, const char[] settingKey, bool value);

/**
 * Get a player's setting value (integer).
 * 
 * @param client       Client index
 * @param settingKey   Setting key name
 * @param defaultValue Default value if setting doesn't exist
 * @return             Setting value
 */
native int Hub_GetPlayerSettingInt(int client, const char[] settingKey, int defaultValue = 0);

/**
 * Set a player's setting value (integer).
 * 
 * @param client      Client index
 * @param settingKey  Setting key name
 * @param value       Setting value
 */
native void Hub_SetPlayerSettingInt(int client, const char[] settingKey, int value);

/**
 * Get a player's setting value (string).
 * 
 * @param client       Client index
 * @param settingKey   Setting key name
 * @param buffer       Buffer to store value
 * @param maxlen       Maximum buffer length
 * @param defaultValue Default value if setting doesn't exist
 * @return             True if setting exists
 */
native bool Hub_GetPlayerSettingString(int client, const char[] settingKey, char[] buffer, int maxlen, const char[] defaultValue = "");

/**
 * Set a player's setting value (string).
 * 
 * @param client      Client index
 * @param settingKey  Setting key name
 * @param value       Setting value
 */
native void Hub_SetPlayerSettingString(int client, const char[] settingKey, const char[] value);

/**
 * Called when the database is ready (migrations complete).
 * Use this forward to delay operations that require database access.
 */
forward void Hub_OnDatabaseReady();

/**
 * Called when player data is fully loaded from the database.
 * 
 * @param client  Client index
 */
forward void Hub_OnPlayerDataLoaded(int client);

/**
 * Called when player data is about to be saved (disconnect/flush).
 * 
 * @param client  Client index
 */
forward void Hub_OnPlayerDataSaving(int client);
