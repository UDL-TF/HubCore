/**
 * HubCore Chat Menus
 * 
 * Menu system for chat color settings - allows players to browse owned colors,
 * enable/disable tags, select from purchased colors, and reset to defaults.
 * Colors are loaded from configs/hub/colors.cfg
 */

#define MAX_CHAT_COLORS 256
#define CHAT_COLORS_CATEGORY "Chat Colors"

enum struct MenuColorEntry
{
    int id;
    char name[64];
    char hex[16];
    char flags[32];
    int cost;
}

MenuColorEntry g_MenuColors[MAX_CHAT_COLORS];
int g_MenuColorCount = 0;

// Track which color menu type is being displayed per client
enum ChatColorMenuType
{
    ColorMenu_Name = 0,
    ColorMenu_Chat,
    ColorMenu_Tag
}
ChatColorMenuType g_ClientColorMenuType[MAXPLAYERS + 1];

/**
 * Register chat menu commands and load colors config.
 */
void Chat_Menus_Init()
{
    RegConsoleCmd("sm_chatcolors", Cmd_ChatColors, "Open chat colors menu");
    RegConsoleCmd("sm_ccc", Cmd_ChatColors, "Open chat colors menu");
    RegConsoleCmd("sm_colors", Cmd_ChatColors, "Open chat colors menu");
    RegConsoleCmd("sm_chatcolor", Cmd_ChatColorMenu, "Open chat color menu");
    RegConsoleCmd("sm_namecolor", Cmd_NameColorMenu, "Open name color menu");
    
    // Admin test commands
    RegAdminCmd("sm_hub_settag", Cmd_AdminSetTag, ADMFLAG_ROOT, "Set your chat tag");
    RegAdminCmd("sm_hub_setcolor", Cmd_AdminSetColor, ADMFLAG_ROOT, "Set chat color (name/chat/tag)");
    RegAdminCmd("sm_hub_chattest", Cmd_AdminChatTest, ADMFLAG_ROOT, "Test chat message display");
    
    // Load colors from config
    Chat_LoadColorsConfig();
    
    // Register with cosmetics system
    Cosmetics_Register(Cosmetic_ChatColors, "Hub_Cosmetics_ChatColors", "chatcolors");
}

/**
 * Load colors from configs/hub/colors.cfg
 */
void Chat_LoadColorsConfig()
{
    g_MenuColorCount = 0;
    
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/hub/colors.cfg");
    
    KeyValues kv = new KeyValues("CCC Menu Colors");
    if (!kv.ImportFromFile(path))
    {
        LogError("[Hub Chat] Failed to load colors config: %s", path);
        delete kv;
        return;
    }
    
    if (!kv.GotoFirstSubKey())
    {
        LogError("[Hub Chat] No colors found in config: %s", path);
        delete kv;
        return;
    }
    
    do
    {
        if (g_MenuColorCount >= MAX_CHAT_COLORS)
        {
            LogError("[Hub Chat] Max colors (%d) reached, some colors not loaded", MAX_CHAT_COLORS);
            break;
        }
        
        char sectionName[16];
        kv.GetSectionName(sectionName, sizeof(sectionName));
        
        g_MenuColors[g_MenuColorCount].id = StringToInt(sectionName);
        kv.GetString("name", g_MenuColors[g_MenuColorCount].name, sizeof(MenuColorEntry::name), "Unknown");
        kv.GetString("hex", g_MenuColors[g_MenuColorCount].hex, sizeof(MenuColorEntry::hex), "#FFFFFF");
        kv.GetString("flags", g_MenuColors[g_MenuColorCount].flags, sizeof(MenuColorEntry::flags), "");
        g_MenuColors[g_MenuColorCount].cost = kv.GetNum("cost", 0);
        
        g_MenuColorCount++;
    }
    while (kv.GotoNextKey());
    
    delete kv;
    LogMessage("[Hub Chat] Loaded %d colors from config", g_MenuColorCount);
}

