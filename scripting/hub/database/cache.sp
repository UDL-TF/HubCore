/**
 * HubCore Player Cache System
 * 
 * In-memory caching to reduce database load.
 * Uses JSON objects for flexible data storage.
 */

#include <json>

// Cache sync settings
#define CACHE_SYNC_INTERVAL     30.0    // Sync dirty cache every 30 seconds
#define CACHE_WRITE_DELAY       5.0     // Batch writes every 5 seconds

// Cache state
Handle g_CacheSyncTimer = INVALID_HANDLE;

/**
 * Player cache data structure.
 */
enum struct PlayerCacheData
{
    char steamID[32];
    char steamID64[24];
    char name[MAX_NAME_LENGTH];
    char ip[45];
    int credits;
    int playTimeSeconds;
    float joinTime;         // GetGameTime() when player joined
    bool isDirty;           // Needs to be written to DB
    float lastSync;         // Last time synced with DB
    bool isLoaded;          // Data has been loaded from DB
    JSON_Object settings;   // Player preferences
    JSON_Object cosmetics;  // Active cosmetic selections
    JSON_Object metadata;   // Extensible data
}

PlayerCacheData PlayerCache[MAXPLAYERS + 1];

/**
 * Initialize the cache system.
 */
void Cache_Init()
{
    // Create periodic sync timer
    if (g_CacheSyncTimer != INVALID_HANDLE)
    {
        delete g_CacheSyncTimer;
    }
    g_CacheSyncTimer = CreateTimer(CACHE_SYNC_INTERVAL, Timer_CacheSync, _, TIMER_REPEAT);
    
    // Initialize all player caches
    for (int i = 1; i <= MaxClients; i++)
    {
        Cache_InitPlayer(i);
    }
}

/**
 * Initialize cache for a specific player.
 * 
 * @param client  Client index
 */
void Cache_InitPlayer(int client)
{
    // Clear any existing data
    Cache_ClearPlayer(client);
    
    PlayerCache[client].steamID[0] = '\0';
    PlayerCache[client].steamID64[0] = '\0';
    PlayerCache[client].name[0] = '\0';
    PlayerCache[client].ip[0] = '\0';
    PlayerCache[client].credits = 0;
    PlayerCache[client].playTimeSeconds = 0;
    PlayerCache[client].joinTime = 0.0;
    PlayerCache[client].isDirty = false;
    PlayerCache[client].lastSync = 0.0;
    PlayerCache[client].isLoaded = false;
    PlayerCache[client].settings = new JSON_Object();
    PlayerCache[client].cosmetics = new JSON_Object();
    PlayerCache[client].metadata = new JSON_Object();
}

/**
 * Load player data from database into cache.
 * 
 * @param client  Client index
 */
void Cache_LoadPlayer(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    char steamId[32];
    GetSteamId(client, steamId, sizeof(steamId));
    
    // Store basic info immediately
    PlayerCache[client].joinTime = GetGameTime();
    strcopy(PlayerCache[client].steamID, sizeof(PlayerCache[].steamID), steamId);
    
    // Get SteamID64
    char steamId64[24];
    GetClientAuthId(client, AuthId_SteamID64, steamId64, sizeof(steamId64));
    strcopy(PlayerCache[client].steamID64, sizeof(PlayerCache[].steamID64), steamId64);
    
    // Get name and IP
    char name[MAX_NAME_LENGTH], ip[45];
    GetClientName(client, name, sizeof(name));
    GetClientIP(client, ip, sizeof(ip));
    strcopy(PlayerCache[client].name, sizeof(PlayerCache[].name), name);
    strcopy(PlayerCache[client].ip, sizeof(PlayerCache[].ip), ip);
    
    // Load from database
    HubDB.GetPlayer(steamId, OnCachePlayerLoaded, GetClientUserId(client));
}

/**
 * Callback when player data is loaded from database.
 */
