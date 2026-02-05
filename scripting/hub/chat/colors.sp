/**
 * HubCore Chat Colors System
 * 
 * Custom chat colors system - replaces CCC (Custom Chat Colors).
 * Manages player tags, name colors, and chat colors with database storage.
 */

// CCC Compatibility - enum definition for CCC_ColorType
// Note: This is defined here to avoid dependency on ccc.inc in the main plugin
// Plugins that include ccc.inc will use that definition via #if defined guards
#if !defined _ccc_included
enum CCC_ColorType {
    CCC_TagColor,
    CCC_NameColor,
    CCC_ChatColor
};

#define COLOR_NONE      -1
#define COLOR_GREEN     -2
#define COLOR_OLIVE     -3
#define COLOR_TEAM      -4
#endif

// Chat color data for each player
enum struct ChatColorData
{
    char tag[HUB_CHAT_MAX_TAG];
    HubChatColorType tagColorType;
    int tagColor;
    HubChatColorType nameColorType;
    int nameColor;
    HubChatColorType chatColorType;
    int chatColor;
    bool tagEnabled;
    bool loaded;
    
    // Default values
    char defaultTag[HUB_CHAT_MAX_TAG];
    HubChatColorType defaultTagColorType;
    int defaultTagColor;
    HubChatColorType defaultNameColorType;
    int defaultNameColor;
    HubChatColorType defaultChatColorType;
    int defaultChatColor;
}

static ChatColorData g_ChatColors[MAXPLAYERS + 1];

// Forwards
static GlobalForward g_FwdColorsLoaded;
static GlobalForward g_FwdTagChanged;

// Whether the colors system is initialized
static bool g_ColorsInitialized = false;

/**
 * Initialize the chat colors system.
 */
void Chat_Colors_Init()
{
    if (g_ColorsInitialized)
    {
        return;
    }
    
    // Create forwards
    g_FwdColorsLoaded = new GlobalForward("OnClientChatColorsLoaded", ET_Ignore, Param_Cell);
    g_FwdTagChanged = new GlobalForward("OnClientTagChanged", ET_Ignore, Param_Cell, Param_String, Param_String);
    
    // Initialize all player data
    for (int i = 1; i <= MaxClients; i++)
    {
        Chat_Colors_ClearClient(i);
    }
    
    g_ColorsInitialized = true;
    LogMessage("[Hub Chat] Chat colors system initialized");
}

/**
 * Handle client connected.
 */
void Chat_Colors_OnClientConnected(int client)
{
    Chat_Colors_ClearClient(client);
}

/**
 * Handle client disconnect.
 */
void Chat_Colors_OnClientDisconnect(int client)
{
    Chat_Colors_ClearClient(client);
}

/**
 * Clear client chat colors to defaults.
 */
void Chat_Colors_ClearClient(int client)
{
    g_ChatColors[client].tag[0] = '\0';
    g_ChatColors[client].tagColorType = HubChatColor_None;
    g_ChatColors[client].tagColor = 0;
    g_ChatColors[client].nameColorType = HubChatColor_Team;
    g_ChatColors[client].nameColor = 0;
    g_ChatColors[client].chatColorType = HubChatColor_None;
    g_ChatColors[client].chatColor = 0;
    g_ChatColors[client].tagEnabled = true;
    g_ChatColors[client].loaded = false;
    
    // Defaults
    g_ChatColors[client].defaultTag[0] = '\0';
    g_ChatColors[client].defaultTagColorType = HubChatColor_None;
    g_ChatColors[client].defaultTagColor = 0;
    g_ChatColors[client].defaultNameColorType = HubChatColor_Team;
    g_ChatColors[client].defaultNameColor = 0;
    g_ChatColors[client].defaultChatColorType = HubChatColor_None;
    g_ChatColors[client].defaultChatColor = 0;
}

/**
 * Load chat colors from player cache.
 * Called when player data is loaded from database.
 * Supports both legacy format (tag object) and new selections format.
 */