/**
 * Check if a client has access to a color based on flags.
 * 
 * @param client    Client index.
 * @param flags     Color flags string.
 * @return          True if client can use the color.
 */
bool Chat_ClientHasColorAccess(int client, const char[] flags)
{
    // Empty flags or "s" (standard) = everyone can use
    if (flags[0] == '\0' || StrEqual(flags, "s"))
    {
        return true;
    }
    
    // Check admin flags
    int adminFlags = ReadFlagString(flags);
    return CheckCommandAccess(client, "", adminFlags, true);
}

/**
 * Check if a client owns a color (purchased from shop or has admin access).
 * 
 * @param client        Client index.
 * @param colorIndex    Index in g_MenuColors array.
 * @return              True if client owns/can use the color.
 */
bool Chat_ClientOwnsColor(int client, int colorIndex)
{
    if (colorIndex < 0 || colorIndex >= g_MenuColorCount)
    {
        return false;
    }
    
    // Admins with ban access have access to all chat colors
    if (CheckCommandAccess(client, "", ADMFLAG_BAN, true))
    {
        return true;
    }
    
    // Check admin flags first
    if (Chat_ClientHasColorAccess(client, g_MenuColors[colorIndex].flags))
    {
        // If cost is 0, everyone with flag access can use it
        if (g_MenuColors[colorIndex].cost <= 0)
        {
            return true;
        }
    }
    
    // Check if player has purchased this color from shop.
    // Support both Chat Colors and Name Colors categories.
    return Hub_HasPlayerItemName(client, CHAT_COLORS_CATEGORY, g_MenuColors[colorIndex].name) > 0
        || Hub_HasPlayerItemName(client, "Name Colors", g_MenuColors[colorIndex].name) > 0;
}

/**
 * Get the color index by hex value.
 * 
 * @param hex       Hex color string.
 * @return          Index in g_MenuColors or -1 if not found.
 */
int Chat_GetColorIndexByHex(const char[] hex)
{
    for (int i = 0; i < g_MenuColorCount; i++)
    {
        if (StrEqual(g_MenuColors[i].hex, hex, false))
        {
            return i;
        }
    }
    return -1;
}

/**
 * Get color info by name.
 * 
 * @param name      Color name.
 * @param hex       Buffer for hex value.
 * @param maxlen    Max buffer length.
 * @param cost      Reference to store cost.
 * @return          Index in g_MenuColors or -1 if not found.
 */
int Chat_GetColorByName(const char[] name, char[] hex, int maxlen, int &cost)
{
    for (int i = 0; i < g_MenuColorCount; i++)
    {
        if (StrEqual(g_MenuColors[i].name, name, false))
        {
            strcopy(hex, maxlen, g_MenuColors[i].hex);
            cost = g_MenuColors[i].cost;
            return i;
        }
    }
    return -1;
}

// ==================== Command Handlers ====================

