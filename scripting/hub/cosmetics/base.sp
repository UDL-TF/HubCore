/**
 * HubCore Cosmetics Base System
 * 
 * Provides the base cosmetics menu and registration system.
 * Individual cosmetics (tags, trails, footprints, spawn particles) are implemented
 * in their respective files and registered with this system.
 */

#include <hub-cosmetics>

// Registered cosmetics
CosmeticInfo g_RegisteredCosmetics[Cosmetic_MAX];
int g_RegisteredCosmeticsCount = 0;

// Forward handles
Handle g_hOnTagChanged = INVALID_HANDLE;
Handle g_hOnTrailChanged = INVALID_HANDLE;
Handle g_hOnFootprintChanged = INVALID_HANDLE;
Handle g_hOnSpawnParticleChanged = INVALID_HANDLE;

/**
 * Initialize the cosmetics base system.
 */
void Cosmetics_Init()
{
    // Create forwards
    g_hOnTagChanged = CreateGlobalForward(
        "Cosmetics_OnTagChanged",
        ET_Ignore,
        Param_Cell,       // client
        Param_String,     // oldTag
        Param_String      // newTag
    );
    
    g_hOnTrailChanged = CreateGlobalForward(
        "Cosmetics_OnTrailChanged",
        ET_Ignore,
        Param_Cell,       // client
        Param_Cell,       // oldTrailId
        Param_Cell        // newTrailId
    );
    
    g_hOnFootprintChanged = CreateGlobalForward(
        "Cosmetics_OnFootprintChanged",
        ET_Ignore,
        Param_Cell,       // client
        Param_Cell,       // oldFootprintId
        Param_Cell        // newFootprintId
    );
    
    g_hOnSpawnParticleChanged = CreateGlobalForward(
        "Cosmetics_OnSpawnParticleChanged",
        ET_Ignore,
        Param_Cell,       // client
        Param_String,     // oldParticle
        Param_String      // newParticle
    );
    
    // Register the cosmetics menu command
    RegConsoleCmd("sm_cosmetics", Command_Cosmetics, "Opens the cosmetics menu");
    
    LogMessage("[HubCore] Cosmetics base system initialized");
}

/**
 * Register a cosmetic type with the system.
 * 
 * @param type           Cosmetic type
 * @param name           Display name
 * @param command        Command to open the cosmetic menu (without sm_)
 */
void Cosmetics_Register(CosmeticType type, const char[] name, const char[] command)
{
    int index = view_as<int>(type);
    
    if (index < 0 || index >= view_as<int>(Cosmetic_MAX))
    {
        LogError("[HubCore] Invalid cosmetic type: %d", index);
        return;
    }
    
    g_RegisteredCosmetics[index].type = type;
    strcopy(g_RegisteredCosmetics[index].name, sizeof(g_RegisteredCosmetics[].name), name);
    strcopy(g_RegisteredCosmetics[index].command, sizeof(g_RegisteredCosmetics[].command), command);
    g_RegisteredCosmetics[index].registered = true;
    
    g_RegisteredCosmeticsCount++;
    
    LogMessage("[HubCore] Registered cosmetic: %s (command: sm_%s)", name, command);
}

/**
 * Check if a cosmetic type is registered.
 * 
 * @param type           Cosmetic type
 * @return               True if registered
 */
bool Cosmetics_IsRegistered(CosmeticType type)
{
    int index = view_as<int>(type);
    
    if (index < 0 || index >= view_as<int>(Cosmetic_MAX))
    {
        return false;
    }
    
    return g_RegisteredCosmetics[index].registered;
}

/**
 * Command handler for /sm_cosmetics
 */
public Action Command_Cosmetics(int client, int args)
{
    if (!IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    ShowCosmeticsMenu(client);
    return Plugin_Handled;
}

/**
 * Show the main cosmetics menu.
 * 
 * @param client         Client index
 */
void ShowCosmeticsMenu(int client)
{
    MenuHistory_Push(client, MenuType_Cosmetics, 0);
    
    Menu menu = new Menu(MenuHandler_Cosmetics, MenuAction_Select | MenuAction_End | MenuAction_DisplayItem);
    menu.ExitBackButton = true;
    
    menu.SetTitle("%t", "Hub_Menu_Cosmetics");
    
    // Add registered cosmetics
    for (int i = 0; i < view_as<int>(Cosmetic_MAX); i++)
    {
        if (g_RegisteredCosmetics[i].registered)
        {
            char info[8];
            IntToString(i, info, sizeof(info));
            menu.AddItem(info, g_RegisteredCosmetics[i].name);
        }
    }
    
    // If no cosmetics registered, show a message
    if (g_RegisteredCosmeticsCount == 0)
    {
        menu.AddItem("", "No cosmetics available", ITEMDRAW_DISABLED);
    }
    
    menu.Display(client, MENU_TIME_FOREVER);
}

/**
 * Menu handler for cosmetics menu.
 */
public int MenuHandler_Cosmetics(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));
            
            int cosmeticIndex = StringToInt(info);
            CosmeticType type = view_as<CosmeticType>(cosmeticIndex);
            
            // Open the specific cosmetic menu
            OpenCosmeticMenu(param1, type);
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
        case MenuAction_DisplayItem:
        {
            char info[8], display[128];
            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
            
            // Translate the display name
            char translated[128];
            Format(translated, sizeof(translated), "%t", display);
            return RedrawMenuItem(translated);
        }
    }
    
    return 0;
}