public void OnCachePlayerLoaded(Database db, DBResultSet results, const char[] error, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client == 0)
    {
        return;
    }
    
    if (results == null)
    {
        LogToFile(logFile, "[Cache] Failed to load player data: %s", error);
        PlayerCache[client].isLoaded = true; // Mark as loaded anyway to prevent loops
        return;
    }
    
    if (results.FetchRow())
    {
        // Player exists, load their data
        PlayerCache[client].credits = results.FetchInt(5);  // credits column
        PlayerCache[client].playTimeSeconds = results.FetchInt(8);  // play_time_seconds
        
        // Load settings JSON
        char settingsJson[1024];
        if (!results.IsFieldNull(9))  // settings column
        {
            results.FetchString(9, settingsJson, sizeof(settingsJson));
            if (strlen(settingsJson) > 2)  // More than just "{}"
            {
                // Clean up old object first
                if (PlayerCache[client].settings != null)
                {
                    json_cleanup_and_delete(PlayerCache[client].settings);
                }
                PlayerCache[client].settings = json_decode(settingsJson);
                if (PlayerCache[client].settings == null)
                {
                    PlayerCache[client].settings = new JSON_Object();
                }
            }
        }
        
        // Load cosmetics JSON
        char cosmeticsJson[2048];
        if (!results.IsFieldNull(10))  // cosmetics column
        {
            results.FetchString(10, cosmeticsJson, sizeof(cosmeticsJson));
            if (strlen(cosmeticsJson) > 2)
            {
                if (PlayerCache[client].cosmetics != null)
                {
                    json_cleanup_and_delete(PlayerCache[client].cosmetics);
                }
                PlayerCache[client].cosmetics = json_decode(cosmeticsJson);
                if (PlayerCache[client].cosmetics == null)
                {
                    PlayerCache[client].cosmetics = new JSON_Object();
                }
            }
        }
        
        // Load metadata JSON
        char metadataJson[1024];
        if (!results.IsFieldNull(11))  // metadata column
        {
            results.FetchString(11, metadataJson, sizeof(metadataJson));
            if (strlen(metadataJson) > 2)
            {
                if (PlayerCache[client].metadata != null)
                {
                    json_cleanup_and_delete(PlayerCache[client].metadata);
                }
                PlayerCache[client].metadata = json_decode(metadataJson);
                if (PlayerCache[client].metadata == null)
                {
                    PlayerCache[client].metadata = new JSON_Object();
                }
            }
        }
        
        PlayerCache[client].isLoaded = true;
        PlayerCache[client].lastSync = GetGameTime();
        
        LogToFile(logFile, "[Cache] Loaded player %s with %d credits", 
            PlayerCache[client].steamID, PlayerCache[client].credits);
        
        // Load selections from player_selections table (source of truth)
        // This will populate the cosmetics cache and then apply them
        HubDB.GetAllSelections(PlayerCache[client].steamID, OnSelectionsLoaded, GetClientUserId(client));
    }
    else
    {
        // New player, create record
        LogToFile(logFile, "[Cache] Creating new player record for %s", PlayerCache[client].steamID);
        
        HubDB.UpsertPlayer(
            PlayerCache[client].steamID,
            PlayerCache[client].steamID64,
            PlayerCache[client].name,
            PlayerCache[client].ip,
            OnCachePlayerCreated,
            GetClientUserId(client)
        );
    }
}

/**
 * Callback when new player record is created.
 */
public void OnCachePlayerCreated(Database db, DBResultSet results, const char[] error, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client == 0)
    {
        return;
    }
    
    if (results == null)
    {
        LogToFile(logFile, "[Cache] Failed to create player record: %s", error);
    }
    else
    {
        LogToFile(logFile, "[Cache] Created player record for %s", PlayerCache[client].steamID);
    }
    
    PlayerCache[client].isLoaded = true;
    PlayerCache[client].lastSync = GetGameTime();
    
    // New players have no selections, so just fire the loaded events
    Selections_OnPlayerLoaded(client);
    Chat_Colors_LoadFromCache(client);
    Tags_ApplySelection(client);
    Cosmetics_OnPlayerLoaded(client);
}

/**
 * Callback when player selections are loaded from player_selections table.
 */
public void OnSelectionsLoaded(Database db, DBResultSet results, const char[] error, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client == 0)
    {
        return;
    }
    
    if (results == null)
    {
        LogToFile(logFile, "[Cache] Failed to load selections: %s", error);
        // Still apply cosmetics from cache as fallback
        Selections_OnPlayerLoaded(client);
        Chat_Colors_LoadFromCache(client);
        Tags_ApplySelection(client);
        Cosmetics_OnPlayerLoaded(client);
        return;
    }
    
    // Populate cosmetics cache from player_selections table
    while (results.FetchRow())
    {
        char selectionType[32], selectionValue[255], extraData[1024];
        
        results.FetchString(0, selectionType, sizeof(selectionType));
        results.FetchString(1, selectionValue, sizeof(selectionValue));
        
        if (!results.IsFieldNull(2))
        {
            results.FetchString(2, extraData, sizeof(extraData));
        }
        else
        {
            strcopy(extraData, sizeof(extraData), "{}");
        }
        
        // Parse extra_data JSON and store in cosmetics cache
        JSON_Object selectionData = json_decode(extraData);
        if (selectionData == null)
        {
            selectionData = new JSON_Object();
            selectionData.SetString("value", selectionValue);
        }
        
        // Ensure the selection has a value/name field
        if (!selectionData.HasKey("value") && !selectionData.HasKey("name"))
        {
            selectionData.SetString("value", selectionValue);
        }
        
        // Store in cosmetics cache
        Cache_SetCosmetic(client, selectionType, selectionData);
        
        LogToFile(logFile, "[Cache] Loaded selection %s = %s for %s", selectionType, selectionValue, PlayerCache[client].steamID);
    }
    
    // Now apply the loaded selections
    Selections_OnPlayerLoaded(client);
    Chat_Colors_LoadFromCache(client);
    Tags_ApplySelection(client);
    Cosmetics_OnPlayerLoaded(client);
}

