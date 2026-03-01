/**
 * HubCore Trails System
 * 
 * Manages player trail effects with special color modes.
 * Migrated from Trails-Chroma functionality.
 */

#include <hub-trails>

#undef REQUIRE_EXTENSIONS
#include <tf2>
#include <tf2_stocks>

#define TRAILS_BEAM_SPRITE_FALLBACK "materials/sprites/laserbeam.vmt"

// ConVars
ConVar g_cvTrailsEnabled = null;
ConVar g_cvForceCheapTrails = null;
ConVar g_cvRemoveOnRespawn = null;
ConVar g_cvAllowHide = null;

// Trail data from config
TrailInfo g_Trails[TRAILS_MAX_COUNT];
int g_TrailsCount = 0;

// Beam sprite model index
int g_BeamSprite = 0;

// Player data
int g_SelectedTrail[MAXPLAYERS + 1] = { TRAILS_NONE, ... };
bool g_IsHidingTrails[MAXPLAYERS + 1];
bool g_IsOddFrame[MAXPLAYERS + 1];

// Dynamic effect data per player
TrailColor g_DynamicColor[MAXPLAYERS + 1];
int g_DynamicAlpha[MAXPLAYERS + 1];
float g_DynamicWidth[MAXPLAYERS + 1];
float g_LastPosition[MAXPLAYERS + 1][3];

TrailSpectrumCycleMode g_SpectrumCycleMode[MAXPLAYERS + 1];
TrailBreathingMode g_BreathingMode[MAXPLAYERS + 1];
TrailBowMode g_BowMode[MAXPLAYERS + 1];

/**
 * Initialize the trails system.
 */