/**
 * Open a specific cosmetic menu.
 * 
 * @param client         Client index
 * @param type           Cosmetic type
 */
void OpenCosmeticMenu(int client, CosmeticType type)
{
    switch (type)
    {
        case Cosmetic_Tag:
        {
            ShowTagsMenu(client, 0);
        }
        case Cosmetic_Trail:
        {
            ShowTrailsMenu(client, 0);
        }
        case Cosmetic_Footprint:
        {
            ShowFootprintsMenu(client, 0);
        }
        case Cosmetic_SpawnParticle:
        {
            ShowSpawnParticlesMenu(client, 0);
        }
        case Cosmetic_ChatColors:
        {
            Menu_ChatSettings(client);
        }
    }
}

/**
 * Fire the tag changed forward.
 * 
 * @param client         Client index
 * @param oldTag         Old tag value
 * @param newTag         New tag value
 */
void Cosmetics_FireTagChanged(int client, const char[] oldTag, const char[] newTag)
{
    Call_StartForward(g_hOnTagChanged);
    Call_PushCell(client);
    Call_PushString(oldTag);
    Call_PushString(newTag);
    Call_Finish();
}

/**
 * Fire the trail changed forward.
 * 
 * @param client         Client index
 * @param oldTrailId     Old trail ID
 * @param newTrailId     New trail ID
 */
void Cosmetics_FireTrailChanged(int client, int oldTrailId, int newTrailId)
{
    Call_StartForward(g_hOnTrailChanged);
    Call_PushCell(client);
    Call_PushCell(oldTrailId);
    Call_PushCell(newTrailId);
    Call_Finish();
}

/**
 * Fire the footprint changed forward.
 * 
 * @param client         Client index
 * @param oldFootprintId Old footprint ID
 * @param newFootprintId New footprint ID
 */
void Cosmetics_FireFootprintChanged(int client, int oldFootprintId, int newFootprintId)
{
    Call_StartForward(g_hOnFootprintChanged);
    Call_PushCell(client);
    Call_PushCell(oldFootprintId);
    Call_PushCell(newFootprintId);
    Call_Finish();
}

/**
 * Fire the spawn particle changed forward.
 * 
 * @param client         Client index
 * @param oldParticle    Old particle name
 * @param newParticle    New particle name
 */
void Cosmetics_FireSpawnParticleChanged(int client, const char[] oldParticle, const char[] newParticle)
{
    Call_StartForward(g_hOnSpawnParticleChanged);
    Call_PushCell(client);
    Call_PushString(oldParticle);
    Call_PushString(newParticle);
    Call_Finish();
}

/**
 * Called when a player's selections are loaded - apply cosmetics.
 * 
 * @param client         Client index
 */
void Cosmetics_OnPlayerLoaded(int client)
{
    // Tags are applied via CCC callback
    
    // Apply trail if selected
    if (Cosmetics_IsRegistered(Cosmetic_Trail))
    {
        Trails_ApplySelection(client);
    }
    
    // Footprints are applied on spawn event
    
    // Spawn particles are applied on spawn event
}

/**
 * Called when a player spawns - apply spawn-based cosmetics.
 * Note: Currently each cosmetic hooks player_spawn individually.
 * This function is available for future centralization if needed.
 * 
 * @param client         Client index
 */
stock void Cosmetics_OnPlayerSpawn(int client)
{
    // Apply footprint on spawn
    if (Cosmetics_IsRegistered(Cosmetic_Footprint))
    {
        Footprints_ApplySelection(client);
    }
    
    // Apply spawn particle on spawn
    if (Cosmetics_IsRegistered(Cosmetic_SpawnParticle))
    {
        SpawnParticles_ApplySelection(client);
    }
}
