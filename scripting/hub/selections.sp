/**
 * HubCore Selections Manager
 * 
 * Manages player cosmetic selections using the JSON cosmetics column in cache.
 * This replaces the cookie-based cosmetic storage system.
 */

// Forward handles
Handle g_hOnSelectionChanged = INVALID_HANDLE;
Handle g_hOnSelectionsLoaded = INVALID_HANDLE;

/**
 * Initialize the selections system.
 */
void Selections_Init()
{
    // Create forwards
    g_hOnSelectionChanged = CreateGlobalForward(
        "Selections_OnPlayerSelectionChanged",
        ET_Ignore,
        Param_Cell,       // client
        Param_String,     // selectionType
        Param_String,     // oldValue
        Param_String      // newValue
    );
    
    g_hOnSelectionsLoaded = CreateGlobalForward(
        "Selections_OnPlayerSelectionsLoaded",
        ET_Ignore,
        Param_Cell        // client
    );
}

/**
 * Register natives for the selections system.
 */
void Selections_RegisterNatives()
{
    CreateNative("Selections_GetPlayer", Native_Selections_GetPlayer);
    CreateNative("Selections_SetPlayer", Native_Selections_SetPlayer);
    CreateNative("Selections_ClearPlayer", Native_Selections_ClearPlayer);
    CreateNative("Selections_HasPlayer", Native_Selections_HasPlayer);
    CreateNative("Selections_GetPlayerInt", Native_Selections_GetPlayerInt);
    CreateNative("Selections_GetPlayerString", Native_Selections_GetPlayerString);
    CreateNative("Selections_GetPlayerBool", Native_Selections_GetPlayerBool);
    CreateNative("Selections_GetPlayerFloat", Native_Selections_GetPlayerFloat);
}

/**
 * Called when player data is loaded - fire the forward.
 * 
 * @param client  Client index
 */
void Selections_OnPlayerLoaded(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    // Fire the forward
    Call_StartForward(g_hOnSelectionsLoaded);
    Call_PushCell(client);
    Call_Finish();
}

/**
 * Get a player's selection as a JSON object.
 * Returns a COPY of the selection data - caller must clean up.
 * 
 * @param client         Client index
 * @param selectionType  Selection type (e.g., "tag", "trail")
 * @return               JSON_Object with selection data, or null if not set
 */
JSON_Object Selections_Get(int client, const char[] selectionType)
{
    if (!IsValidPlayer(client))
    {
        return null;
    }
    
    JSON_Object cosmetic = Cache_GetCosmetic(client, selectionType);
    if (cosmetic == null)
    {
        return null;
    }
    
    // Return a clone to prevent memory issues
    int size = json_encode_size(cosmetic);
    if (size <= 2)
    {
        return null;
    }
    
    char[] buffer = new char[size];
    json_encode(cosmetic, buffer, size);
    
    return json_decode(buffer);
}

/**
 * Set a player's selection from a JSON object.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 * @param data           JSON_Object with selection data (ownership transferred)
 * @return               True on success
 */
bool Selections_Set(int client, const char[] selectionType, JSON_Object data)
{
    if (!IsValidPlayer(client) || data == null)
    {
        return false;
    }
    
    // Get old value for forward
    char oldValue[256] = "";
    JSON_Object oldCosmetic = Cache_GetCosmetic(client, selectionType);
    if (oldCosmetic != null && oldCosmetic.HasKey("value"))
    {
        oldCosmetic.GetString("value", oldValue, sizeof(oldValue));
    }
    
    // Get new value for forward and audit
    char newValue[256] = "";
    if (data.HasKey("value"))
    {
        data.GetString("value", newValue, sizeof(newValue));
    }
    else if (data.HasKey("name"))
    {
        data.GetString("name", newValue, sizeof(newValue));
    }
    else if (data.HasKey("id"))
    {
        IntToString(data.GetInt("id"), newValue, sizeof(newValue));
    }
    
    // Store in cache
    Cache_SetCosmetic(client, selectionType, data);
    
    // Also store in player_selections table for quick lookups
    char steamId[32];
    GetSteamId(client, steamId, sizeof(steamId));
    
    // Encode extra data
    int size = json_encode_size(data);
    char[] extraData = new char[size];
    json_encode(data, extraData, size);
    
    HubDB.SetSelection(steamId, selectionType, newValue, extraData);
    
    // Audit log
    Audit_LogCosmeticChange(client, selectionType, oldValue, newValue);
    
    // Fire forward
    Call_StartForward(g_hOnSelectionChanged);
    Call_PushCell(client);
    Call_PushString(selectionType);
    Call_PushString(oldValue);
    Call_PushString(newValue);
    Call_Finish();
    
    return true;
}

/**
 * Clear a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type to clear
 * @return               True on success
 */
bool Selections_Clear(int client, const char[] selectionType)
{
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    // Get old value for forward
    char oldValue[256] = "";
    JSON_Object oldCosmetic = Cache_GetCosmetic(client, selectionType);
    if (oldCosmetic != null && oldCosmetic.HasKey("value"))
    {
        oldCosmetic.GetString("value", oldValue, sizeof(oldValue));
    }
    
    // Clear from cache
    Cache_ClearCosmetic(client, selectionType);
    
    // Clear from database
    char steamId[32];
    GetSteamId(client, steamId, sizeof(steamId));
    HubDB.ClearSelection(steamId, selectionType);
    
    // Audit log
    Audit_LogCosmeticChange(client, selectionType, oldValue, "");
    
    // Fire forward
    Call_StartForward(g_hOnSelectionChanged);
    Call_PushCell(client);
    Call_PushString(selectionType);
    Call_PushString(oldValue);
    Call_PushString("");
    Call_Finish();
    
    return true;
}

