/**
 * HubCore Tags System
 * 
 * Manages player chat tags with native Hub chat integration.
 * Migrated from CCCM-TagShop functionality.
 */

#include <hub-tags>

// Note: CCC compatibility natives are provided by hub/chat/colors.sp
// This allows the same code to work with both the native Hub chat system
// and legacy CCC plugins.

// Tag data from config
TagInfo g_Tags[TAGS_MAX_COUNT];
int g_TagsCount = 0;

// Player selected tags
int g_SelectedTag[MAXPLAYERS + 1] = { TAGS_NONE, ... };

/**
 * Initialize the tags system.
 */
void Tags_Init()
{
    // Load tags config
    if (!Tags_LoadConfig())
    {
        LogError("[HubCore] Failed to load tags config from %s", TAGS_CONFIG_PATH);
    }
    else
    {
        LogMessage("[HubCore] Loaded %d tags from config", g_TagsCount);
    }
    
    // Register command
    RegConsoleCmd("sm_tags", Command_Tags, "Opens the tags menu");
    
    // Register cosmetic
    Cosmetics_Register(Cosmetic_Tag, "Hub_Cosmetics_Tags", "tags");
    
    LogMessage("[HubCore] Tags system initialized");
}

/**
 * Register tags natives.
 */
void Tags_RegisterNatives()
{
    CreateNative("Tags_GetPlayerTag", Native_Tags_GetPlayerTag);
    CreateNative("Tags_GetPlayerTagColor", Native_Tags_GetPlayerTagColor);
    CreateNative("Tags_SetPlayerTag", Native_Tags_SetPlayerTag);
    CreateNative("Tags_ClearPlayerTag", Native_Tags_ClearPlayerTag);
    CreateNative("Tags_OpenMenu", Native_Tags_OpenMenu);
}

/**
 * Load tags from config file.
 * 
 * @return               True on success
 */
bool Tags_LoadConfig()
{
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, PLATFORM_MAX_PATH, TAGS_CONFIG_PATH);
    
    KeyValues kv = new KeyValues("tags-list");
    
    if (!kv.ImportFromFile(configPath))
    {
        delete kv;
        return false;
    }
    
    if (!kv.GotoFirstSubKey())
    {
        delete kv;
        return false;
    }
    
    g_TagsCount = 0;
    
    do
    {
        if (g_TagsCount >= TAGS_MAX_COUNT)
        {
            LogError("[HubCore] Maximum tags count reached (%d)", TAGS_MAX_COUNT);
            break;
        }
        
        kv.GetString("name", g_Tags[g_TagsCount].name, sizeof(g_Tags[].name), "");
        kv.GetString("color", g_Tags[g_TagsCount].color, sizeof(g_Tags[].color), "FFFFFF");
        g_Tags[g_TagsCount].isEnabled = kv.GetNum("enabled", 1) > 0;
        
        // Parse hex color to int
        g_Tags[g_TagsCount].colorInt = Tags_ParseHexColor(g_Tags[g_TagsCount].color);
        
        g_TagsCount++;
    }
    while (kv.GotoNextKey());
    
    delete kv;
    return true;
}

/**
 * Parse a hex color string to an integer.
 * 
 * @param hexColor       Hex color string (e.g., "FF0000" or "#FF0000")
 * @return               Color as integer
 */
int Tags_ParseHexColor(const char[] hexColor)
{
    char color[16];
    int start = (hexColor[0] == '#') ? 1 : 0;
    int j = 0;
    for (int i = start; hexColor[i] != '\0' && j < sizeof(color) - 1; i++)
    {
        color[j++] = hexColor[i];
    }
    color[j] = '\0';
    
    return StringToInt(color, 16);
}

/**
 * Command handler for /sm_tags
 */
