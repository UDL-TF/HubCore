/**
 * HubCore Spawn Particles System
 * 
 * Manages player spawn particle effects.
 * Migrated from SpawnParticlesShop functionality.
 */

// Particle definitions
char g_Particles[][] = {
    "none",
    "achieved",                            // Getting an achievement
    "asplode_hoodoo",                      // Explosion
    "asplode_hoodoo_burning_debris",       // Big explosion, longer debris
    "asplode_hoodoo_debris",               // Just debris
    "bday_1balloon",                       // Just one balloon
    "blood_decap_fountain",                // Blood fountain
    "bonk_text",                           // Bonk!
    "burningplayer_blue",                  // Burning blue
    "burningplayer_red",                   // Burning red
    "cinefx_goldrush",                     // Big explosion
    "coin_blue",                           // Cute blue effect
    "coin_large_blue",                     // Bigger blue effect
    "crutgun_firstperson",                 // Electro boom
    "Explosion_bubbles",                   // Bubbles
    "ExplosionCore_Wall_underwater",       // Bubble explosion
    "ghost_appearation",                   // Ghost effect
    "ghost_firepit",                       // Firepit
    "ghost_firepit_firebits",              // Small firepit
    "ghost_firepit_plate",                 // Plate below
    "halloween_boss_summon",               // Boss summon
    "halloween_ghosts",                    // Small ghosts
    "target_break",                        // Wood explosion
    "target_break_child_puff"              // Wood dust
};

char g_ParticleNames[][] = {
    "None",
    "Achievement",
    "Big Explosion",
    "Biggest Explosion",
    "Debris",
    "One Balloon",
    "Blood Fountain",
    "Bonk!",
    "Burning Blue",
    "Burning Red",
    "Gold Explosion",
    "Coin Blue",
    "Coin Large Blue",
    "Electric Blue",
    "Bubbles",
    "Explosive Bubbles",
    "Purple Explosion",
    "Purple Firepit",
    "Purple Small Firepit",
    "Purple Plate",
    "Legendary Summon",
    "Small Ghosts",
    "Wood Explosion",
    "Wood Dust"
};

int g_ParticlesCount = sizeof(g_Particles);

// Default particle duration in seconds
#define PARTICLE_DURATION 5.0

// Player selected particles
int g_SelectedParticle[MAXPLAYERS + 1] = { 0, ... };  // 0 = none
bool g_IsHidingSpawnParticles[MAXPLAYERS + 1];

// Maps entity index -> owning client for spawn particle entities
// Used in the SetTransmit hook instead of GetEntPropEnt to avoid prop lookup issues
int g_ParticleOwner[2048];

/**
 * Initialize the spawn particles system.
 */
void SpawnParticles_Init()
{
    // Register command
    RegConsoleCmd("sm_sp", Command_SpawnParticles, "Opens the spawn particles menu");
    RegConsoleCmd("sm_spawnparticles", Command_SpawnParticles, "Opens the spawn particles menu");
    
    // Register cosmetic
    Cosmetics_Register(Cosmetic_SpawnParticle, "Hub_Cosmetics_SpawnParticles", "sp");
    
    // Hook player spawn
    HookEvent("player_spawn", Event_PlayerSpawn_SpawnParticles);
    
    LogMessage("[HubCore] Spawn particles system initialized with %d particle types", g_ParticlesCount);
}

/**
 * Load hiding preference for a client.
 * Called when cookies are cached or changed.
 */
void SpawnParticles_LoadHidingPreference(int client)
{
	if (!IsValidPlayer(client))
	{
		return;
	}
	
	Cookie hideParticlesCookie = GetCookieByName(HUB_COOKIE_SPAWN_PARTICLE_HIDING);
	if (hideParticlesCookie != null)
	{
		g_IsHidingSpawnParticles[client] = GetCookieValue(client, hideParticlesCookie) == 1;
	}
}

/**
 * Event handler for player spawn.
 */