void Chat_Colors_LoadFromCache(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    Chat_Colors_ClearClient(client);
    
    // Get cosmetics JSON from cache
    JSON_Object cosmetics = PlayerCache[client].cosmetics;
    if (cosmetics == null)
    {
        g_ChatColors[client].loaded = true;
        Chat_Colors_FireLoaded(client);
        return;
    }
    
    // Load tag - check both legacy format and new selection format
    if (cosmetics.HasKey("tag"))
    {
        JSON_Object tagObj = cosmetics.GetObject("tag");
        if (tagObj != null)
        {
            // Try new format first (name field from selections)
            if (tagObj.HasKey("name"))
            {
                tagObj.GetString("name", g_ChatColors[client].tag, HUB_CHAT_MAX_TAG);
            }
            // Fall back to legacy format (text field)
            else if (tagObj.HasKey("text"))
            {
                tagObj.GetString("text", g_ChatColors[client].tag, HUB_CHAT_MAX_TAG);
            }
            
            char colorStr[16];
            tagObj.GetString("color", colorStr, sizeof(colorStr));
            if (strlen(colorStr) > 0)
            {
                g_ChatColors[client].tagColorType = HubChat_ParseColorString(colorStr, g_ChatColors[client].tagColor);
            }
            
            g_ChatColors[client].tagEnabled = tagObj.GetBool("enabled", true);
        }
    }
    
    // Load tag color from selection (if saved separately)
    if (cosmetics.HasKey(SELECTION_TAG_COLOR))
    {
        JSON_Object colorObj = cosmetics.GetObject(SELECTION_TAG_COLOR);
        if (colorObj != null)
        {
            char colorStr[16];
            colorObj.GetString("value", colorStr, sizeof(colorStr));
            if (strlen(colorStr) > 0)
            {
                g_ChatColors[client].tagColorType = HubChat_ParseColorString(colorStr, g_ChatColors[client].tagColor);
            }
        }
    }
    
    // Load name color
    if (cosmetics.HasKey("name_color") || cosmetics.HasKey(SELECTION_NAME_COLOR))
    {
        char key[32];
        strcopy(key, sizeof(key), cosmetics.HasKey(SELECTION_NAME_COLOR) ? SELECTION_NAME_COLOR : "name_color");
        
        JSON_Object nameObj = cosmetics.GetObject(key);
        if (nameObj != null)
        {
            char colorStr[16];
            nameObj.GetString("value", colorStr, sizeof(colorStr));
            if (strlen(colorStr) > 0)
            {
                g_ChatColors[client].nameColorType = HubChat_ParseColorString(colorStr, g_ChatColors[client].nameColor);
            }
        }
    }
    
    // Load chat color
    if (cosmetics.HasKey("chat_color") || cosmetics.HasKey(SELECTION_CHAT_COLOR))
    {
        char key[32];
        strcopy(key, sizeof(key), cosmetics.HasKey(SELECTION_CHAT_COLOR) ? SELECTION_CHAT_COLOR : "chat_color");
        
        JSON_Object chatObj = cosmetics.GetObject(key);
        if (chatObj != null)
        {
            char colorStr[16];
            chatObj.GetString("value", colorStr, sizeof(colorStr));
            if (strlen(colorStr) > 0)
            {
                g_ChatColors[client].chatColorType = HubChat_ParseColorString(colorStr, g_ChatColors[client].chatColor);
            }
        }
    }
    
    g_ChatColors[client].loaded = true;
    
    // Fire forward
    Chat_Colors_FireLoaded(client);
}

/**
 * Fire the colors loaded forward.
 */
void Chat_Colors_FireLoaded(int client)
{
    Call_StartForward(g_FwdColorsLoaded);
    Call_PushCell(client);
    Call_Finish();
}

/**
 * Save chat colors to player cache.
 */