/**
 * Check if player has a selection of a specific type.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 * @return               True if selection exists
 */
bool Selections_Has(int client, const char[] selectionType)
{
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    JSON_Object cosmetic = Cache_GetCosmetic(client, selectionType);
    return cosmetic != null;
}

/**
 * Get an integer value from a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 * @param key            Key to get
 * @param defaultValue   Default value
 * @return               Integer value
 */
int Selections_GetInt(int client, const char[] selectionType, const char[] key, int defaultValue = 0)
{
    if (!IsValidPlayer(client))
    {
        return defaultValue;
    }
    
    JSON_Object cosmetic = Cache_GetCosmetic(client, selectionType);
    if (cosmetic == null || !cosmetic.HasKey(key))
    {
        return defaultValue;
    }
    
    return cosmetic.GetInt(key);
}

/**
 * Get a string value from a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 * @param key            Key to get
 * @param buffer         Buffer for value
 * @param maxlen         Buffer size
 * @param defaultValue   Default value
 * @return               True if key exists
 */
bool Selections_GetString(int client, const char[] selectionType, const char[] key, 
                           char[] buffer, int maxlen, const char[] defaultValue = "")
{
    if (!IsValidPlayer(client))
    {
        strcopy(buffer, maxlen, defaultValue);
        return false;
    }
    
    JSON_Object cosmetic = Cache_GetCosmetic(client, selectionType);
    if (cosmetic == null || !cosmetic.HasKey(key))
    {
        strcopy(buffer, maxlen, defaultValue);
        return false;
    }
    
    cosmetic.GetString(key, buffer, maxlen);
    return true;
}

/**
 * Get a boolean value from a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 * @param key            Key to get
 * @param defaultValue   Default value
 * @return               Boolean value
 */
bool Selections_GetBool(int client, const char[] selectionType, const char[] key, bool defaultValue = false)
{
    if (!IsValidPlayer(client))
    {
        return defaultValue;
    }
    
    JSON_Object cosmetic = Cache_GetCosmetic(client, selectionType);
    if (cosmetic == null || !cosmetic.HasKey(key))
    {
        return defaultValue;
    }
    
    return cosmetic.GetBool(key);
}

/**
 * Get a float value from a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 * @param key            Key to get
 * @param defaultValue   Default value
 * @return               Float value
 */
float Selections_GetFloat(int client, const char[] selectionType, const char[] key, float defaultValue = 0.0)
{
    if (!IsValidPlayer(client))
    {
        return defaultValue;
    }
    
    JSON_Object cosmetic = Cache_GetCosmetic(client, selectionType);
    if (cosmetic == null || !cosmetic.HasKey(key))
    {
        return defaultValue;
    }
    
    return cosmetic.GetFloat(key);
}

/* ========================================
 * Native Implementations
 * ======================================== */

public int Native_Selections_GetPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char selectionType[32];
    GetNativeString(2, selectionType, sizeof(selectionType));
    
    JSON_Object result = Selections_Get(client, selectionType);
    
    // Return the handle as a cell
    return view_as<int>(result);
}

public int Native_Selections_SetPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char selectionType[32];
    GetNativeString(2, selectionType, sizeof(selectionType));
    
    JSON_Object data = view_as<JSON_Object>(GetNativeCell(3));
    
    return Selections_Set(client, selectionType, data);
}

public int Native_Selections_ClearPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char selectionType[32];
    GetNativeString(2, selectionType, sizeof(selectionType));
    
    return Selections_Clear(client, selectionType);
}

public int Native_Selections_HasPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char selectionType[32];
    GetNativeString(2, selectionType, sizeof(selectionType));
    
    return Selections_Has(client, selectionType);
}

public int Native_Selections_GetPlayerInt(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char selectionType[32], key[64];
    GetNativeString(2, selectionType, sizeof(selectionType));
    GetNativeString(3, key, sizeof(key));
    int defaultValue = GetNativeCell(4);
    
    return Selections_GetInt(client, selectionType, key, defaultValue);
}

public int Native_Selections_GetPlayerString(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char selectionType[32], key[64], defaultValue[256];
    GetNativeString(2, selectionType, sizeof(selectionType));
    GetNativeString(3, key, sizeof(key));
    int maxlen = GetNativeCell(5);
    GetNativeString(6, defaultValue, sizeof(defaultValue));
    
    char buffer[256];
    bool result = Selections_GetString(client, selectionType, key, buffer, sizeof(buffer), defaultValue);
    
    SetNativeString(4, buffer, maxlen);
    return result;
}

public int Native_Selections_GetPlayerBool(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char selectionType[32], key[64];
    GetNativeString(2, selectionType, sizeof(selectionType));
    GetNativeString(3, key, sizeof(key));
    bool defaultValue = GetNativeCell(4);
    
    return Selections_GetBool(client, selectionType, key, defaultValue);
}

public int Native_Selections_GetPlayerFloat(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char selectionType[32], key[64];
    GetNativeString(2, selectionType, sizeof(selectionType));
    GetNativeString(3, key, sizeof(key));
    float defaultValue = GetNativeCell(4);
    
    return view_as<int>(Selections_GetFloat(client, selectionType, key, defaultValue));
}