public void Event_PlayerSpawn_SpawnParticles(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    // Apply spawn particle after a short delay to ensure player is fully spawned
    CreateTimer(0.1, Timer_SpawnParticle, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * Timer to spawn the particle after player spawn.
 */
public Action Timer_SpawnParticle(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    
    if (!IsValidPlayer(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }
    
    SpawnParticles_ApplySelection(client);
    return Plugin_Stop;
}

/**
 * Command handler for /sm_sp
 */
public Action Command_SpawnParticles(int client, int args)
{
    if (!IsValidPlayer(client))
    {
        return Plugin_Handled;
    }
    
    ShowSpawnParticlesMenu(client, 0);
    return Plugin_Handled;
}

/**
 * Show the spawn particles menu.
 * 
 * @param client         Client index
 * @param page           Menu page to display
 */
void ShowSpawnParticlesMenu(int client, int page)
{
    MenuHistory_Push(client, MenuType_CosmeticsSpawnParticles, 0);
    
    Menu menu = new Menu(MenuHandler_SpawnParticles);
    menu.ExitBackButton = true;
    
    menu.SetTitle("%t", "Hub_Cosmetics_SpawnParticles_Title");
    
    for (int i = 0; i < g_ParticlesCount; i++)
    {
        char info[8];
        IntToString(i, info, sizeof(info));
        
        // First option (None) is always available
        if (i == 0)
        {
            int style = (g_SelectedParticle[client] == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            menu.AddItem(info, g_ParticleNames[i], style);
            continue;
        }
        
        // Check if player owns this particle
        bool hasItem = Hub_HasPlayerItemName(client, "Spawn Particles", g_ParticleNames[i]) > 0;
        
        if (hasItem)
        {
            int style = (g_SelectedParticle[client] == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            menu.AddItem(info, g_ParticleNames[i], style);
        }
        else
        {
            menu.AddItem(info, g_ParticleNames[i], ITEMDRAW_DISABLED);
        }
    }
    
    menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

/**
 * Menu handler for spawn particles menu.
 */
public int MenuHandler_SpawnParticles(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));
            
            int choice = StringToInt(info);
            SpawnParticles_SelectParticle(param1, choice);
            
            // Reopen menu
            ShowSpawnParticlesMenu(param1, GetMenuSelectionPosition());
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
 * Select a spawn particle for a player.
 * 
 * @param client         Client index
 * @param particleIndex  Particle index
 */
void SpawnParticles_SelectParticle(int client, int particleIndex)
{
    if (particleIndex < 0 || particleIndex >= g_ParticlesCount)
    {
        particleIndex = 0;  // None
    }
    
    // Get old particle for forward
    char oldParticle[64] = "";
    if (g_SelectedParticle[client] > 0 && g_SelectedParticle[client] < g_ParticlesCount)
    {
        strcopy(oldParticle, sizeof(oldParticle), g_Particles[g_SelectedParticle[client]]);
    }
    
    // Set new particle
    g_SelectedParticle[client] = particleIndex;
    
    char newParticle[64] = "";
    if (particleIndex > 0)
    {
        strcopy(newParticle, sizeof(newParticle), g_Particles[particleIndex]);
    }
    
    // Save selection to database
    if (particleIndex == 0)
    {
        Selections_ClearPlayer(client, SELECTION_SPAWN_PARTICLE);
    }
    else
    {
        JSON_Object particleData = new JSON_Object();
        particleData.SetInt("id", particleIndex);
        particleData.SetString("name", g_ParticleNames[particleIndex]);
        particleData.SetString("particle", g_Particles[particleIndex]);
        
        Selections_SetPlayer(client, SELECTION_SPAWN_PARTICLE, particleData);
    }
    
    // Fire forward
    Cosmetics_FireSpawnParticleChanged(client, oldParticle, newParticle);
    
    // Print message
    if (particleIndex == 0)
    {
        CPrintToChat(client, "%t", "Hub_Cosmetics_SpawnParticles_Cleared");
    }
    else
    {
        CPrintToChat(client, "%t", "Hub_Cosmetics_SpawnParticles_Selected", g_ParticleNames[particleIndex]);
    }
}

/**
 * Apply a player's saved spawn particle selection.
 * Called on player spawn.
 * 
 * @param client         Client index
 */
void SpawnParticles_ApplySelection(int client)
{
	if (!IsValidPlayer(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	// Load hide preference from cookie
	SpawnParticles_LoadHidingPreference(client);
	
	// If the player wants to hide spawn particles, don't create one on their spawn
	if (g_IsHidingSpawnParticles[client])
	{
		return;
	}
	
	// If we have a selection in memory, apply it
	if (g_SelectedParticle[client] > 0 && g_SelectedParticle[client] < g_ParticlesCount)
	{
		SpawnParticles_CreateParticle(client, g_Particles[g_SelectedParticle[client]], PARTICLE_DURATION);
		return;
	}
	
	// Otherwise, load from database
	JSON_Object particleData = Selections_GetPlayer(client, SELECTION_SPAWN_PARTICLE);
	
	if (particleData == null)
	{
		g_SelectedParticle[client] = 0;
		return;
	}
	
	// Get particle info - support both new format (name, particle) and legacy format (value)
	char particleName[64];
	char particleEffect[64];
	
	// Try new format first
	particleData.GetString("name", particleName, sizeof(particleName));
	particleData.GetString("particle", particleEffect, sizeof(particleEffect));
	int particleId = particleData.GetInt("id", 0);
	
	// Fallback to "value" field if "name" is empty (from database load)
	if (strlen(particleName) == 0 && particleData.HasKey("value"))
	{
		particleData.GetString("value", particleName, sizeof(particleName));
	}
	
	json_cleanup_and_delete(particleData);
	
	if (strlen(particleName) == 0)
	{
		g_SelectedParticle[client] = 0;
		return;
	}
	
	// Find the particle by name
	int foundIndex = -1;
	for (int i = 0; i < g_ParticlesCount; i++)
	{
		if (StrEqual(g_ParticleNames[i], particleName))
		{
			foundIndex = i;
			break;
		}
	}
	
	// Use saved ID if we couldn't find by name
	if (foundIndex == -1 && particleId > 0 && particleId < g_ParticlesCount)
	{
		foundIndex = particleId;
	}
	
	if (foundIndex <= 0)
	{
		g_SelectedParticle[client] = 0;
		return;
	}
	
	g_SelectedParticle[client] = foundIndex;
	
	// Note: We don't check ownership here because inventory may not be loaded yet
	// when this is called on player spawn. Ownership is verified when opening
	// the cosmetics menu or when selecting a new cosmetic.
	
	// Create the particle
	SpawnParticles_CreateParticle(client, g_Particles[foundIndex], PARTICLE_DURATION);
}

/**
 * Create a particle effect attached to a player.
 * 
 * @param client         Client index
 * @param particleType   Particle effect name
 * @param duration       Duration in seconds
 */
void SpawnParticles_CreateParticle(int client, const char[] particleType, float duration)
{
	if (StrEqual(particleType, "none"))
	{
		return;
	}
	
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEdict(particle))
	{
		return;
	}
	
	// Get player position
	float position[3];
	GetClientAbsOrigin(client, position);
	
	// Get player name for parenting
	char playerName[64];
	GetEntPropString(client, Prop_Data, "m_iName", playerName, sizeof(playerName));
	
	// Setup particle
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", playerName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	
	SetVariantString(playerName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	
	// Track owner in our own array (more reliable than m_hOwnerEntity send prop)
	g_ParticleOwner[particle] = client;
	
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	
	// Set transmit hook to control visibility.
	// Note: FL_EDICT_ALWAYS is cleared inside the hook itself on every call because
	// the engine continuously re-sets it on parented entities.
	SDKHook(particle, SDKHook_SetTransmit, Hook_SpawnParticleSetTransmit);
	
	// Delete after duration
	CreateTimer(duration, Timer_DeleteParticle, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * Timer to delete a particle entity.
 */
public Action Timer_DeleteParticle(Handle timer, int entRef)
{
    int particle = EntRefToEntIndex(entRef);
    
    if (particle == INVALID_ENT_REFERENCE)
    {
        return Plugin_Stop;
    }
    
    if (IsValidEntity(particle))
    {
        char classname[64];
        GetEdictClassname(particle, classname, sizeof(classname));
        
        if (StrEqual(classname, "info_particle_system", false))
        {
            g_ParticleOwner[particle] = 0;
            RemoveEntity(particle);
        }
    }
    
    return Plugin_Stop;
}

/**
 * Hook to control spawn particle visibility based on player preferences.
 */
public Action Hook_SpawnParticleSetTransmit(int particle, int client)
{
	// The engine re-sets FL_EDICT_ALWAYS on parented entities every network update,
	// bypassing ShouldTransmit checks. Clear it here each time so this hook keeps firing.
	if (GetEdictFlags(particle) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(particle, GetEdictFlags(particle) ^ FL_EDICT_ALWAYS);
	}

	if (!IsValidPlayer(client))
	{
		return Plugin_Handled;
	}

	// Use cached preference loaded from cookies.
	if (!g_IsHidingSpawnParticles[client])
	{
		return Plugin_Continue;
	}

	// Hide only other players' spawn particles, keep your own visible.
	int owner = g_ParticleOwner[particle];
	if (owner == client)
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

/**
 * Handle player disconnect.
 * 
 * @param client         Client index
 */
void SpawnParticles_OnClientDisconnect(int client)
{
	g_SelectedParticle[client] = 0;
	g_IsHidingSpawnParticles[client] = false;
}

// ============================================================================
// Inventory Integration Helper Functions
// ============================================================================

/**
 * Apply a spawn particle by name (for inventory equipping).
 * 
 * @param client         Client index
 * @param particleName   Display name of the particle to apply
 * @return               True on success
 */
bool SpawnParticles_ApplyByName(int client, const char[] particleName)
{
    if (!IsValidPlayer(client) || strlen(particleName) == 0)
    {
        return false;
    }
    
    // Find the particle by display name
    for (int i = 0; i < g_ParticlesCount; i++)
    {
        if (StrEqual(g_ParticleNames[i], particleName, false))
        {
            SpawnParticles_SelectParticle(client, i);
            return true;
        }
    }
    
    return false;
}

/**
 * Clear a player's spawn particle (for inventory unequipping).
 * 
 * @param client         Client index
 */
void SpawnParticles_Clear(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    SpawnParticles_SelectParticle(client, 0);
}