void Chat_Colors_SaveToCache(int client)
{
    if (!IsValidPlayer(client) || !PlayerCache[client].isLoaded)
    {
        return;
    }
    
    JSON_Object cosmetics = PlayerCache[client].cosmetics;
    if (cosmetics == null)
    {
        cosmetics = new JSON_Object();
        PlayerCache[client].cosmetics = cosmetics;
    }
    
    // Save tag
    if (strlen(g_ChatColors[client].tag) > 0)
    {
        JSON_Object tagObj;
        if (cosmetics.HasKey("tag"))
        {
            tagObj = cosmetics.GetObject("tag");
        }
        else
        {
            tagObj = new JSON_Object();
        }
        
        tagObj.SetString("text", g_ChatColors[client].tag);
        
        char colorStr[16];
        HubChat_ColorTypeToString(g_ChatColors[client].tagColorType, g_ChatColors[client].tagColor, colorStr, sizeof(colorStr));
        tagObj.SetString("color", colorStr);
        tagObj.SetBool("enabled", g_ChatColors[client].tagEnabled);
        
        cosmetics.SetObject("tag", tagObj);
    }
    else
    {
        cosmetics.Remove("tag");
    }
    
    // Save name color
    if (g_ChatColors[client].nameColorType != HubChatColor_Team)
    {
        JSON_Object nameObj = new JSON_Object();
        char colorStr[16];
        HubChat_ColorTypeToString(g_ChatColors[client].nameColorType, g_ChatColors[client].nameColor, colorStr, sizeof(colorStr));
        nameObj.SetString("value", colorStr);
        cosmetics.SetObject("name_color", nameObj);
    }
    else
    {
        cosmetics.Remove("name_color");
    }
    
    // Save chat color
    if (g_ChatColors[client].chatColorType != HubChatColor_None)
    {
        JSON_Object chatObj = new JSON_Object();
        char colorStr[16];
        HubChat_ColorTypeToString(g_ChatColors[client].chatColorType, g_ChatColors[client].chatColor, colorStr, sizeof(colorStr));
        chatObj.SetString("value", colorStr);
        cosmetics.SetObject("chat_color", chatObj);
    }
    else
    {
        cosmetics.Remove("chat_color");
    }
    
    // Mark cache as dirty
    PlayerCache[client].isDirty = true;
    
    // Also save to player_selections table for consistency
    Chat_Colors_SaveSelections(client);
}

/**
 * Save chat color selections to hub_player_selections table.
 * This ensures selections are persisted even if cache flush fails.
 */