/**
 * Get player credits from cache.
 * 
 * @param client  Client index
 * @return        Player's credit balance
 */
int Cache_GetCredits(int client)
{
    if (!IsValidPlayer(client))
    {
        return 0;
    }
    
    return PlayerCache[client].credits;
}

/**
 * Set player credits in cache (marks as dirty).
 * 
 * @param client   Client index
 * @param credits  New credit amount
 */
void Cache_SetCredits(int client, int credits)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    PlayerCache[client].credits = credits;
    PlayerCache[client].isDirty = true;
}

/**
 * Add credits to player's cache.
 * 
 * @param client  Client index
 * @param amount  Amount to add
 * @return        New credit balance
 */
int Cache_AddCredits(int client, int amount)
{
    if (!IsValidPlayer(client))
    {
        return 0;
    }
    
    PlayerCache[client].credits += amount;
    PlayerCache[client].isDirty = true;
    return PlayerCache[client].credits;
}

/**
 * Remove credits from player's cache.
 * 
 * @param client  Client index
 * @param amount  Amount to remove
 * @return        New credit balance
 */
int Cache_RemoveCredits(int client, int amount)
{
    if (!IsValidPlayer(client))
    {
        return 0;
    }
    
    PlayerCache[client].credits -= amount;
    if (PlayerCache[client].credits < 0)
    {
        PlayerCache[client].credits = 0;
    }
    PlayerCache[client].isDirty = true;
    return PlayerCache[client].credits;
}

/**
 * Check if player cache is loaded.
 * 
 * @param client  Client index
 * @return        True if loaded
 */
bool Cache_IsLoaded(int client)
{
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    return PlayerCache[client].isLoaded;
}

/**
 * Get a setting value from cache.
 * 
 * @param client   Client index
 * @param key      Setting key
 * @param value    Buffer for value
 * @param maxlen   Buffer size
 * @return         True if setting exists
 */
bool Cache_GetSetting(int client, const char[] key, char[] value, int maxlen)
{
    if (!IsValidPlayer(client) || PlayerCache[client].settings == null)
    {
        value[0] = '\0';
        return false;
    }
    
    if (!PlayerCache[client].settings.HasKey(key))
    {
        value[0] = '\0';
        return false;
    }
    
    PlayerCache[client].settings.GetString(key, value, maxlen);
    return true;
}

/**
 * Get a boolean setting from cache.
 * 
 * @param client        Client index
 * @param key           Setting key
 * @param defaultValue  Default value if not found
 * @return              Setting value
 */
bool Cache_GetSettingBool(int client, const char[] key, bool defaultValue = false)
{
    if (!IsValidPlayer(client) || PlayerCache[client].settings == null)
    {
        return defaultValue;
    }
    
    if (!PlayerCache[client].settings.HasKey(key))
    {
        return defaultValue;
    }
    
    return PlayerCache[client].settings.GetBool(key);
}

/**
 * Get an integer setting from cache.
 * 
 * @param client        Client index
 * @param key           Setting key
 * @param defaultValue  Default value if not found
 * @return              Setting value
 */
int Cache_GetSettingInt(int client, const char[] key, int defaultValue = 0)
{
    if (!IsValidPlayer(client) || PlayerCache[client].settings == null)
    {
        return defaultValue;
    }
    
    if (!PlayerCache[client].settings.HasKey(key))
    {
        return defaultValue;
    }
    
    return PlayerCache[client].settings.GetInt(key);
}

/**
 * Set a string setting in cache.
 * 
 * @param client  Client index
 * @param key     Setting key
 * @param value   Setting value
 */
void Cache_SetSetting(int client, const char[] key, const char[] value)
{
    if (!IsValidPlayer(client) || PlayerCache[client].settings == null)
    {
        return;
    }
    
    PlayerCache[client].settings.SetString(key, value);
    PlayerCache[client].isDirty = true;
}