void Trails_Init()
{
    // Create ConVars
    g_cvTrailsEnabled = CreateConVar("sm_hub_trails_enabled", "1", "Enables the trails system.", 0, true, 0.0, true, 1.0);
    g_cvForceCheapTrails = CreateConVar("sm_hub_trails_force_cheap", "0", "Forces all trails to be cheap (lower quality).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvRemoveOnRespawn = CreateConVar("sm_hub_trails_remove_on_respawn", "0", "Removes trail after respawning.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvAllowHide = CreateConVar("sm_hub_trails_allow_hide", "1", "Allows hiding other players' trails.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    // Register commands
    RegConsoleCmd("sm_trail", Command_Trail, "Opens the trails menu");
    RegConsoleCmd("sm_trails", Command_Trail, "Opens the trails menu");
    RegConsoleCmd("sm_hidetrail", Command_HideTrail, "Toggles hiding other players' trails");
    RegConsoleCmd("sm_trailinfo", Command_TrailInfo, "Shows debug info about your current trail");
    
    // Register cosmetic
    Cosmetics_Register(Cosmetic_Trail, "Hub_Cosmetics_Trails", "trails");
    
    // Hook player spawn
    HookEvent("player_spawn", Event_PlayerSpawn_Trails);
    
    LogMessage("[HubCore] Trails system initialized");
}

/**
 * Load hiding preference for a client.
 * Called when cookies are cached or changed.
 */
void Trails_LoadHidingPreference(int client)
{
	if (!IsValidPlayer(client))
	{
		return;
	}
	
	Cookie hideTrailsCookie = GetCookieByName(HUB_COOKIE_TRAIL_HIDING);
	if (hideTrailsCookie != null)
	{
		g_IsHidingTrails[client] = GetCookieValue(client, hideTrailsCookie) == 1;
	}
}

/**
 * Register trails natives.
 */
void Trails_RegisterNatives()
{
    CreateNative("Trails_GetPlayerTrail", Native_Trails_GetPlayerTrail);
    CreateNative("Trails_SetPlayerTrail", Native_Trails_SetPlayerTrail);
    CreateNative("Trails_ClearPlayerTrail", Native_Trails_ClearPlayerTrail);
    CreateNative("Trails_ToggleHideTrails", Native_Trails_ToggleHideTrails);
    CreateNative("Trails_IsHidingTrails", Native_Trails_IsHidingTrails);
    CreateNative("Trails_OpenMenu", Native_Trails_OpenMenu);
}

/**
 * Called on map start.
 */
void Trails_OnMapStart()
{
    // Load trails config
    if (!Trails_LoadConfig())
    {
        LogError("[HubCore] Failed to load trails config from %s", TRAILS_CONFIG_PATH);
    }
    else
    {
        LogMessage("[HubCore] Loaded %d trails from config", g_TrailsCount);
    }
    
    bool hasCustomBeam = FileExists(TRAILS_BEAM_SPRITE_VMT, true) && FileExists(TRAILS_BEAM_SPRITE_VTF, true);

    if (hasCustomBeam)
    {
        g_BeamSprite = PrecacheModel(TRAILS_BEAM_SPRITE_VMT, true);
        AddFileToDownloadsTable(TRAILS_BEAM_SPRITE_VMT);
        AddFileToDownloadsTable(TRAILS_BEAM_SPRITE_VTF);
    }
    else
    {
        g_BeamSprite = 0;
    }

    // Fallback to a built-in sprite if custom materials are missing/case-mismatched (common on Linux).
    if (g_BeamSprite <= 0)
    {
        g_BeamSprite = PrecacheModel(TRAILS_BEAM_SPRITE_FALLBACK, true);
        LogMessage("[HubCore] Trails using fallback sprite: %s", TRAILS_BEAM_SPRITE_FALLBACK);
    }

    if (g_BeamSprite <= 0)
    {
        LogError("[HubCore] Trails failed to precache any beam sprite. Trails will be invisible.");
    }
}

/**
 * Load trails from config file.
 * 
 * @return               True on success
 */
bool Trails_LoadConfig()
{
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, PLATFORM_MAX_PATH, TRAILS_CONFIG_PATH);
    
    KeyValues kv = new KeyValues("trails-list");
    
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
    
    g_TrailsCount = 0;
    
    do
    {
        if (g_TrailsCount >= TRAILS_MAX_COUNT)
        {
            LogError("[HubCore] Maximum trails count reached (%d)", TRAILS_MAX_COUNT);
            break;
        }
        
        // Basic parameters
        kv.GetString("name", g_Trails[g_TrailsCount].name, sizeof(g_Trails[].name), "<MISSING TRAIL NAME>");
        
        g_Trails[g_TrailsCount].colorType = view_as<TrailColorType>(kv.GetNum("color_type", 0));
        
        if (view_as<int>(g_Trails[g_TrailsCount].colorType) < 0 || 
            view_as<int>(g_Trails[g_TrailsCount].colorType) >= view_as<int>(TrailColorType_MAX))
        {
            g_Trails[g_TrailsCount].colorType = TrailColorType_SolidColor;
        }
        
        g_Trails[g_TrailsCount].color.r = kv.GetNum("red", 0);
        g_Trails[g_TrailsCount].color.g = kv.GetNum("green", 0);
        g_Trails[g_TrailsCount].color.b = kv.GetNum("blue", 0);
        g_Trails[g_TrailsCount].color.a = kv.GetNum("alpha", 255);
        
        Trails_NormalizeColor(g_Trails[g_TrailsCount].color);
        
        g_Trails[g_TrailsCount].width = kv.GetFloat("width", 1.5);
        if (g_Trails[g_TrailsCount].width < 0.0)
        {
            g_Trails[g_TrailsCount].width = 0.0;
        }
        
        g_Trails[g_TrailsCount].duration = kv.GetFloat("duration", 1.5);
        if (g_Trails[g_TrailsCount].duration < 0.0)
        {
            g_Trails[g_TrailsCount].duration = 0.0;
        }
        
        g_Trails[g_TrailsCount].isCheap = kv.GetNum("cheap", 0) > 0;
        g_Trails[g_TrailsCount].isAdminsOnly = kv.GetNum("admins_only", 0) > 0;
        
        // Special effect parameters
        g_Trails[g_TrailsCount].spectrumCycleSpeed = kv.GetNum("spectrum_cycle_speed", 1);
        Trails_NormalizeChannel(g_Trails[g_TrailsCount].spectrumCycleSpeed);
        
        g_Trails[g_TrailsCount].breathingSpeed = kv.GetNum("breathing_speed", 1);
        Trails_NormalizeChannel(g_Trails[g_TrailsCount].breathingSpeed);
        
        g_Trails[g_TrailsCount].bowTransformSpeed = kv.GetFloat("bow_transform_speed", 0.1);
        if (g_Trails[g_TrailsCount].bowTransformSpeed < 0.01)
        {
            g_Trails[g_TrailsCount].bowTransformSpeed = 0.01;
        }
        
        g_Trails[g_TrailsCount].breathingMinAlpha = kv.GetNum("breathing_min_alpha", g_Trails[g_TrailsCount].color.a);
        Trails_NormalizeChannel(g_Trails[g_TrailsCount].breathingMinAlpha);
        
        g_Trails[g_TrailsCount].breathingMaxAlpha = kv.GetNum("breathing_max_alpha", g_Trails[g_TrailsCount].color.a);
        Trails_NormalizeChannel(g_Trails[g_TrailsCount].breathingMaxAlpha);
        
        if (g_Trails[g_TrailsCount].breathingMinAlpha > g_Trails[g_TrailsCount].breathingMaxAlpha)
        {
            g_Trails[g_TrailsCount].breathingMaxAlpha = g_Trails[g_TrailsCount].breathingMinAlpha;
        }
        
        g_Trails[g_TrailsCount].bowMinWidth = kv.GetFloat("bow_min_width", g_Trails[g_TrailsCount].width);
        if (g_Trails[g_TrailsCount].bowMinWidth < 0.0)
        {
            g_Trails[g_TrailsCount].bowMinWidth = 0.0;
        }
        
        g_Trails[g_TrailsCount].bowMaxWidth = kv.GetFloat("bow_max_width", g_Trails[g_TrailsCount].width);
        if (g_Trails[g_TrailsCount].bowMinWidth > g_Trails[g_TrailsCount].bowMaxWidth)
        {
            g_Trails[g_TrailsCount].bowMaxWidth = g_Trails[g_TrailsCount].bowMinWidth;
        }
        
        g_TrailsCount++;
    }
    while (kv.GotoNextKey());
    
    delete kv;
    return true;
}

/**
 * Event handler for player spawn.
 */
public void Event_PlayerSpawn_Trails(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    // Initialize last position to current position to avoid distance check issues on first frame
    float origin[3];
    GetClientAbsOrigin(client, origin);
    g_LastPosition[client] = origin;
    
    // Reset trail on respawn if enabled
    if (g_cvRemoveOnRespawn != null && g_cvRemoveOnRespawn.BoolValue)
    {
        Trails_RemoveTrail(client);
    }
}

/**
 * Command handler for /sm_trail
 */
public Action Command_Trail(int client, int args)
{
    if (!g_cvTrailsEnabled.BoolValue || !IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    ShowTrailsMenu(client, 0);
    return Plugin_Handled;
}

/**
 * Command handler for /sm_hidetrail
 */
public Action Command_HideTrail(int client, int args)
{
    if (!g_cvTrailsEnabled.BoolValue || !g_cvAllowHide.BoolValue || !IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    g_IsHidingTrails[client] = !g_IsHidingTrails[client];
    
    // Save preference to cookie
    Cookie hideTrailsCookie = GetCookieByName(HUB_COOKIE_TRAIL_HIDING);
    if (hideTrailsCookie != null)
    {
        SetCookieValue(client, hideTrailsCookie, g_IsHidingTrails[client] ? "1" : "0");
    }
    
    // Print message
    if (g_IsHidingTrails[client])
    {
        CPrintToChat(client, "%t", "Hub_Cosmetics_Trails_Hidden");
    }
    else
    {
        CPrintToChat(client, "%t", "Hub_Cosmetics_Trails_Visible");
    }
    
    return Plugin_Handled;
}

/**
 * Command handler for /sm_trailinfo
 */
public Action Command_TrailInfo(int client, int args)
{
    if (!IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    PrintToChat(client, "[Trails Debug]");
    PrintToChat(client, "Trails Enabled: %s", g_cvTrailsEnabled.BoolValue ? "Yes" : "No");
    PrintToChat(client, "Selected Trail Index: %d", g_SelectedTrail[client]);
    PrintToChat(client, "Total Trails Loaded: %d", g_TrailsCount);
    PrintToChat(client, "Is Hiding Trails: %s", g_IsHidingTrails[client] ? "Yes" : "No");
    PrintToChat(client, "Is Alive: %s", IsPlayerAlive(client) ? "Yes" : "No");
    PrintToChat(client, "Beam Sprite Index: %d", g_BeamSprite);
    
    if (g_SelectedTrail[client] >= 0 && g_SelectedTrail[client] < g_TrailsCount)
    {
        PrintToChat(client, "Trail Name: %s", g_Trails[g_SelectedTrail[client]].name);
        PrintToChat(client, "Trail Type: %d", g_Trails[g_SelectedTrail[client]].colorType);
        PrintToChat(client, "Is Cheap: %s", g_Trails[g_SelectedTrail[client]].isCheap ? "Yes" : "No");
    }
    
    float pos[3];
    GetClientAbsOrigin(client, pos);
    PrintToChat(client, "Current Pos: %.1f, %.1f, %.1f", pos[0], pos[1], pos[2]);
    PrintToChat(client, "Last Pos: %.1f, %.1f, %.1f", g_LastPosition[client][0], g_LastPosition[client][1], g_LastPosition[client][2]);
    
    float dist = GetVectorDistance(pos, g_LastPosition[client], false);
    PrintToChat(client, "Distance: %.2f", dist);
    
    return Plugin_Handled;
}

/**
 * Show the trails menu.
 * 
 * @param client         Client index
 * @param page           Menu page to display
 */
void ShowTrailsMenu(int client, int page)
{
    MenuHistory_Push(client, MenuType_CosmeticsTrails, 0);
    
    Menu menu = new Menu(MenuHandler_Trails);
    menu.ExitBackButton = true;
    
    menu.SetTitle("%t", "Hub_Cosmetics_Trails_Title");
    
    // Add "None" option
    char noneInfo[8];
    IntToString(TRAILS_NONE, noneInfo, sizeof(noneInfo));
    menu.AddItem(noneInfo, "None", (g_SelectedTrail[client] == TRAILS_NONE) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    
    // Add available trails
    for (int i = 0; i < g_TrailsCount; i++)
    {
        // Skip empty/null trails (spacers)
        if (strlen(g_Trails[i].name) == 0 ||
            StrEqual(g_Trails[i].name, "\\0") ||
            StrEqual(g_Trails[i].name, "{null}", false) ||
            StrEqual(g_Trails[i].name, "{empty}", false))
        {
            menu.AddItem("", "", ITEMDRAW_SPACER);
            continue;
        }
        
        // Check admin-only
        if (g_Trails[i].isAdminsOnly && !IsClientAdmin(client))
        {
            continue;
        }
        
        char info[8];
        IntToString(i, info, sizeof(info));
        
        // Check if player owns this trail
        bool hasItem = Hub_HasPlayerItemName(client, "Trails", g_Trails[i].name) > 0;
        
        if (hasItem)
        {
            int style = (g_SelectedTrail[client] == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            menu.AddItem(info, g_Trails[i].name, style);
        }
    }
    
    menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

/**
 * Menu handler for trails menu.
 */
public int MenuHandler_Trails(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));
            
            int choice = StringToInt(info);
            Trails_SelectTrail(param1, choice);
            
            // Reopen menu
            ShowTrailsMenu(param1, GetMenuSelectionPosition());
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
 * Select a trail for a player.
 * 
 * @param client         Client index
 * @param trailIndex     Trail index (-1 for none)
 */
void Trails_SelectTrail(int client, int trailIndex)
{
    // Get old trail for forward
    int oldTrail = g_SelectedTrail[client];
    
    if (trailIndex == TRAILS_NONE)
    {
        // Disable trail
        Trails_DisableAllSpecialEffects(client);
        g_SelectedTrail[client] = TRAILS_NONE;
        
        // Clear selection in database
        Selections_ClearPlayer(client, SELECTION_TRAIL);
        
        CPrintToChat(client, "%t", "Hub_Cosmetics_Trails_Disabled");
    }
    else if (trailIndex >= 0 && trailIndex < g_TrailsCount)
    {
        // Enable trail
        g_SelectedTrail[client] = trailIndex;
        Trails_UpdateSpecialEffectModes(client, trailIndex);
        
        // Save selection to database
        JSON_Object trailData = new JSON_Object();
        trailData.SetInt("id", trailIndex);
        trailData.SetString("name", g_Trails[trailIndex].name);
        
        Selections_SetPlayer(client, SELECTION_TRAIL, trailData);
        
        CPrintToChat(client, "%t", "Hub_Cosmetics_Trails_Selected", g_Trails[trailIndex].name);
    }
    
    // Fire forward
    Cosmetics_FireTrailChanged(client, oldTrail, g_SelectedTrail[client]);
}

/**
 * Remove a player's trail.
 * 
 * @param client         Client index
 */
void Trails_RemoveTrail(int client)
{
    g_SelectedTrail[client] = TRAILS_NONE;
    Trails_DisableAllSpecialEffects(client);
}

/**
 * Apply a player's saved trail selection.
 * Called when player loads.
 * 
 * @param client         Client index
 */
void Trails_ApplySelection(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    // Load hide preference
    Trails_LoadHidingPreference(client);
    
    // Get saved selection
    JSON_Object trailData = Selections_GetPlayer(client, SELECTION_TRAIL);
    
    if (trailData == null)
    {
        g_SelectedTrail[client] = TRAILS_NONE;
        return;
    }
    
    // Get trail info - support both new format (name) and legacy format (value)
    char trailName[255];
    trailData.GetString("name", trailName, sizeof(trailName));
    int trailId = trailData.GetInt("id", -1);
    
    // Fallback to "value" field if "name" is empty (from database load)
    if (strlen(trailName) == 0 && trailData.HasKey("value"))
    {
        trailData.GetString("value", trailName, sizeof(trailName));
    }
    
    json_cleanup_and_delete(trailData);
    
    if (strlen(trailName) == 0)
    {
        g_SelectedTrail[client] = TRAILS_NONE;
        return;
    }
    
    // Find the trail in our loaded config
    int foundIndex = -1;
    for (int i = 0; i < g_TrailsCount; i++)
    {
        if (StrEqual(g_Trails[i].name, trailName))
        {
            foundIndex = i;
            break;
        }
    }
    
    // Use saved ID if we couldn't find by name
    if (foundIndex == -1 && trailId >= 0 && trailId < g_TrailsCount)
    {
        foundIndex = trailId;
    }
    
    if (foundIndex == -1)
    {
        g_SelectedTrail[client] = TRAILS_NONE;
        return;
    }
    
    g_SelectedTrail[client] = foundIndex;
    
    // Note: We don't check ownership here because inventory may not be loaded yet
    // when this is called on player join. Ownership is verified when opening
    // the cosmetics menu or when selecting a new cosmetic.
    
    // Apply the trail effects
    Trails_UpdateSpecialEffectModes(client, foundIndex);
}

/**
 * Called every frame for trail rendering.
 * Hook OnPlayerRunCmd for this.
 */
void Trails_OnPlayerRunCmd(int client)
{
    if (!g_cvTrailsEnabled.BoolValue)
    {
        return;
    }
    
    int choice = g_SelectedTrail[client];
    
    if (choice == TRAILS_NONE || choice < 0 || choice >= g_TrailsCount)
    {
        return;
    }
    
    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    // Check for cloaked spy
    if (TF2_IsPlayerInCondition(client, TFCond_Cloaked))
    {
        return;
    }
    
    // Draw the trail
    if (g_Trails[choice].isCheap || (g_cvForceCheapTrails != null && g_cvForceCheapTrails.BoolValue))
    {
        Trails_DrawCheapTrail(client, choice);
    }
    else
    {
        Trails_DrawExpensiveTrail(client, choice);
    }
}

/**
 * Draw a cheap trail (skips every other frame).
 * 
 * @param client         Client index
 * @param trailIndex     Trail index
 */
void Trails_DrawCheapTrail(int client, int trailIndex)
{
    float playerOrigin[3];
    GetClientAbsOrigin(client, playerOrigin);
    
    if (g_IsOddFrame[client])
    {
        // First frame: cache origin
        g_LastPosition[client] = playerOrigin;
        g_IsOddFrame[client] = false;
    }
    else
    {
        // Second frame: render beam
        g_IsOddFrame[client] = true;
        Trails_CreatePlayerTrail(client, trailIndex, playerOrigin, g_LastPosition[client]);
    }
}

/**
 * Draw an expensive trail (every frame).
 * 
 * @param client         Client index
 * @param trailIndex     Trail index
 */
void Trails_DrawExpensiveTrail(int client, int trailIndex)
{
    float playerOrigin[3];
    GetClientAbsOrigin(client, playerOrigin);
    
    Trails_CreatePlayerTrail(client, trailIndex, playerOrigin, g_LastPosition[client]);
    
    // Update last position AFTER rendering
    g_LastPosition[client] = playerOrigin;
}

/**
 * Create the player's trail beam.
 * 
 * @param client         Client index
 * @param trailIndex     Trail index
 * @param playerOrigin   Current player position
 * @param secondPoint    Previous position
 */
void Trails_CreatePlayerTrail(int client, int trailIndex, float playerOrigin[3], float secondPoint[3])
{
	// Check for teleportation first
	bool hasClientTeleported = GetVectorDistance(playerOrigin, secondPoint, false) > 50.0;
	
	if (!g_cvTrailsEnabled.BoolValue || g_SelectedTrail[client] == TRAILS_NONE || !IsPlayerAlive(client) || hasClientTeleported || g_BeamSprite <= 0)
	{
		return;
	}
    
    g_DynamicColor[client].a = g_Trails[trailIndex].color.a;
    
    // Calculate start and end points
    float start[3], end[3];
    start[0] = playerOrigin[0];
    start[1] = playerOrigin[1];
    start[2] = playerOrigin[2] + TRAILS_GROUND_OFFSET;
    
    end[0] = secondPoint[0];
    end[1] = secondPoint[1];
    end[2] = secondPoint[2] + TRAILS_GROUND_OFFSET;
    
    // Get client-specific color
    TrailColor cColor;
    Trails_GetClientColor(client, trailIndex, cColor);
    
    int iColor[4];
    iColor[0] = cColor.r;
    iColor[1] = cColor.g;
    iColor[2] = cColor.b;
    iColor[3] = cColor.a;
    
    // Get client-specific width
    float width;
    Trails_GetClientWidth(client, trailIndex, width);
    
    // Setup beam
    TE_SetupBeamPoints(start, end, g_BeamSprite, 0, 0, 0, g_Trails[trailIndex].duration, width, width, 10, 0.0, iColor, 0);
    
    // Send to receivers
    Trails_SendTempEntity(client);
}

/**
 * Get the client-specific trail color.
 * 
 * @param client         Client index
 * @param trailIndex     Trail index
 * @param buffer         Color buffer to fill
 */
void Trails_GetClientColor(int client, int trailIndex, TrailColor buffer)
{
    switch (g_Trails[trailIndex].colorType)
    {
        case TrailColorType_SpectrumCycle:
        {
            Trails_DoSpectrumCycle(g_DynamicColor[client], g_SpectrumCycleMode[client], g_Trails[trailIndex].spectrumCycleSpeed);
            buffer.r = g_DynamicColor[client].r;
            buffer.g = g_DynamicColor[client].g;
            buffer.b = g_DynamicColor[client].b;
            buffer.a = g_DynamicColor[client].a;
        }
        case TrailColorType_VelocityBased:
        {
            float absVelocity[3];
            GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", absVelocity);
            float playerSpeed = SquareRoot(Pow(absVelocity[0], 2.0) + Pow(absVelocity[1], 2.0));
            
            Trails_SpeedToColor(buffer, playerSpeed);
            buffer.a = g_Trails[trailIndex].color.a;
        }
        default:
        {
            buffer.r = g_Trails[trailIndex].color.r;
            buffer.g = g_Trails[trailIndex].color.g;
            buffer.b = g_Trails[trailIndex].color.b;
            buffer.a = g_Trails[trailIndex].color.a;
        }
    }
    
    // Apply breathing effect
    if (Trails_IsBreathingTrail(trailIndex))
    {
        Trails_DoColorBreathing(g_DynamicAlpha[client], g_BreathingMode[client], 
            g_Trails[trailIndex].breathingMinAlpha, g_Trails[trailIndex].breathingMaxAlpha, 
            g_Trails[trailIndex].breathingSpeed);
        buffer.a = g_DynamicAlpha[client];
    }
}

/**
 * Get the client-specific trail width.
 * 
 * @param client         Client index
 * @param trailIndex     Trail index
 * @param buffer         Width buffer to fill
 */
void Trails_GetClientWidth(int client, int trailIndex, float& buffer)
{
    if (Trails_IsBowTrail(trailIndex))
    {
        Trails_DoBowResizeCycle(g_DynamicWidth[client], g_BowMode[client],
            g_Trails[trailIndex].bowMinWidth, g_Trails[trailIndex].bowMaxWidth,
            g_Trails[trailIndex].bowTransformSpeed);
        buffer = g_DynamicWidth[client];
    }
    else
    {
        buffer = g_Trails[trailIndex].width;
    }
}

/**
 * Send the temp entity to appropriate receivers.
 * 
 * @param client         Client index (the player whose trail is being rendered)
 */
void Trails_SendTempEntity(int client)
{
    int receivers[MAXPLAYERS + 1];
    int receiverCount = 0;
    
    // Get all players who are not hiding trails
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidPlayer(i) && !g_IsHidingTrails[i])
        {
            receivers[receiverCount++] = i;
        }
    }
    
    // If the trail owner is hiding trails, add them so they can still see their own trail
    if (g_IsHidingTrails[client])
    {
        receivers[receiverCount++] = client;
        TE_Send(receivers, receiverCount);
    }
    else
    {
        // Otherwise just send to all non-hiding players (which already includes the owner)
        if (receiverCount > 0)
        {
            TE_Send(receivers, receiverCount);
        }
    }
}

/**
 * Update special effect modes for a trail.
 * 
 * @param client         Client index
 * @param trailIndex     Trail index
 */
void Trails_UpdateSpecialEffectModes(int client, int trailIndex)
{
    if (trailIndex < 0 || trailIndex >= g_TrailsCount)
    {
        return;
    }
    
    // Spectrum cycle
    if (g_Trails[trailIndex].colorType == TrailColorType_SpectrumCycle)
    {
        g_DynamicColor[client].r = 0;
        g_DynamicColor[client].g = 0;
        g_DynamicColor[client].b = 0;
        g_SpectrumCycleMode[client] = TrailSpectrumCycleMode_RedToYellow;
    }
    else
    {
        g_SpectrumCycleMode[client] = TrailSpectrumCycleMode_Off;
    }
    
    // Breathing
    if (Trails_IsBreathingTrail(trailIndex))
    {
        g_DynamicColor[client].a = g_Trails[trailIndex].breathingMinAlpha;
        g_DynamicAlpha[client] = g_Trails[trailIndex].breathingMinAlpha;
        g_BreathingMode[client] = TrailBreathingMode_Inhale;
    }
    else
    {
        g_BreathingMode[client] = TrailBreathingMode_Off;
    }
    
    // Bow
    if (Trails_IsBowTrail(trailIndex))
    {
        g_DynamicWidth[client] = g_Trails[trailIndex].bowMinWidth;
        g_BowMode[client] = TrailBowMode_Expand;
    }
    else
    {
        g_BowMode[client] = TrailBowMode_Off;
    }
}

/**
 * Disable all special effects for a player.
 * 
 * @param client         Client index
 */
void Trails_DisableAllSpecialEffects(int client)
{
    g_SpectrumCycleMode[client] = TrailSpectrumCycleMode_Off;
    g_BreathingMode[client] = TrailBreathingMode_Off;
    g_BowMode[client] = TrailBowMode_Off;
}

/**
 * Handle player disconnect.
 * 
 * @param client         Client index
 */
void Trails_OnClientDisconnect(int client)
{
    g_SelectedTrail[client] = TRAILS_NONE;
    g_IsHidingTrails[client] = false;
    g_IsOddFrame[client] = false;
    
    // Reset last position
    float zeroVec[3];
    g_LastPosition[client] = zeroVec;
    
    Trails_DisableAllSpecialEffects(client);
}

// ============================================================================
// Inventory Integration Helper Functions
// ============================================================================

/**
 * Apply a trail by name (for inventory equipping).
 * 
 * @param client         Client index
 * @param trailName      Name of the trail to apply
 * @return               True on success
 */
bool Trails_ApplyByName(int client, const char[] trailName)
{
    if (!IsValidPlayer(client) || strlen(trailName) == 0)
    {
        return false;
    }
    
    // Find the trail by name
    for (int i = 0; i < g_TrailsCount; i++)
    {
        if (StrEqual(g_Trails[i].name, trailName, false))
        {
            Trails_SelectTrail(client, i);
            return true;
        }
    }
    
    return false;
}

/**
 * Clear a player's trail (for inventory unequipping).
 * 
 * @param client         Client index
 */
void Trails_Clear(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    Trails_SelectTrail(client, TRAILS_NONE);
}

// ============================================================================
// Special Effect Functions
// ============================================================================

/**
 * Check if a trail has breathing effect.
 */
bool Trails_IsBreathingTrail(int trailIndex)
{
    return g_Trails[trailIndex].breathingMinAlpha != g_Trails[trailIndex].breathingMaxAlpha;
}

/**
 * Check if a trail has bow effect.
 */
bool Trails_IsBowTrail(int trailIndex)
{
    return g_Trails[trailIndex].bowMinWidth != g_Trails[trailIndex].bowMaxWidth;
}

/**
 * Normalize a color value.
 */
void Trails_NormalizeColor(TrailColor color)
{
    Trails_NormalizeChannel(color.r);
    Trails_NormalizeChannel(color.g);
    Trails_NormalizeChannel(color.b);
    Trails_NormalizeChannel(color.a);
}

/**
 * Normalize a color channel value.
 */
void Trails_NormalizeChannel(int& channel)
{
    if (channel < 0)
    {
        channel = 0;
    }
    else if (channel > 255)
    {
        channel = 255;
    }
}

/**
 * Perform spectrum cycle effect.
 */
void Trails_DoSpectrumCycle(TrailColor buffer, TrailSpectrumCycleMode& mode, int stepSize = 1)
{
    switch (mode)
    {
        case TrailSpectrumCycleMode_RedToYellow:
        {
            buffer.r = 255;
            buffer.g += stepSize;
            buffer.b = 0;
            
            if (buffer.r >= 255 && buffer.g >= 255 && buffer.b <= 0)
            {
                mode = TrailSpectrumCycleMode_YellowToGreen;
            }
        }
        case TrailSpectrumCycleMode_YellowToGreen:
        {
            buffer.r -= stepSize;
            buffer.g = 255;
            buffer.b = 0;
            
            if (buffer.r <= 0 && buffer.g >= 255 && buffer.b <= 0)
            {
                mode = TrailSpectrumCycleMode_GreenToCyan;
            }
        }
        case TrailSpectrumCycleMode_GreenToCyan:
        {
            buffer.r = 0;
            buffer.g = 255;
            buffer.b += stepSize;
            
            if (buffer.r <= 0 && buffer.g >= 255 && buffer.b >= 255)
            {
                mode = TrailSpectrumCycleMode_CyanToBlue;
            }
        }
        case TrailSpectrumCycleMode_CyanToBlue:
        {
            buffer.r = 0;
            buffer.g -= stepSize;
            buffer.b = 255;
            
            if (buffer.r <= 0 && buffer.g <= 0 && buffer.b >= 255)
            {
                mode = TrailSpectrumCycleMode_BlueToMagenta;
            }
        }
        case TrailSpectrumCycleMode_BlueToMagenta:
        {
            buffer.r += stepSize;
            buffer.g = 0;
            buffer.b = 255;
            
            if (buffer.r >= 255 && buffer.g <= 0 && buffer.b >= 255)
            {
                mode = TrailSpectrumCycleMode_MagentaToRed;
            }
        }
        case TrailSpectrumCycleMode_MagentaToRed:
        {
            buffer.r = 255;
            buffer.g = 0;
            buffer.b -= stepSize;
            
            if (buffer.r >= 255 && buffer.g <= 0 && buffer.b <= 0)
            {
                mode = TrailSpectrumCycleMode_RedToYellow;
            }
        }
    }
    
    Trails_NormalizeColor(buffer);
}

/**
 * Convert speed to color for velocity-based trails.
 */
void Trails_SpeedToColor(TrailColor buffer, float speed)
{
    int fullStep = 255;
    
    if (speed <= fullStep)
    {
        buffer.r = 0;
        buffer.g = 0;
        buffer.b = 255;
    }
    else if (speed > fullStep && speed <= 2 * fullStep)
    {
        buffer.r = 0;
        buffer.g = RoundToFloor(speed) - fullStep;
        buffer.b = 255;
    }
    else if (speed > 2 * fullStep && speed <= 3 * fullStep)
    {
        buffer.r = 0;
        buffer.g = 255;
        buffer.b = 255 - (RoundToFloor(speed) - 2 * fullStep);
    }
    else if (speed > 3 * fullStep && speed <= 4 * fullStep)
    {
        buffer.r = RoundToFloor(speed) - 3 * fullStep;
        buffer.g = 255;
        buffer.b = 0;
    }
    else if (speed > 4 * fullStep && speed <= 5 * fullStep)
    {
        buffer.r = 255;
        buffer.g = 255 - (RoundToFloor(speed) - 4 * fullStep);
        buffer.b = 0;
    }
    else if (speed > 5 * fullStep && speed <= 6 * fullStep)
    {
        buffer.r = 255;
        buffer.g = 0;
        buffer.b = RoundToFloor(speed) - 5 * fullStep;
    }
    else if (speed > 6 * fullStep && speed <= 6.5 * fullStep)
    {
        buffer.r = 255 - (RoundToFloor(speed) - 6 * fullStep);
        buffer.g = 0;
        buffer.b = 255;
    }
    else
    {
        buffer.r = 128;
        buffer.g = 0;
        buffer.b = 255;
    }
    
    Trails_NormalizeColor(buffer);
}

/**
 * Perform color breathing effect.
 */
void Trails_DoColorBreathing(int& alpha, TrailBreathingMode& mode, int minAlpha, int maxAlpha, int stepSize = 1)
{
    switch (mode)
    {
        case TrailBreathingMode_Inhale:
        {
            alpha += stepSize;
            
            if (alpha >= maxAlpha)
            {
                alpha = maxAlpha;
                mode = TrailBreathingMode_Exhale;
            }
        }
        case TrailBreathingMode_Exhale:
        {
            alpha -= stepSize;
            
            if (alpha <= minAlpha)
            {
                alpha = minAlpha;
                mode = TrailBreathingMode_Inhale;
            }
        }
    }
}

/**
 * Perform bow resize cycle effect.
 */
void Trails_DoBowResizeCycle(float& buffer, TrailBowMode& mode, float minWidth, float maxWidth, float stepSize = 0.1)
{
    switch (mode)
    {
        case TrailBowMode_Expand:
        {
            buffer += stepSize;
            
            if (buffer >= maxWidth)
            {
                buffer = maxWidth;
                mode = TrailBowMode_Shrink;
            }
        }
        case TrailBowMode_Shrink:
        {
            buffer -= stepSize;
            
            if (buffer <= minWidth)
            {
                buffer = minWidth;
                mode = TrailBowMode_Expand;
            }
        }
    }
}

/**
 * Check if client is an admin.
 */
bool IsClientAdmin(int client)
{
    return CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false);
}

// ============================================================================
// Natives Implementation
// ============================================================================

public int Native_Trails_GetPlayerTrail(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int maxlen = GetNativeCell(3);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    if (g_SelectedTrail[client] >= 0 && g_SelectedTrail[client] < g_TrailsCount)
    {
        SetNativeString(2, g_Trails[g_SelectedTrail[client]].name, maxlen);
        return true;
    }
    
    SetNativeString(2, "", maxlen);
    return false;
}

public int Native_Trails_SetPlayerTrail(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char trailName[255];
    GetNativeString(2, trailName, sizeof(trailName));
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    // Find trail by name
    for (int i = 0; i < g_TrailsCount; i++)
    {
        if (StrEqual(g_Trails[i].name, trailName))
        {
            Trails_SelectTrail(client, i);
            return true;
        }
    }
    
    return false;
}

public int Native_Trails_ClearPlayerTrail(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    Trails_SelectTrail(client, TRAILS_NONE);
    return true;
}

public int Native_Trails_ToggleHideTrails(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    g_IsHidingTrails[client] = !g_IsHidingTrails[client];
    return g_IsHidingTrails[client];
}

public int Native_Trails_IsHidingTrails(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        return false;
    }
    
    return g_IsHidingTrails[client];
}

public int Native_Trails_OpenMenu(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (!IsValidPlayer(client))
    {
        return 0;
    }
    
    ShowTrailsMenu(client, 0);
    return 0;
}