void Chat_Colors_SaveSelections(int client)
{
    if (!IsValidPlayer(client) || !PlayerCache[client].isLoaded)
    {
        return;
    }
    
    char steamId[32];
    GetSteamId(client, steamId, sizeof(steamId));
    
    // Save tag selection
    if (strlen(g_ChatColors[client].tag) > 0)
    {
        JSON_Object tagData = new JSON_Object();
        tagData.SetString("name", g_ChatColors[client].tag);
        tagData.SetBool("enabled", g_ChatColors[client].tagEnabled);
        
        char colorStr[16];
        HubChat_ColorTypeToString(g_ChatColors[client].tagColorType, g_ChatColors[client].tagColor, colorStr, sizeof(colorStr));
        tagData.SetString("color", colorStr);
        
        int size = json_encode_size(tagData);
        char[] extraData = new char[size];
        json_encode(tagData, extraData, size);
        
        HubDB.SetSelection(steamId, SELECTION_TAG, g_ChatColors[client].tag, extraData);
        json_cleanup_and_delete(tagData);
    }
    else
    {
        HubDB.ClearSelection(steamId, SELECTION_TAG);
    }
    
    // Save tag color selection
    if (g_ChatColors[client].tagColorType != HubChatColor_None)
    {
        char colorStr[16];
        HubChat_ColorTypeToString(g_ChatColors[client].tagColorType, g_ChatColors[client].tagColor, colorStr, sizeof(colorStr));
        
        JSON_Object colorData = new JSON_Object();
        colorData.SetString("value", colorStr);
        colorData.SetInt("type", view_as<int>(g_ChatColors[client].tagColorType));
        colorData.SetInt("color", g_ChatColors[client].tagColor);
        
        int size = json_encode_size(colorData);
        char[] extraData = new char[size];
        json_encode(colorData, extraData, size);
        
        HubDB.SetSelection(steamId, SELECTION_TAG_COLOR, colorStr, extraData);
        json_cleanup_and_delete(colorData);
    }
    else
    {
        HubDB.ClearSelection(steamId, SELECTION_TAG_COLOR);
    }
    
    // Save name color selection
    if (g_ChatColors[client].nameColorType != HubChatColor_Team)
    {
        char colorStr[16];
        HubChat_ColorTypeToString(g_ChatColors[client].nameColorType, g_ChatColors[client].nameColor, colorStr, sizeof(colorStr));
        
        JSON_Object colorData = new JSON_Object();
        colorData.SetString("value", colorStr);
        colorData.SetInt("type", view_as<int>(g_ChatColors[client].nameColorType));
        colorData.SetInt("color", g_ChatColors[client].nameColor);
        
        int size = json_encode_size(colorData);
        char[] extraData = new char[size];
        json_encode(colorData, extraData, size);
        
        HubDB.SetSelection(steamId, SELECTION_NAME_COLOR, colorStr, extraData);
        json_cleanup_and_delete(colorData);
    }
    else
    {
        HubDB.ClearSelection(steamId, SELECTION_NAME_COLOR);
    }
    
    // Save chat color selection
    if (g_ChatColors[client].chatColorType != HubChatColor_None)
    {
        char colorStr[16];
        HubChat_ColorTypeToString(g_ChatColors[client].chatColorType, g_ChatColors[client].chatColor, colorStr, sizeof(colorStr));
        
        JSON_Object colorData = new JSON_Object();
        colorData.SetString("value", colorStr);
        colorData.SetInt("type", view_as<int>(g_ChatColors[client].chatColorType));
        colorData.SetInt("color", g_ChatColors[client].chatColor);
        
        int size = json_encode_size(colorData);
        char[] extraData = new char[size];
        json_encode(colorData, extraData, size);
        
        HubDB.SetSelection(steamId, SELECTION_CHAT_COLOR, colorStr, extraData);
        json_cleanup_and_delete(colorData);
    }
    else
    {
        HubDB.ClearSelection(steamId, SELECTION_CHAT_COLOR);
    }
}

/**
 * Apply chat colors to a message.
 * Called by the chat processor before sending.
 */
void Chat_Colors_ApplyToMessage(int author, char[] name, int nameMaxLen, char[] message, int msgMaxLen)
{
    if (!IsValidPlayer(author) || !g_ChatColors[author].loaded)
    {
        return;
    }
    
    char colorCode[16];
    char tempName[HUB_CHAT_MAX_NAME];
    
    // Apply name color
    HubChat_ColorToCode(g_ChatColors[author].nameColorType, g_ChatColors[author].nameColor, colorCode, sizeof(colorCode));
    
    // Apply tag if present and enabled
    if (strlen(g_ChatColors[author].tag) > 0 && g_ChatColors[author].tagEnabled)
    {
        char tagColorCode[16];
        HubChat_ColorToCode(g_ChatColors[author].tagColorType, g_ChatColors[author].tagColor, tagColorCode, sizeof(tagColorCode));
        
        Format(tempName, sizeof(tempName), "%s%s \x01%s%s", 
            tagColorCode, g_ChatColors[author].tag,
            colorCode, name);
    }
    else
    {
        Format(tempName, sizeof(tempName), "%s%s", colorCode, name);
    }
    
    strcopy(name, nameMaxLen, tempName);
    
    // Apply chat color
    if (g_ChatColors[author].chatColorType != HubChatColor_None)
    {
        char chatColorCode[16];
        HubChat_ColorToCode(g_ChatColors[author].chatColorType, g_ChatColors[author].chatColor, chatColorCode, sizeof(chatColorCode));
        
        char tempMsg[HUB_CHAT_MAX_MESSAGE];
        Format(tempMsg, sizeof(tempMsg), "%s%s", chatColorCode, message);
        strcopy(message, msgMaxLen, tempMsg);
    }
}