/**
 * Set a boolean setting in cache.
 * 
 * @param client  Client index
 * @param key     Setting key
 * @param value   Setting value
 */
void Cache_SetSettingBool(int client, const char[] key, bool value)
{
    if (!IsValidPlayer(client) || PlayerCache[client].settings == null)
    {
        return;
    }
    
    PlayerCache[client].settings.SetBool(key, value);
    PlayerCache[client].isDirty = true;
}

/**
 * Set an integer setting in cache.
 * 
 * @param client  Client index
 * @param key     Setting key
 * @param value   Setting value
 */
void Cache_SetSettingInt(int client, const char[] key, int value)
{
    if (!IsValidPlayer(client) || PlayerCache[client].settings == null)
    {
        return;
    }
    
    PlayerCache[client].settings.SetInt(key, value);
    PlayerCache[client].isDirty = true;
}

/**
 * Get a cosmetic object from cache.
 * 
 * @param client  Client index
 * @param type    Cosmetic type (e.g., "tag", "trail")
 * @return        JSON_Object for the cosmetic, or null if not set
 */
JSON_Object Cache_GetCosmetic(int client, const char[] type)
{
    if (!IsValidPlayer(client) || PlayerCache[client].cosmetics == null)
    {
        return null;
    }
    
    if (!PlayerCache[client].cosmetics.HasKey(type))
    {
        return null;
    }
    
    return PlayerCache[client].cosmetics.GetObject(type);
}

/**
 * Set a cosmetic object in cache.
 * 
 * @param client  Client index
 * @param type    Cosmetic type
 * @param data    JSON_Object with cosmetic data (ownership is transferred)
 */
void Cache_SetCosmetic(int client, const char[] type, JSON_Object data)
{
    if (!IsValidPlayer(client) || PlayerCache[client].cosmetics == null)
    {
        return;
    }
    
    // Remove old cosmetic object if exists
    if (PlayerCache[client].cosmetics.HasKey(type))
    {
        JSON_Object old = PlayerCache[client].cosmetics.GetObject(type);
        if (old != null)
        {
            json_cleanup_and_delete(old);
        }
    }
    
    PlayerCache[client].cosmetics.SetObject(type, data);
    PlayerCache[client].isDirty = true;
}

/**
 * Clear a cosmetic from cache.
 * 
 * @param client  Client index
 * @param type    Cosmetic type to clear
 */
void Cache_ClearCosmetic(int client, const char[] type)
{
    if (!IsValidPlayer(client) || PlayerCache[client].cosmetics == null)
    {
        return;
    }
    
    if (PlayerCache[client].cosmetics.HasKey(type))
    {
        JSON_Object old = PlayerCache[client].cosmetics.GetObject(type);
        if (old != null)
        {
            json_cleanup_and_delete(old);
        }
        PlayerCache[client].cosmetics.Remove(type);
        PlayerCache[client].isDirty = true;
    }
}

/**
 * Get player's SteamID from cache.
 * 
 * @param client  Client index
 * @param buffer  Buffer to store SteamID
 * @param maxlen  Buffer size
 */
void Cache_GetSteamID(int client, char[] buffer, int maxlen)
{
    if (!IsValidPlayer(client))
    {
        buffer[0] = '\0';
        return;
    }
    
    strcopy(buffer, maxlen, PlayerCache[client].steamID);
}

/**
 * Flush player cache to database.
 * 
 * @param client  Client index
 */