public Action Command_Tags(int client, int args)
{
    if (!IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    ShowTagsMenu(client, 0);
    return Plugin_Handled;
}

/**
 * Show the tags menu.
 * 
 * @param client         Client index
 * @param page           Menu page to display
 */
void ShowTagsMenu(int client, int page)
{
    MenuHistory_Push(client, MenuType_CosmeticsTags, 0);
    
    Menu menu = new Menu(MenuHandler_Tags);
    menu.ExitBackButton = true;
    
    menu.SetTitle("%t", "Hub_Cosmetics_Tags_Title");
    
    // Add "None" option
    char noneInfo[8];
    IntToString(TAGS_NONE, noneInfo, sizeof(noneInfo));
    menu.AddItem(noneInfo, "None", (g_SelectedTag[client] == TAGS_NONE) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    
    // Add available tags
    for (int i = 0; i < g_TagsCount; i++)
    {
        // Skip empty/null tags (spacers)
        if (strlen(g_Tags[i].name) == 0 ||
            StrEqual(g_Tags[i].name, "\\0") ||
            StrEqual(g_Tags[i].name, "{null}", false) ||
            StrEqual(g_Tags[i].name, "{empty}", false))
        {
            menu.AddItem("", "", ITEMDRAW_SPACER);
            continue;
        }
        
        // Skip disabled tags
        if (!g_Tags[i].isEnabled)
        {
            continue;
        }
        
        char info[8];
        IntToString(i, info, sizeof(info));
        
        // Check if player owns this tag
        bool hasItem = Hub_HasPlayerItemName(client, "Tags", g_Tags[i].name) > 0;
        
        if (hasItem)
        {
            int style = (g_SelectedTag[client] == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            menu.AddItem(info, g_Tags[i].name, style);
        }
    }
    
    menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

/**
 * Menu handler for tags menu.
 */
public int MenuHandler_Tags(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));
            
            int choice = StringToInt(info);
            Tags_SelectTag(param1, choice);
            
            // Reopen menu at the same position
            ShowTagsMenu(param1, GetMenuSelectionPosition());
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                MenuHistory_GoBack(param1);
            }
            else
            {
                MenuHistory_Clear(param1);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    
    return 0;
}

/**
 * Select a tag for a player.
 * 
 * @param client         Client index
 * @param tagIndex       Tag index (-1 for none)
 */
void Tags_SelectTag(int client, int tagIndex)
{
    // Get old tag for forward
    char oldTag[64] = "";
    if (g_SelectedTag[client] >= 0 && g_SelectedTag[client] < g_TagsCount)
    {
        strcopy(oldTag, sizeof(oldTag), g_Tags[g_SelectedTag[client]].name);
    }
    
    // Set new tag
    g_SelectedTag[client] = tagIndex;
    
    char newTag[64] = "";
    char newColor[16] = "";
    
    if (tagIndex == TAGS_NONE)
    {
        // Clear tag
        Chat_Colors_SetTag(client, "");
        
        // Clear selection in database
        Selections_ClearPlayer(client, SELECTION_TAG);
        Selections_ClearPlayer(client, SELECTION_TAG_COLOR);
    }
    else if (tagIndex >= 0 && tagIndex < g_TagsCount)
    {
        strcopy(newTag, sizeof(newTag), g_Tags[tagIndex].name);
        strcopy(newColor, sizeof(newColor), g_Tags[tagIndex].color);
        
        // Apply tag to chat colors system
        Chat_Colors_SetTag(client, newTag);
        Chat_Colors_SetTagColor(client, HubChatColor_Hex, g_Tags[tagIndex].colorInt);
        
        // Save selection to database
        JSON_Object tagData = new JSON_Object();
        tagData.SetInt("id", tagIndex);
        tagData.SetString("name", newTag);
        tagData.SetString("color", newColor);
        
        Selections_SetPlayer(client, SELECTION_TAG, tagData);
        // Note: tagData ownership is transferred to Selections_SetPlayer
    }
    
    // Fire forward
    Cosmetics_FireTagChanged(client, oldTag, newTag);
    
    // Print message
    if (tagIndex == TAGS_NONE)
    {
        CPrintToChat(client, "%t", "Hub_Cosmetics_Tags_Cleared");
    }
    else
    {
        CPrintToChat(client, "%t", "Hub_Cosmetics_Tags_Selected", newTag);
    }
}

/**
 * Apply a player's saved tag selection.
 * Called when player loads.
 * 
 * @param client         Client index
 */
void Tags_ApplySelection(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    // Get saved selection
    JSON_Object tagData = Selections_GetPlayer(client, SELECTION_TAG);
    
    if (tagData == null)
    {
        g_SelectedTag[client] = TAGS_NONE;
        return;
    }
    
    // Get tag info - support both new format (name) and legacy format (text/value)
    char tagName[64];
    char tagColor[16];
    
    tagData.GetString("name", tagName, sizeof(tagName));
    tagData.GetString("color", tagColor, sizeof(tagColor));
    int tagId = tagData.GetInt("id", -1);
    
    // Fallback to "text" or "value" field if "name" is empty (from database load)
    if (strlen(tagName) == 0)
    {
        if (tagData.HasKey("text"))
        {
            tagData.GetString("text", tagName, sizeof(tagName));
        }
        else if (tagData.HasKey("value"))
        {
            tagData.GetString("value", tagName, sizeof(tagName));
        }
    }
    
    json_cleanup_and_delete(tagData);
    
    if (strlen(tagName) == 0)
    {
        g_SelectedTag[client] = TAGS_NONE;
        return;
    }
    
    // Find the tag in our loaded config
    int foundIndex = -1;
    for (int i = 0; i < g_TagsCount; i++)
    {
        if (StrEqual(g_Tags[i].name, tagName))
        {
            foundIndex = i;
            break;
        }
    }
    
    // Use saved ID if we couldn't find by name
    if (foundIndex == -1 && tagId >= 0 && tagId < g_TagsCount)
    {
        foundIndex = tagId;
    }
    
    g_SelectedTag[client] = foundIndex;
    
    // Note: We don't check ownership here because inventory may not be loaded yet
    // when this is called on player join. Ownership is verified when opening
    // the cosmetics menu or when selecting a new cosmetic.
    
    // Apply the tag if we found a valid one
    if (foundIndex >= 0)
    {
        Chat_Colors_SetTag(client, tagName);
        
        int colorInt = strlen(tagColor) > 0 ? Tags_ParseHexColor(tagColor) : g_Tags[foundIndex].colorInt;
        Chat_Colors_SetTagColor(client, HubChatColor_Hex, colorInt);
    }
}

/**
 * Handle player disconnect.
 * 
 * @param client         Client index
 */
void Tags_OnClientDisconnect(int client)
{
    g_SelectedTag[client] = TAGS_NONE;
}

// ============================================================================
// Natives Implementation
// ============================================================================

public int Native_Tags_GetPlayerTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int maxlen = GetNativeCell(3);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    if (g_SelectedTag[client] >= 0 && g_SelectedTag[client] < g_TagsCount)
    {
        SetNativeString(2, g_Tags[g_SelectedTag[client]].name, maxlen);
        return true;
    }
    
    SetNativeString(2, "", maxlen);
    return false;
}

public int Native_Tags_GetPlayerTagColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int maxlen = GetNativeCell(3);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    if (g_SelectedTag[client] >= 0 && g_SelectedTag[client] < g_TagsCount)
    {
        SetNativeString(2, g_Tags[g_SelectedTag[client]].color, maxlen);
        return true;
    }
    
    SetNativeString(2, "", maxlen);
    return false;
}