/**
 * Check if chat colors are loaded for a client.
 */
bool Chat_Colors_IsLoaded(int client)
{
    return g_ChatColors[client].loaded;
}

// ==================== Getter/Setter Functions ====================

void Chat_Colors_GetTag(int client, char[] buffer, int maxlen)
{
    strcopy(buffer, maxlen, g_ChatColors[client].tag);
}

void Chat_Colors_SetTag(int client, const char[] tag)
{
    char oldTag[HUB_CHAT_MAX_TAG];
    strcopy(oldTag, sizeof(oldTag), g_ChatColors[client].tag);
    
    strcopy(g_ChatColors[client].tag, HUB_CHAT_MAX_TAG, tag);
    
    // Fire forward if changed
    if (!StrEqual(oldTag, tag))
    {
        Call_StartForward(g_FwdTagChanged);
        Call_PushCell(client);
        Call_PushString(oldTag);
        Call_PushString(tag);
        Call_Finish();
        
        Chat_Colors_SaveToCache(client);
    }
}

HubChatColorType Chat_Colors_GetTagColor(int client, int &color)
{
    color = g_ChatColors[client].tagColor;
    return g_ChatColors[client].tagColorType;
}

void Chat_Colors_SetTagColor(int client, HubChatColorType type, int color)
{
    g_ChatColors[client].tagColorType = type;
    g_ChatColors[client].tagColor = color;
    Chat_Colors_SaveToCache(client);
}

HubChatColorType Chat_Colors_GetNameColor(int client, int &color)
{
    color = g_ChatColors[client].nameColor;
    return g_ChatColors[client].nameColorType;
}

void Chat_Colors_SetNameColor(int client, HubChatColorType type, int color)
{
    g_ChatColors[client].nameColorType = type;
    g_ChatColors[client].nameColor = color;
    Chat_Colors_SaveToCache(client);
}

HubChatColorType Chat_Colors_GetChatColor(int client, int &color)
{
    color = g_ChatColors[client].chatColor;
    return g_ChatColors[client].chatColorType;
}

void Chat_Colors_SetChatColor(int client, HubChatColorType type, int color)
{
    g_ChatColors[client].chatColorType = type;
    g_ChatColors[client].chatColor = color;
    Chat_Colors_SaveToCache(client);
}

bool Chat_Colors_IsTagEnabled(int client)
{
    return g_ChatColors[client].tagEnabled;
}

void Chat_Colors_SetTagEnabled(int client, bool enabled)
{
    g_ChatColors[client].tagEnabled = enabled;
    Chat_Colors_SaveToCache(client);
}

void Chat_Colors_ResetAll(int client)
{
    g_ChatColors[client].tag[0] = '\0';
    g_ChatColors[client].tagColorType = g_ChatColors[client].defaultTagColorType;
    g_ChatColors[client].tagColor = g_ChatColors[client].defaultTagColor;
    g_ChatColors[client].nameColorType = g_ChatColors[client].defaultNameColorType;
    g_ChatColors[client].nameColor = g_ChatColors[client].defaultNameColor;
    g_ChatColors[client].chatColorType = g_ChatColors[client].defaultChatColorType;
    g_ChatColors[client].chatColor = g_ChatColors[client].defaultChatColor;
    g_ChatColors[client].tagEnabled = true;
    
    Chat_Colors_SaveToCache(client);
}

// ==================== Native Implementations ====================