void Cache_FlushPlayer(int client)
{
    if (!IsValidPlayer(client) || !PlayerCache[client].isDirty)
    {
        return;
    }
    
    if (PlayerCache[client].steamID[0] == '\0')
    {
        return;
    }
    
    // Encode JSON objects to strings
    char settingsJson[1024], cosmeticsJson[2048];
    
    if (PlayerCache[client].settings != null)
    {
        int size = json_encode_size(PlayerCache[client].settings);
        if (size > 0 && size < sizeof(settingsJson))
        {
            json_encode(PlayerCache[client].settings, settingsJson, sizeof(settingsJson));
        }
        else
        {
            strcopy(settingsJson, sizeof(settingsJson), "{}");
        }
    }
    else
    {
        strcopy(settingsJson, sizeof(settingsJson), "{}");
    }
    
    if (PlayerCache[client].cosmetics != null)
    {
        int size = json_encode_size(PlayerCache[client].cosmetics);
        if (size > 0 && size < sizeof(cosmeticsJson))
        {
            json_encode(PlayerCache[client].cosmetics, cosmeticsJson, sizeof(cosmeticsJson));
        }
        else
        {
            strcopy(cosmeticsJson, sizeof(cosmeticsJson), "{}");
        }
    }
    else
    {
        strcopy(cosmeticsJson, sizeof(cosmeticsJson), "{}");
    }
    
    // Calculate session play time
    int sessionTime = 0;
    if (PlayerCache[client].joinTime > 0.0)
    {
        sessionTime = RoundToFloor(GetGameTime() - PlayerCache[client].joinTime);
    }
    
    // Update database with a transaction
    Transaction txn = new Transaction();
    char query[8192];
    char escapedSettings[2048], escapedCosmetics[4096], escapedSteamID[64];
    
    DB.Escape(settingsJson, escapedSettings, sizeof(escapedSettings));
    DB.Escape(cosmeticsJson, escapedCosmetics, sizeof(escapedCosmetics));
    DB.Escape(PlayerCache[client].steamID, escapedSteamID, sizeof(escapedSteamID));
    
    // Update credits and JSON columns
    Format(query, sizeof(query),
        "UPDATE `%splayers_v2` SET `credits` = %d, `settings` = '%s', `cosmetics` = '%s', `play_time_seconds` = `play_time_seconds` + %d WHERE `steamid` = '%s';",
        databasePrefix,
        PlayerCache[client].credits,
        escapedSettings,
        escapedCosmetics,
        sessionTime,
        escapedSteamID);
    
    txn.AddQuery(query);
    
    DB.Execute(txn, OnCacheFlushSuccess, OnCacheFlushFailed, GetClientUserId(client));
    
    PlayerCache[client].isDirty = false;
    PlayerCache[client].lastSync = GetGameTime();
    PlayerCache[client].joinTime = GetGameTime();  // Reset for next session calculation
}

/**
 * Callback when cache flush succeeds.
 */
public void OnCacheFlushSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    int client = GetClientOfUserId(data);
    if (client > 0)
    {
        LogToFile(logFile, "[Cache] Flushed cache for %s", PlayerCache[client].steamID);
    }
}

/**
 * Callback when cache flush fails.
 */
public void OnCacheFlushFailed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    int client = GetClientOfUserId(data);
    char steamId[32] = "unknown";
    if (client > 0)
    {
        strcopy(steamId, sizeof(steamId), PlayerCache[client].steamID);
    }
    LogToFile(logFile, "[Cache] CRITICAL: Failed to flush cache for %s (query %d/%d): %s", steamId, failIndex + 1, numQueries, error);
}

/**
 * Clear player cache and cleanup JSON objects.
 * 
 * @param client  Client index
 */
void Cache_ClearPlayer(int client)
{
    // Flush any dirty data first
    if (PlayerCache[client].isDirty && PlayerCache[client].steamID[0] != '\0')
    {
        Cache_FlushPlayer(client);
    }
    
    // Cleanup JSON objects to prevent memory leaks
    if (PlayerCache[client].settings != null)
    {
        json_cleanup_and_delete(PlayerCache[client].settings);
        PlayerCache[client].settings = null;
    }
    if (PlayerCache[client].cosmetics != null)
    {
        json_cleanup_and_delete(PlayerCache[client].cosmetics);
        PlayerCache[client].cosmetics = null;
    }
    if (PlayerCache[client].metadata != null)
    {
        json_cleanup_and_delete(PlayerCache[client].metadata);
        PlayerCache[client].metadata = null;
    }
    
    // Reset all fields
    PlayerCache[client].steamID[0] = '\0';
    PlayerCache[client].steamID64[0] = '\0';
    PlayerCache[client].name[0] = '\0';
    PlayerCache[client].ip[0] = '\0';
    PlayerCache[client].credits = 0;
    PlayerCache[client].playTimeSeconds = 0;
    PlayerCache[client].joinTime = 0.0;
    PlayerCache[client].isDirty = false;
    PlayerCache[client].lastSync = 0.0;
    PlayerCache[client].isLoaded = false;
}

/**
 * Timer callback for periodic cache sync.
 */
public Action Timer_CacheSync(Handle timer)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && PlayerCache[i].isDirty)
        {
            Cache_FlushPlayer(i);
        }
    }
    
    return Plugin_Continue;
}

/**
 * Shutdown the cache system.
 */
void Cache_Shutdown()
{
    // Stop sync timer
    if (g_CacheSyncTimer != INVALID_HANDLE)
    {
        delete g_CacheSyncTimer;
        g_CacheSyncTimer = INVALID_HANDLE;
    }
    
    // Flush all caches
    for (int i = 1; i <= MaxClients; i++)
    {
        if (PlayerCache[i].isDirty)
        {
            Cache_FlushPlayer(i);
        }
        Cache_ClearPlayer(i);
    }
}