public int Native_Tags_SetPlayerTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char tag[64], color[16];
    GetNativeString(2, tag, sizeof(tag));
    GetNativeString(3, color, sizeof(color));
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    if (strlen(tag) == 0)
    {
        Tags_SelectTag(client, TAGS_NONE);
        return true;
    }
    
    // Find tag in config
    for (int i = 0; i < g_TagsCount; i++)
    {
        if (StrEqual(g_Tags[i].name, tag))
        {
            Tags_SelectTag(client, i);
            return true;
        }
    }
    
    // Tag not in config - set it directly
    Chat_Colors_SetTag(client, tag);
    if (strlen(color) > 0)
    {
        Chat_Colors_SetTagColor(client, HubChatColor_Hex, Tags_ParseHexColor(color));
    }
    
    return true;
}

public int Native_Tags_ClearPlayerTag(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    Tags_SelectTag(client, TAGS_NONE);
    return true;
}

public int Native_Tags_OpenMenu(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        return 0;
    }
    
    ShowTagsMenu(client, 0);
    return 0;
}

// ============================================================================
// Inventory Integration Helper Functions
// ============================================================================

/**
 * Apply a tag by name (for inventory equipping).
 * 
 * @param client         Client index
 * @param tagName        Name of the tag to apply
 * @return               True on success
 */
bool Tags_ApplyByName(int client, const char[] tagName)
{
    if (!IsValidPlayer(client) || strlen(tagName) == 0)
    {
        return false;
    }
    
    // Find the tag by name
    for (int i = 0; i < g_TagsCount; i++)
    {
        if (StrEqual(g_Tags[i].name, tagName, false))
        {
            Tags_SelectTag(client, i);
            return true;
        }
    }
    
    return false;
}

/**
 * Clear a player's tag (for inventory unequipping).
 * 
 * @param client         Client index
 */
void Tags_Clear(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    Tags_SelectTag(client, TAGS_NONE);
}