int Native_HubChat_GetClientTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    SetNativeString(2, g_ChatColors[client].tag, GetNativeCell(3));
    return 0;
}

int Native_HubChat_SetClientTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    char tag[HUB_CHAT_MAX_TAG];
    GetNativeString(2, tag, sizeof(tag));
    Chat_Colors_SetTag(client, tag);
    return 0;
}

int Native_HubChat_GetClientTagColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    SetNativeCellRef(2, g_ChatColors[client].tagColor);
    return view_as<int>(g_ChatColors[client].tagColorType);
}

int Native_HubChat_SetClientTagColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    HubChatColorType type = GetNativeCell(2);
    int color = GetNativeCell(3);
    Chat_Colors_SetTagColor(client, type, color);
    return 0;
}

int Native_HubChat_GetClientNameColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    SetNativeCellRef(2, g_ChatColors[client].nameColor);
    return view_as<int>(g_ChatColors[client].nameColorType);
}

int Native_HubChat_SetClientNameColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    HubChatColorType type = GetNativeCell(2);
    int color = GetNativeCell(3);
    Chat_Colors_SetNameColor(client, type, color);
    return 0;
}

int Native_HubChat_GetClientChatColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    SetNativeCellRef(2, g_ChatColors[client].chatColor);
    return view_as<int>(g_ChatColors[client].chatColorType);
}

int Native_HubChat_SetClientChatColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    HubChatColorType type = GetNativeCell(2);
    int color = GetNativeCell(3);
    Chat_Colors_SetChatColor(client, type, color);
    return 0;
}

int Native_HubChat_ResetClientColors(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    Chat_Colors_ResetAll(client);
    return 0;
}

int Native_HubChat_IsClientTagEnabled(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    return g_ChatColors[client].tagEnabled;
}

int Native_HubChat_SetClientTagEnabled(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client index %d", client);
        return 0;
    }
    
    bool enabled = GetNativeCell(2);
    Chat_Colors_SetTagEnabled(client, enabled);
    return 0;
}

// ==================== CCC Compatibility Natives ====================

/**
 * CCC_GetColor compatibility native.
 */
int Native_CCC_GetColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    CCC_ColorType type = GetNativeCell(2);
    
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
        return COLOR_NONE;
    }
    
    int color;
    HubChatColorType hubType;
    
    switch (type)
    {
        case CCC_TagColor:
            hubType = Chat_Colors_GetTagColor(client, color);
        case CCC_NameColor:
            hubType = Chat_Colors_GetNameColor(client, color);
        case CCC_ChatColor:
            hubType = Chat_Colors_GetChatColor(client, color);
        default:
        {
            SetNativeCellRef(3, false);
            return COLOR_NONE;
        }
    }
    
    // Set alpha reference parameter (param 3) - true if hex color with alpha
    bool hasAlpha = (hubType == HubChatColor_HexAlpha);
    SetNativeCellRef(3, hasAlpha);
    
    // Convert to old CCC format
    switch (hubType)
    {
        case HubChatColor_None: return COLOR_NONE;
        case HubChatColor_Team: return COLOR_TEAM;
        case HubChatColor_Green: return COLOR_GREEN;
        case HubChatColor_Olive: return COLOR_OLIVE;
        default: return color;
    }
}

/**
 * CCC_SetColor compatibility native.
 */
