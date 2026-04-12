/**
 * HubCore Footprints System
 * 
 * Manages player footprint effects using TF2 attributes.
 * Migrated from FootprintShop functionality.
 */

#include <hub-footprints>
#include <tf2attributes>

// Footprint definitions
FootprintInfo g_Footprints[] = {
    { "0",        "No Effect",         0.0 },
    { "7777",     "Blue",              7777.0 },
    { "933333",   "Light Blue",        933333.0 },
    { "8421376",  "Yellow",            8421376.0 },
    { "4552221",  "Corrupted Green",   4552221.0 },
    { "3100495",  "Dark Green",        3100495.0 },
    { "51234123", "Lime",              51234123.0 },
    { "5322826",  "Brown",             5322826.0 },
    { "8355220",  "Oak Tree Brown",    8355220.0 },
    { "13595446", "Flames",            13595446.0 },
    { "8208497",  "Cream",             8208497.0 },
    { "41234123", "Pink",              41234123.0 },
    { "300000",   "Satan's Blue",      300000.0 },
    { "2",        "Purple",            2.0 },
    { "3",        "4 8 15 16 23 42",   3.0 },
    { "83552",    "Ghost In The Machine", 83552.0 },
    { "9335510",  "Holy Flame",        9335510.0 }
};

int g_FootprintsCount = sizeof(g_Footprints);

// Player selected footprints
int g_SelectedFootprint[MAXPLAYERS + 1] = { FOOTPRINTS_NONE, ... };
float g_FootprintValue[MAXPLAYERS + 1] = { 0.0, ... };
float g_LastFootprintApply[MAXPLAYERS + 1] = { 0.0, ... };

/**
 * Initialize the footprints system.
 */
void Footprints_Init()
{
    // Register command
    RegConsoleCmd("sm_footprints", Command_Footprints, "Opens the footprints menu");
    RegConsoleCmd("sm_footsteps", Command_Footprints, "Opens the footprints menu");
    
    // Register cosmetic
    Cosmetics_Register(Cosmetic_Footprint, "Hub_Cosmetics_Footprints", "footprints");
    
    // Hook player spawn for applying footprints
    HookEvent("player_spawn", Event_PlayerSpawn_Footprints);
    
    LogMessage("[HubCore] Footprints system initialized with %d footprint types", g_FootprintsCount);
}

/**
 * Register footprints natives.
 */
void Footprints_RegisterNatives()
{
    CreateNative("Footprints_GetPlayerFootprint", Native_Footprints_GetPlayerFootprint);
    CreateNative("Footprints_SetPlayerFootprint", Native_Footprints_SetPlayerFootprint);
    CreateNative("Footprints_ClearPlayerFootprint", Native_Footprints_ClearPlayerFootprint);
    CreateNative("Footprints_OpenMenu", Native_Footprints_OpenMenu);
}

/**
 * Event handler for player spawn.
 */
