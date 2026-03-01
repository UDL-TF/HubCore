#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <dbi>
#include <hub-stock>
#include <hub-enum>
#include <hub-defines>
#include <hub-database>
#include <hub-cache>
#include <hub-chat>
#include <clientprefs>
#include <multicolors>
#include <json>

#undef REQUIRE_EXTENSIONS
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#define REQUIRE_EXTENSIONS

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION		 "2.2.0"
#define PLUGIN_DESCRIPTION "Hub is the core plugin for the hub plugins."

HubPlayers			hubPlayers[MAXPLAYERS + 1];

// Credits
ConVar					Hub_Credits_Minute;
ConVar					Hub_Credits_Amount;
ConVar					Hub_Credits_Coinflip_Multiplier;
// Get credits when you kill someone, either enabled or not.
// When a player gets killed we take their points
ConVar					Hub_Credits_Kill_For_Credits;
ConVar					Hub_Credits_Kill_For_Credits_Points;

// Shop
HubCategories		hubCategories[MAX_CATEGORIES];
HubItems				hubItems[MAX_CATEGORIES][MAX_ITEMS];
HubPlayersItems hubPlayersItems[MAXPLAYERS + 1][MAX_ITEMS];
PrepareBuying		prepareBuying[MAXPLAYERS + 1];

/* Database */
Database				DB;

/* Public Data */
char						logFile[256], databasePrefix[10] = "hub_";

char						preferenceData[][] = {
	 HUB_COOKIE_DISABLED_CREDIT_KILL_REWARD_MESSAGE,
	 HUB_COOKIE_DISABLED_CREDIT_RECEIVED_MESSAGE,
	 HUB_COOKIE_TRAIL_HIDING,
	 HUB_COOKIE_SPAWN_PARTICLE_HIDING
};

// Database module includes
#include "hub/database/migrations.sp"
#include "hub/database/db_manager.sp"
#include "hub/database/audit.sp"
#include "hub/database/cache.sp"

// Core module includes
#include "hub/core.sp"
#include "hub/cookies.sp"
#include "hub/credits.sp"
#include "hub/selections.sp"
#include "hub/shop.sp"
#include "hub/menu.sp"

// Cosmetics module includes
#include "hub/cosmetics/base.sp"
#include "hub/cosmetics/tags.sp"
#include "hub/cosmetics/footprints.sp"
#include "hub/cosmetics/spawn_particles.sp"
#include "hub/cosmetics/trails.sp"

// Chat system module includes
#include "hub/chat/processor.sp"
#include "hub/chat/colors.sp"
#include "hub/chat/formatting.sp"
#include "hub/chat/menus.sp"

/**
 * If we are connecting to the database.
 */
// bool			 g_connectingToDatabase = false;
public Plugin myinfo =
{
	name				= "hub",
	author			= "Tolfx",
	description = PLUGIN_DESCRIPTION,
	version			= PLUGIN_VERSION,
	url					= "https://github.com/Dodgeball-TF/HubCore"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("hub");

	// Plugins Loading
	CoreAskPluginLoad2();
	CreditsAskPluginLoad2();
	ShopAskPluginLoad2();
	Selections_RegisterNatives();
	
	// Cosmetics natives
	Tags_RegisterNatives();
	Footprints_RegisterNatives();
	Trails_RegisterNatives();
	
	// Chat system natives
	Chat_RegisterNatives();

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Load translations
	LoadTranslations("hub.phrases.txt");

	// Initialize cache system first
	Cache_Init();

	// Plugins Loading
	CoreOnStart();
	CookieOnStart();
	CreditsOnStart();
	ShopOnStart();
	MenuOnStart();
	
	// Initialize selections system
	Selections_Init();
	
	// Initialize cosmetics systems
	Cosmetics_Init();
	Tags_Init();
	Footprints_Init();
	SpawnParticles_Init();
	Trails_Init();
	
	// Initialize chat system
	Chat_Processor_Init();
	Chat_Colors_Init();
	Chat_Menus_Init();
}

/* Player connections */
public void OnClientConnected(int client)
{
	// Initialize chat colors for new client
	Chat_Colors_OnClientConnected(client);
}

public void OnClientPostAdminCheck(int client)
{
	/* Do not check bots nor check player with lan steamid. */
	if (DB == INVALID_HANDLE)
	{
		return;
	}

	// Is client valid
	if (!IsValidPlayer(client))
	{
		return;
	}

	CoreBootstrapClient(client);
	CreditsOnClientPostAdminCheck(client);
	ShopOnClientPostAdminCheck(client);
	CookieOnClientPostAdminCheck(client);
}

public void OnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	// Core disconnect handling (cache flush, audit log, etc.)
	CoreOnClientDisconnect(client);

	// Remove the player from the hubPlayers array.
	hubPlayers[client].steamID = "";
	hubPlayers[client].name		 = "";
	hubPlayers[client].ip			 = "";
	hubPlayers[client].credits = 0;

	// Add each plugin own callback too
	CreditsOnClientDisconnect(client);
	ShopOnClientDisconnect(client);
	
	// Cosmetics disconnect handling
	Tags_OnClientDisconnect(client);
	Footprints_OnClientDisconnect(client);
	SpawnParticles_OnClientDisconnect(client);
	Trails_OnClientDisconnect(client);
	
	// Chat system disconnect handling
	Chat_Colors_OnClientDisconnect(client);
}

public void OnMapStart()
{
	// Load trails config and precache materials
	Trails_OnMapStart();
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!IsValidPlayer(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	// Render trails
	Trails_OnPlayerRunCmd(client);

	// Keep footprint attribute persistent
	Footprints_OnPlayerRunCmd(client);
	
	return Plugin_Continue;
}

public void OnPluginEnd()
{
	// Shutdown cache system - flush all data
	Cache_Shutdown();
}

public void ErrorCheckCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
	}
}