public Action Cmd_ChatColors(int client, int args)
{
    if (!IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    Menu_ChatSettings(client);
    return Plugin_Handled;
}

public Action Cmd_ChatColorMenu(int client, int args)
{
    if (!IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    Menu_ChatColor(client);
    return Plugin_Handled;
}

public Action Cmd_NameColorMenu(int client, int args)
{
    if (!IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    Menu_NameColor(client);
    return Plugin_Handled;
}

public Action Cmd_AdminSetTag(int client, int args)
{
    if (args < 1)
    {
        HubChat_SetClientTag(client, "");
        ReplyToCommand(client, "[Hub Chat] Tag cleared");
        return Plugin_Handled;
    }
    
    char tag[HUB_CHAT_MAX_TAG];
    GetCmdArgString(tag, sizeof(tag));
    HubChat_SetClientTag(client, tag);
    ReplyToCommand(client, "[Hub Chat] Tag set to: %s", tag);
    return Plugin_Handled;
}

public Action Cmd_AdminSetColor(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Hub Chat] Usage: sm_hub_setcolor <name|chat|tag> <color>");
        ReplyToCommand(client, "[Hub Chat] Colors: team, green, olive, #RRGGBB");
        return Plugin_Handled;
    }
    
    char type[16], colorStr[16];
    GetCmdArg(1, type, sizeof(type));
    GetCmdArg(2, colorStr, sizeof(colorStr));
    
    int colorValue;
    HubChatColorType colorType = HubChat_ParseColorString(colorStr, colorValue);
    
    if (StrEqual(type, "name", false))
    {
        HubChat_SetClientNameColor(client, colorType, colorValue);
        ReplyToCommand(client, "[Hub Chat] Name color set");
    }
    else if (StrEqual(type, "chat", false))
    {
        HubChat_SetClientChatColor(client, colorType, colorValue);
        ReplyToCommand(client, "[Hub Chat] Chat color set");
    }
    else if (StrEqual(type, "tag", false))
    {
        HubChat_SetClientTagColor(client, colorType, colorValue);
        ReplyToCommand(client, "[Hub Chat] Tag color set");
    }
    else
    {
        ReplyToCommand(client, "[Hub Chat] Unknown type. Use: name, chat, or tag");
    }
    
    return Plugin_Handled;
}

public Action Cmd_AdminChatTest(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[Hub Chat] Usage: sm_hub_chattest <message>");
        return Plugin_Handled;
    }
    
    char message[256];
    GetCmdArgString(message, sizeof(message));
    
    char name[64];
    GetClientName(client, name, sizeof(name));
    
    // Apply colors and send test message
    char formattedName[HUB_CHAT_MAX_NAME];
    char formattedMsg[HUB_CHAT_MAX_MESSAGE];
    strcopy(formattedName, sizeof(formattedName), name);
    strcopy(formattedMsg, sizeof(formattedMsg), message);
    
    Chat_Colors_ApplyToMessage(client, formattedName, sizeof(formattedName), formattedMsg, sizeof(formattedMsg));
    
    Chat_PrintToClient(client, client, "\x01%s\x01 :  %s", formattedName, formattedMsg);
    ReplyToCommand(client, "[Hub Chat] Test message sent to yourself");
    
    return Plugin_Handled;
}

// ==================== Main Chat Settings Menu ====================

void Menu_ChatSettings(int client)
{
    MenuHistory_Push(client, MenuType_CosmeticsChat, 0);
    
    Menu menu = new Menu(MenuHandler_ChatSettings);
    menu.SetTitle("%T", "Hub_Chat_MenuTitle", client);
    
    char buffer[128];
    
    // Tag Settings
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_TagSettings", client);
    menu.AddItem("tag", buffer);
    
    // Name Color
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_NameColor", client);
    menu.AddItem("name", buffer);
    
    // Chat Color
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_ChatColor", client);
    menu.AddItem("chat", buffer);
    
    // Reset All
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_ResetAll", client);
    menu.AddItem("reset_all", buffer);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ChatSettings(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
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
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "tag"))
        {
            Menu_TagSettings(param1);
        }
        else if (StrEqual(info, "name"))
        {
            Menu_NameColor(param1);
        }
        else if (StrEqual(info, "chat"))
        {
            Menu_ChatColor(param1);
        }
        else if (StrEqual(info, "reset_all"))
        {
            HubChat_ResetClientColors(param1);
            CPrintToChat(param1, "%t", "Hub_Chat_AllReset");
            Menu_ChatSettings(param1);
        }
    }
    return 0;
}

// ==================== Tag Settings Menu ====================