int Native_CCC_SetColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    CCC_ColorType type = GetNativeCell(2);
    int color = GetNativeCell(3);
    bool alpha = GetNativeCell(4);
    
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
        return 0;
    }
    
    HubChatColorType hubType;
    int hubColor = 0;
    
    // Convert from old CCC format
    if (color < 0)
    {
        switch (color)
        {
            case COLOR_NONE: hubType = HubChatColor_None;
            case COLOR_GREEN: hubType = HubChatColor_Green;
            case COLOR_OLIVE: hubType = HubChatColor_Olive;
            case COLOR_TEAM: hubType = HubChatColor_Team;
            default: hubType = HubChatColor_None;
        }
    }
    else
    {
        hubType = alpha ? HubChatColor_HexAlpha : HubChatColor_Hex;
        hubColor = color;
    }
    
    switch (type)
    {
        case CCC_TagColor:
            Chat_Colors_SetTagColor(client, hubType, hubColor);
        case CCC_NameColor:
            Chat_Colors_SetNameColor(client, hubType, hubColor);
        case CCC_ChatColor:
            Chat_Colors_SetChatColor(client, hubType, hubColor);
    }
    
    return 1;
}

/**
 * CCC_GetTag compatibility native.
 */
int Native_CCC_GetTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
        return 0;
    }
    
    SetNativeString(2, g_ChatColors[client].tag, GetNativeCell(3));
    return 0;
}

/**
 * CCC_SetTag compatibility native.
 */
int Native_CCC_SetTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
        return 0;
    }
    
    char tag[HUB_CHAT_MAX_TAG];
    GetNativeString(2, tag, sizeof(tag));
    Chat_Colors_SetTag(client, tag);
    return 0;
}

/**
 * CCC_ResetColor compatibility native.
 */
int Native_CCC_ResetColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    CCC_ColorType type = GetNativeCell(2);
    
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
        return 0;
    }
    
    switch (type)
    {
        case CCC_TagColor:
            Chat_Colors_SetTagColor(client, HubChatColor_None, 0);
        case CCC_NameColor:
            Chat_Colors_SetNameColor(client, HubChatColor_Team, 0);
        case CCC_ChatColor:
            Chat_Colors_SetChatColor(client, HubChatColor_None, 0);
    }
    return 0;
}

/**
 * CCC_ResetTag compatibility native.
 */
int Native_CCC_ResetTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
        return 0;
    }
    
    Chat_Colors_SetTag(client, "");
    return 0;
}

/**
 * Register all CCC compatibility natives.
 */
void Chat_Colors_RegisterCCCCompat()
{
    CreateNative("CCC_GetColor", Native_CCC_GetColor);
    CreateNative("CCC_SetColor", Native_CCC_SetColor);
    CreateNative("CCC_GetTag", Native_CCC_GetTag);
    CreateNative("CCC_SetTag", Native_CCC_SetTag);
    CreateNative("CCC_ResetColor", Native_CCC_ResetColor);
    CreateNative("CCC_ResetTag", Native_CCC_ResetTag);
    
    RegPluginLibrary("ccc");
}

/**
 * Register all Hub chat natives.
 */
void Chat_RegisterNatives()
{
    // Hub natives
    CreateNative("HubChat_GetChatFlags", Native_HubChat_GetChatFlags);
    CreateNative("HubChat_GetClientTag", Native_HubChat_GetClientTag);
    CreateNative("HubChat_SetClientTag", Native_HubChat_SetClientTag);
    CreateNative("HubChat_GetClientTagColor", Native_HubChat_GetClientTagColor);
    CreateNative("HubChat_SetClientTagColor", Native_HubChat_SetClientTagColor);
    CreateNative("HubChat_GetClientNameColor", Native_HubChat_GetClientNameColor);
    CreateNative("HubChat_SetClientNameColor", Native_HubChat_SetClientNameColor);
    CreateNative("HubChat_GetClientChatColor", Native_HubChat_GetClientChatColor);
    CreateNative("HubChat_SetClientChatColor", Native_HubChat_SetClientChatColor);
    CreateNative("HubChat_ResetClientColors", Native_HubChat_ResetClientColors);
    CreateNative("HubChat_IsClientTagEnabled", Native_HubChat_IsClientTagEnabled);
    CreateNative("HubChat_SetClientTagEnabled", Native_HubChat_SetClientTagEnabled);
    
    // CCC compatibility
    Chat_Colors_RegisterCCCCompat();
}