public void Event_PlayerSpawn_Footprints(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    // Reset apply time so OnPlayerRunCmd can immediately re-apply the moment the delay fires
    g_LastFootprintApply[client] = 0.0;
    
    // Delay the apply so TF2 finishes stripping/resetting attributes during the spawn sequence
    // before we set them. Applying immediately causes a brief flash then disappears.
    CreateTimer(0.5, Timer_ApplyFootprints, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * Timer to apply footprints after player has fully spawned.
 */
public Action Timer_ApplyFootprints(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    
    if (!IsValidPlayer(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }
    
    Footprints_ApplySelection(client);
    return Plugin_Stop;
}

/**
 * Command handler for /sm_footprints
 */
public Action Command_Footprints(int client, int args)
{
    if (!IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    ShowFootprintsMenu(client, 0);
    return Plugin_Handled;
}

/**
 * Show the footprints menu.
 * 
 * @param client         Client index
 * @param page           Menu page to display
 */
void ShowFootprintsMenu(int client, int page)
{
    MenuHistory_Push(client, MenuType_CosmeticsFootprints, 0);
    
    Menu menu = new Menu(MenuHandler_Footprints);
    menu.ExitBackButton = true;
    
    menu.SetTitle("%t", "Hub_Cosmetics_Footprints_Title");
    
    for (int i = 0; i < g_FootprintsCount; i++)
    {
        char info[8];
        IntToString(i, info, sizeof(info));
        
        // First option (No Effect) is always available
        if (i == 0)
        {
            int style = (g_SelectedFootprint[client] == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            menu.AddItem(info, g_Footprints[i].name, style);
            continue;
        }
        
        // Check if player owns this footprint
        bool hasItem = Hub_HasPlayerItemName(client, "Footprints", g_Footprints[i].name) > 0;
        
        if (hasItem)
        {
            int style = (g_SelectedFootprint[client] == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            menu.AddItem(info, g_Footprints[i].name, style);
        }
        else
        {
            menu.AddItem(info, g_Footprints[i].name, ITEMDRAW_DISABLED);
        }
    }
    
    menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

/**
 * Menu handler for footprints menu.
 */
public int MenuHandler_Footprints(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));
            
            int choice = StringToInt(info);
            Footprints_SelectFootprint(param1, choice);
            
            // Reopen menu at the same position
            ShowFootprintsMenu(param1, GetMenuSelectionPosition());
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
 * Select a footprint for a player.
 * 
 * @param client         Client index
 * @param footprintIndex Footprint index
 */
void Footprints_SelectFootprint(int client, int footprintIndex)
{
    if (footprintIndex < 0 || footprintIndex >= g_FootprintsCount)
    {
        footprintIndex = FOOTPRINTS_NONE;
    }
    
    // Get old footprint for forward
    int oldFootprint = g_SelectedFootprint[client];
    
    // Set new footprint
    g_SelectedFootprint[client] = footprintIndex;
    g_FootprintValue[client] = g_Footprints[footprintIndex].value;
    
	// Apply footprint attribute
	if (footprintIndex == FOOTPRINTS_NONE || g_Footprints[footprintIndex].value == 0.0)
	{
		TF2Attrib_SetByName(client, "SPELL: set Halloween footstep type", 0.0);
		g_LastFootprintApply[client] = 0.0;
        
        // Clear selection in database
        Selections_ClearPlayer(client, SELECTION_FOOTPRINT);
    }
	else
	{
		TF2Attrib_SetByName(client, "SPELL: set Halloween footstep type", g_Footprints[footprintIndex].value);
		g_LastFootprintApply[client] = GetGameTime();
        
        // Save selection to database
        JSON_Object footprintData = new JSON_Object();
        footprintData.SetInt("id", footprintIndex);
        footprintData.SetString("name", g_Footprints[footprintIndex].name);
        footprintData.SetFloat("value", g_Footprints[footprintIndex].value);
        
        Selections_SetPlayer(client, SELECTION_FOOTPRINT, footprintData);
    }
    
    // Fire forward
    Cosmetics_FireFootprintChanged(client, oldFootprint, footprintIndex);
    
    // Print message
    if (footprintIndex == FOOTPRINTS_NONE)
    {
        CPrintToChat(client, "%t", "Hub_Cosmetics_Footprints_Cleared");
    }
    else
    {
        CPrintToChat(client, "%t", "Hub_Cosmetics_Footprints_Selected", g_Footprints[footprintIndex].name);
    }
}

/**
 * Apply a player's saved footprint selection.
 * Called on player spawn and when player loads.
 * 
 * @param client         Client index
 */
void Footprints_ApplySelection(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    // If we already have a selection in memory, apply it
    if (g_SelectedFootprint[client] > 0)
    {
        TF2Attrib_SetByName(client, "SPELL: set Halloween footstep type", g_FootprintValue[client]);
        return;
    }
    
    // Otherwise, load from database
    JSON_Object footprintData = Selections_GetPlayer(client, SELECTION_FOOTPRINT);
    
    if (footprintData == null)
    {
        g_SelectedFootprint[client] = FOOTPRINTS_NONE;
        g_FootprintValue[client] = 0.0;
        return;
    }
    
    // Get footprint info - support both new format (name) and legacy format (value)
    char footprintName[64];
    footprintData.GetString("name", footprintName, sizeof(footprintName));
    int footprintId = footprintData.GetInt("id", 0);
    float footprintValue = footprintData.GetFloat("value", 0.0);
    
    // Fallback to "value" field if "name" is empty (from database load)
    if (strlen(footprintName) == 0 && footprintData.HasKey("value"))
    {
        footprintData.GetString("value", footprintName, sizeof(footprintName));
    }
    
    json_cleanup_and_delete(footprintData);
    
    if (strlen(footprintName) == 0)
    {
        g_SelectedFootprint[client] = FOOTPRINTS_NONE;
        g_FootprintValue[client] = 0.0;
        return;
    }
    
    // Find the footprint by name
    int foundIndex = -1;
    for (int i = 0; i < g_FootprintsCount; i++)
    {
        if (StrEqual(g_Footprints[i].name, footprintName))
        {
            foundIndex = i;
            break;
        }
    }
    
    // Use saved ID if we couldn't find by name
    if (foundIndex == -1 && footprintId >= 0 && footprintId < g_FootprintsCount)
    {
        foundIndex = footprintId;
    }
    
    if (foundIndex == -1)
    {
        g_SelectedFootprint[client] = FOOTPRINTS_NONE;
        g_FootprintValue[client] = 0.0;
        return;
    }
    
    g_SelectedFootprint[client] = foundIndex;
    g_FootprintValue[client] = footprintValue > 0.0 ? footprintValue : g_Footprints[foundIndex].value;
    
    // Note: We don't check ownership here because inventory may not be loaded yet
    // when this is called on player spawn. Ownership is verified when opening
    // the cosmetics menu or when selecting a new cosmetic.
    
	// Apply the footprint
	TF2Attrib_SetByName(client, "SPELL: set Halloween footstep type", g_FootprintValue[client]);
	g_LastFootprintApply[client] = GetGameTime();
}

/**
 * Keeps footprint attributes applied while alive.
 * Some game events on Linux can strip the player attribute shortly after spawn.
 */
void Footprints_OnPlayerRunCmd(int client)
{
	if (!IsValidPlayer(client) || !IsPlayerAlive(client))
	{
		return;
	}

	int footprintIndex = g_SelectedFootprint[client];
	if (footprintIndex <= FOOTPRINTS_NONE || footprintIndex >= g_FootprintsCount)
	{
		return;
	}

	float now = GetGameTime();
	if ((now - g_LastFootprintApply[client]) < 1.0)
	{
		return;
	}

	TF2Attrib_SetByName(client, "SPELL: set Halloween footstep type", g_FootprintValue[client]);
	g_LastFootprintApply[client] = now;
}

/**
 * Handle player disconnect.
 * 
 * @param client         Client index
 */
void Footprints_OnClientDisconnect(int client)
{
    g_SelectedFootprint[client] = FOOTPRINTS_NONE;
    g_FootprintValue[client] = 0.0;
    g_LastFootprintApply[client] = 0.0;
}

// ============================================================================
// Natives Implementation
// ============================================================================

public int Native_Footprints_GetPlayerFootprint(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int maxlen = GetNativeCell(3);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    if (g_SelectedFootprint[client] >= 0 && g_SelectedFootprint[client] < g_FootprintsCount)
    {
        SetNativeString(2, g_Footprints[g_SelectedFootprint[client]].name, maxlen);
        return true;
    }
    
    SetNativeString(2, "", maxlen);
    return false;
}

public int Native_Footprints_SetPlayerFootprint(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char footprintName[64];
    GetNativeString(2, footprintName, sizeof(footprintName));
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    // Find footprint by name
    for (int i = 0; i < g_FootprintsCount; i++)
    {
        if (StrEqual(g_Footprints[i].name, footprintName))
        {
            Footprints_SelectFootprint(client, i);
            return true;
        }
    }
    
    return false;
}

public int Native_Footprints_ClearPlayerFootprint(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    Footprints_SelectFootprint(client, FOOTPRINTS_NONE);
    return true;
}

public int Native_Footprints_OpenMenu(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        return 0;
    }
    
    ShowFootprintsMenu(client, 0);
    return 0;
}

// ============================================================================
// Inventory Integration Helper Functions
// ============================================================================

/**
 * Apply a footprint by name (for inventory equipping).
 * 
 * @param client         Client index
 * @param footprintName  Name of the footprint to apply
 * @return               True on success
 */
bool Footprints_ApplyByName(int client, const char[] footprintName)
{
    if (!IsValidPlayer(client) || strlen(footprintName) == 0)
    {
        return false;
    }
    
    // Find the footprint by name
    for (int i = 0; i < g_FootprintsCount; i++)
    {
        if (StrEqual(g_Footprints[i].name, footprintName, false))
        {
            Footprints_SelectFootprint(client, i);
            return true;
        }
    }
    
    return false;
}

/**
 * Clear a player's footprint (for inventory unequipping).
 * 
 * @param client         Client index
 */
void Footprints_Clear(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    Footprints_SelectFootprint(client, FOOTPRINTS_NONE);
}