void Menu_TagSettings(int client)
{
    Menu menu = new Menu(MenuHandler_TagSettings);
    menu.SetTitle("%T", "Hub_Chat_TagSettingsTitle", client);
    
    char buffer[128];
    
    // Enable/Disable Tag Toggle
    bool tagEnabled = HubChat_IsClientTagEnabled(client);
    Format(buffer, sizeof(buffer), "%T: %s", "Hub_Chat_TagVisibility", client, 
        tagEnabled ? "ON" : "OFF");
    menu.AddItem("toggle", buffer);
    
    // Select Tag (from owned - integrates with existing Tags system)
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_SelectTag", client);
    menu.AddItem("select_tag", buffer);
    
    // Tag Color
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_TagColor", client);
    menu.AddItem("tag_color", buffer);
    
    // Reset Tag to Default
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_ResetTagDefault", client);
    menu.AddItem("reset", buffer);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TagSettings(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Menu_ChatSettings(param1);
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "toggle"))
        {
            bool current = HubChat_IsClientTagEnabled(param1);
            HubChat_SetClientTagEnabled(param1, !current);
            CPrintToChat(param1, "%t", current ? "Hub_Chat_TagDisabled" : "Hub_Chat_TagEnabled");
            Menu_TagSettings(param1);
        }
        else if (StrEqual(info, "select_tag"))
        {
            // Use existing tags menu from tags.sp
            ShowTagsMenu(param1, 0);
        }
        else if (StrEqual(info, "tag_color"))
        {
            Menu_TagColor(param1);
        }
        else if (StrEqual(info, "reset"))
        {
            HubChat_SetClientTag(param1, "");
            HubChat_SetClientTagColor(param1, HubChatColor_None, 0);
            CPrintToChat(param1, "%t", "Hub_Chat_TagReset");
            Menu_TagSettings(param1);
        }
    }
    return 0;
}

// ==================== Tag Color Menu ====================

void Menu_TagColor(int client)
{
    g_ClientColorMenuType[client] = ColorMenu_Tag;
    Menu_ColorSelection(client, ColorMenu_Tag);
}

public int MenuHandler_TagColor(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Menu_TagSettings(param1);
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "reset"))
        {
            HubChat_SetClientTagColor(param1, HubChatColor_None, 0);
            CPrintToChat(param1, "%t", "Hub_Chat_TagColorReset");
        }
        else if (StrEqual(info, "team"))
        {
            HubChat_SetClientTagColor(param1, HubChatColor_Team, 0);
            CPrintToChat(param1, "%t", "Hub_Chat_TagColorSet", "Team Color");
        }
        else
        {
            int colorValue;
            HubChatColorType colorType = HubChat_ParseColorString(info, colorValue);
            HubChat_SetClientTagColor(param1, colorType, colorValue);
            
            // Find the color name for the message
            char colorName[64];
            GetColorNameByHex(info, colorName, sizeof(colorName));
            CPrintToChat(param1, "%t", "Hub_Chat_TagColorSet", colorName);
        }
        
        Menu_TagSettings(param1);
    }
    return 0;
}

// ==================== Name Color Menu ====================

void Menu_NameColor(int client)
{
    g_ClientColorMenuType[client] = ColorMenu_Name;
    Menu_ColorSelection(client, ColorMenu_Name);
}

public int MenuHandler_NameColor(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Menu_ChatSettings(param1);
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "reset"))
        {
            HubChat_SetClientNameColor(param1, HubChatColor_Team, 0);
            CPrintToChat(param1, "%t", "Hub_Chat_NameColorReset");
        }
        else if (StrEqual(info, "team"))
        {
            HubChat_SetClientNameColor(param1, HubChatColor_Team, 0);
            CPrintToChat(param1, "%t", "Hub_Chat_NameColorSet", "Team Color");
        }
        else
        {
            int colorValue;
            HubChatColorType colorType = HubChat_ParseColorString(info, colorValue);
            HubChat_SetClientNameColor(param1, colorType, colorValue);
            
            // Find the color name for the message
            char colorName[64];
            GetColorNameByHex(info, colorName, sizeof(colorName));
            CPrintToChat(param1, "%t", "Hub_Chat_NameColorSet", colorName);
        }
        
        Menu_NameColor(param1);
    }
    return 0;
}

// ==================== Chat Color Menu ====================

void Menu_ChatColor(int client)
{
    g_ClientColorMenuType[client] = ColorMenu_Chat;
    Menu_ColorSelection(client, ColorMenu_Chat);
}

public int MenuHandler_ChatColor(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        Menu_ChatSettings(param1);
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "reset") || StrEqual(info, "none"))
        {
            HubChat_SetClientChatColor(param1, HubChatColor_None, 0);
            CPrintToChat(param1, "%t", "Hub_Chat_ChatColorReset");
        }
        else if (StrEqual(info, "team"))
        {
            HubChat_SetClientChatColor(param1, HubChatColor_Team, 0);
            CPrintToChat(param1, "%t", "Hub_Chat_ChatColorSet", "Team Color");
        }
        else
        {
            int colorValue;
            HubChatColorType colorType = HubChat_ParseColorString(info, colorValue);
            HubChat_SetClientChatColor(param1, colorType, colorValue);
            
            // Find the color name for the message
            char colorName[64];
            GetColorNameByHex(info, colorName, sizeof(colorName));
            CPrintToChat(param1, "%t", "Hub_Chat_ChatColorSet", colorName);
        }
        
        Menu_ChatColor(param1);
    }
    return 0;
}

// ==================== Unified Color Selection Menu ====================

/**
 * Display a unified color selection menu from colors.cfg
 */
void Menu_ColorSelection(int client, ChatColorMenuType menuType)
{
    Menu menu = new Menu(MenuHandler_ColorSelection);
    
    char title[128];
    switch (menuType)
    {
        case ColorMenu_Name:
        {
            Format(title, sizeof(title), "%T", "Hub_Chat_NameColorTitle", client);
        }
        case ColorMenu_Chat:
        {
            Format(title, sizeof(title), "%T", "Hub_Chat_ChatColorTitle", client);
        }
        case ColorMenu_Tag:
        {
            Format(title, sizeof(title), "%T", "Hub_Chat_TagColorTitle", client);
        }
    }
    menu.SetTitle(title);
    
    char buffer[128];
    
    // Reset to Default option
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_ResetDefault", client);
    menu.AddItem("reset", buffer);
    
    // Team Color option (always available)
    Format(buffer, sizeof(buffer), "%T", "Hub_Chat_TeamColor", client);
    menu.AddItem("team", buffer);
    
    // No Color option (for chat color only)
    if (menuType == ColorMenu_Chat)
    {
        Format(buffer, sizeof(buffer), "%T", "Hub_Chat_NoColor", client);
        menu.AddItem("none", buffer);
    }
    
    // Add all colors from config that client owns or can access
    for (int i = 0; i < g_MenuColorCount; i++)
    {
        // Skip colors the client doesn't have flag access to
        if (!Chat_ClientHasColorAccess(client, g_MenuColors[i].flags))
        {
            continue;
        }
        
        bool ownsColor = Chat_ClientOwnsColor(client, i);
        
        // Format: "Color Name" or "Color Name (Owned)" if owned
        if (ownsColor)
        {
            Format(buffer, sizeof(buffer), "%s (Owned)", g_MenuColors[i].name);
            menu.AddItem(g_MenuColors[i].hex, buffer, ITEMDRAW_DEFAULT);
        }
        else
        {
            Format(buffer, sizeof(buffer), "%s", g_MenuColors[i].name);
            menu.AddItem(g_MenuColors[i].hex, buffer, ITEMDRAW_DISABLED);
        }
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ColorSelection(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        // Route back to appropriate menu
        switch (g_ClientColorMenuType[param1])
        {
            case ColorMenu_Name:
                Menu_ChatSettings(param1);
            case ColorMenu_Chat:
                Menu_ChatSettings(param1);
            case ColorMenu_Tag:
                Menu_TagSettings(param1);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        // Route to appropriate handler based on stored menu type
        switch (g_ClientColorMenuType[param1])
        {
            case ColorMenu_Name:
                HandleNameColorSelection(param1, info);
            case ColorMenu_Chat:
                HandleChatColorSelection(param1, info);
            case ColorMenu_Tag:
                HandleTagColorSelection(param1, info);
        }
    }
    return 0;
}

void HandleNameColorSelection(int client, const char[] info)
{
    if (StrEqual(info, "reset") || StrEqual(info, "team"))
    {
        HubChat_SetClientNameColor(client, HubChatColor_Team, 0);
        CPrintToChat(client, "%t", "Hub_Chat_NameColorReset");
    }
    else
    {
        // Verify ownership before applying
        int colorIndex = Chat_GetColorIndexByHex(info);
        if (colorIndex >= 0 && !Chat_ClientOwnsColor(client, colorIndex))
        {
            CPrintToChat(client, "%t", "Hub_Chat_ColorNotOwned");
            Menu_NameColor(client);
            return;
        }
        
        int colorValue;
        HubChatColorType colorType = HubChat_ParseColorString(info, colorValue);
        HubChat_SetClientNameColor(client, colorType, colorValue);
        
        char colorName[64];
        GetColorNameByHex(info, colorName, sizeof(colorName));
        CPrintToChat(client, "%t", "Hub_Chat_NameColorSet", colorName);
    }
    Menu_NameColor(client);
}

void HandleChatColorSelection(int client, const char[] info)
{
    if (StrEqual(info, "reset") || StrEqual(info, "none"))
    {
        HubChat_SetClientChatColor(client, HubChatColor_None, 0);
        CPrintToChat(client, "%t", "Hub_Chat_ChatColorReset");
    }
    else if (StrEqual(info, "team"))
    {
        HubChat_SetClientChatColor(client, HubChatColor_Team, 0);
        CPrintToChat(client, "%t", "Hub_Chat_ChatColorSet", "Team Color");
    }
    else
    {
        // Verify ownership before applying
        int colorIndex = Chat_GetColorIndexByHex(info);
        if (colorIndex >= 0 && !Chat_ClientOwnsColor(client, colorIndex))
        {
            CPrintToChat(client, "%t", "Hub_Chat_ColorNotOwned");
            Menu_ChatColor(client);
            return;
        }
        
        int colorValue;
        HubChatColorType colorType = HubChat_ParseColorString(info, colorValue);
        HubChat_SetClientChatColor(client, colorType, colorValue);
        
        char colorName[64];
        GetColorNameByHex(info, colorName, sizeof(colorName));
        CPrintToChat(client, "%t", "Hub_Chat_ChatColorSet", colorName);
    }
    Menu_ChatColor(client);
}

void HandleTagColorSelection(int client, const char[] info)
{
    if (StrEqual(info, "reset"))
    {
        HubChat_SetClientTagColor(client, HubChatColor_None, 0);
        CPrintToChat(client, "%t", "Hub_Chat_TagColorReset");
    }
    else if (StrEqual(info, "team"))
    {
        HubChat_SetClientTagColor(client, HubChatColor_Team, 0);
        CPrintToChat(client, "%t", "Hub_Chat_TagColorSet", "Team Color");
    }
    else
    {
        // Verify ownership before applying
        int colorIndex = Chat_GetColorIndexByHex(info);
        if (colorIndex >= 0 && !Chat_ClientOwnsColor(client, colorIndex))
        {
            CPrintToChat(client, "%t", "Hub_Chat_ColorNotOwned");
            Menu_TagSettings(client);
            return;
        }
        
        int colorValue;
        HubChatColorType colorType = HubChat_ParseColorString(info, colorValue);
        HubChat_SetClientTagColor(client, colorType, colorValue);
        
        char colorName[64];
        GetColorNameByHex(info, colorName, sizeof(colorName));
        CPrintToChat(client, "%t", "Hub_Chat_TagColorSet", colorName);
    }
    Menu_TagSettings(client);
}

/**
 * Get the color name by hex value from loaded config.
 */
void GetColorNameByHex(const char[] hex, char[] name, int maxlen)
{
    for (int i = 0; i < g_MenuColorCount; i++)
    {
        if (StrEqual(g_MenuColors[i].hex, hex, false))
        {
            strcopy(name, maxlen, g_MenuColors[i].name);
            return;
        }
    }
    
    // Not found, just use the hex value
    strcopy(name, maxlen, hex);
}
