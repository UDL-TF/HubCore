
void CoreOnStart()
{
	// Load translations
	LoadTranslations("hub.phrases.txt");

	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/hub.log");
	// g_connectingToDatabase = true;
	if (!SQL_CheckConfig("hub"))
	{
		LogToFile(logFile, "Database failure: Could not find Database conf \"hub\".");
		SetFailState("Database failure: Could not find Database conf \"hub\"");
		return;
	}

	Database.Connect(DatabaseConnectedCallback, "hub");
}

void CoreAskPluginLoad2()
{
	// Legacy natives (maintained for backwards compatibility)
	CreateNative("GetPlayerCredits", Native_GetPlayerCredits);
	CreateNative("SetPlayerCredits", Native_SetPlayerCredits);
	CreateNative("AddPlayerCredits", Native_AddPlayerCredits);
	CreateNative("RemovePlayerCredits", Native_RemovePlayerCredits);

	// New database natives
	CreateNative("Hub_IsDatabaseReady", Native_IsDatabaseReady);
	CreateNative("Hub_GetSchemaVersion", Native_GetSchemaVersion);
	CreateNative("Hub_GetPlayerSelection", Native_GetPlayerSelection);
	CreateNative("Hub_SetPlayerSelection", Native_SetPlayerSelection);
	CreateNative("Hub_ClearPlayerSelection", Native_ClearPlayerSelection);
	CreateNative("Hub_GetPlayerSettingBool", Native_GetPlayerSettingBool);
	CreateNative("Hub_SetPlayerSettingBool", Native_SetPlayerSettingBool);
	CreateNative("Hub_GetPlayerSettingInt", Native_GetPlayerSettingInt);
	CreateNative("Hub_SetPlayerSettingInt", Native_SetPlayerSettingInt);
	CreateNative("Hub_GetPlayerSettingString", Native_GetPlayerSettingString);
	CreateNative("Hub_SetPlayerSettingString", Native_SetPlayerSettingString);

	// New cache natives
	CreateNative("Hub_IsPlayerDataLoaded", Native_IsPlayerDataLoaded);
	CreateNative("Hub_GetPlayerCredits", Native_Hub_GetPlayerCredits);
	CreateNative("Hub_SetPlayerCredits", Native_Hub_SetPlayerCredits);
	CreateNative("Hub_AddPlayerCredits", Native_Hub_AddPlayerCredits);
	CreateNative("Hub_RemovePlayerCredits", Native_Hub_RemovePlayerCredits);
	CreateNative("Hub_FlushPlayerCache", Native_FlushPlayerCache);
	CreateNative("Hub_GetPlayerSteamID", Native_GetPlayerSteamID);
	CreateNative("Hub_GetPlayerSteamID64", Native_GetPlayerSteamID64);
	CreateNative("Hub_GetPlayerPlayTime", Native_GetPlayerPlayTime);
	CreateNative("Hub_GetPlayerSessionTime", Native_GetPlayerSessionTime);
}

/* Methods */
int Core_GetPlayerCredits(int client)
{
	if (client < 1 || client > MaxClients)
	{
		LogError("GetPlayerCredits: Invalid client %d.", client);
		return -1;
	}

	// Use cache system - much faster than DB queries
	if (Cache_IsLoaded(client))
	{
		int credits = Cache_GetCredits(client);
		hubPlayers[client].credits = credits;  // Keep legacy struct in sync
		return credits;
	}

	// Fallback to legacy struct if cache not loaded
	return hubPlayers[client].credits;
}

int Core_SetPlayerCredits(int client, int credits)
{
	if (client < 1 || client > MaxClients)
	{
		LogError("SetPlayerCredits: Invalid client %d.", client);
		return -1;
	}

	if (credits < 0)
	{
		credits = 0;
	}

	// Get old credits for audit logging
	int oldCredits = Cache_GetCredits(client);

	// Update cache (marks as dirty, will sync to DB)
	Cache_SetCredits(client, credits);

	// Keep legacy struct in sync
	hubPlayers[client].credits = credits;

	// Audit log the change
	Audit_LogCreditChange(client, oldCredits, credits, "set", AUDIT_SOURCE_CORE);

	return 1;
}

int Core_RemovePlayerCredits(int client, int credits)
{
	if (!IsValidPlayer(client))
	{
		LogError("RemovePlayerCredits: Invalid client %d.", client);
		return 0;
	}

	if (credits < 0)
	{
		LogError("RemovePlayerCredits: Invalid credits %d.", credits);
		return 0;
	}

	// Get old credits for audit logging
	int oldCredits = Cache_GetCredits(client);

	// Use cache system - handles preventing negative values
	int newCredits = Cache_RemoveCredits(client, credits);

	// Keep legacy struct in sync
	hubPlayers[client].credits = newCredits;

	// Audit log the change
	Audit_LogCreditChange(client, oldCredits, newCredits, "remove", AUDIT_SOURCE_CORE);

	return 1;
}

int Core_AddPlayerCredits(int client, int credits)
{
	if (!IsValidPlayer(client))
	{
		LogError("AddPlayerCredits: Invalid client %d.", client);
		return 0;
	}

	if (credits < 0)
	{
		LogError("AddPlayerCredits: Invalid credits %d.", credits);
		return 0;
	}

	// Get old credits for audit logging
	int oldCredits = Cache_GetCredits(client);

	// Use cache system
	int newCredits = Cache_AddCredits(client, credits);

	// Keep legacy struct in sync
	hubPlayers[client].credits = newCredits;

	// Audit log the change
	Audit_LogCreditChange(client, oldCredits, newCredits, "add", AUDIT_SOURCE_CORE);

	return 1;
}

public void CoreBootstrapClient(int client)
{
	// Check if client is valid.
	if (!IsValidPlayer(client))
	{
		return;
	}

	// Initialize cache for player
	Cache_InitPlayer(client);
	
	// Load player data from database into cache
	// This handles both v1 and v2 tables
	Cache_LoadPlayer(client);

	// Also update legacy hubPlayers struct for backwards compatibility
	char steamID[32], name[32], ip[32];
	GetSteamId(client, steamID, sizeof(steamID));
	GetClientName(client, name, sizeof(name));
	GetClientIP(client, ip, sizeof(ip));

	hubPlayers[client].steamID = steamID;
	hubPlayers[client].name		 = name;
	hubPlayers[client].ip			 = ip;

	// Log login for audit
	Audit_LogLogin(client);
}

/**
 * Called when client disconnects - flush cache and update play time.
 */
void CoreOnClientDisconnect(int client)
{
	if (!IsValidPlayer(client))
	{
		return;
	}

	// Calculate session play time
	int sessionTime = 0;
	if (PlayerCache[client].joinTime > 0.0)
	{
		sessionTime = RoundToFloor(GetGameTime() - PlayerCache[client].joinTime);
	}

	// Log logout with play time
	Audit_LogLogout(client, sessionTime);

	// Flush and clear cache
	Cache_ClearPlayer(client);
}

/* Natives */
public int Native_GetPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		LogError("GetPlayerCredits: Invalid client %d.", client);
		return 0;
	}

	Core_GetPlayerCredits(client);

	return hubPlayers[client]
		.credits;
}

public int Native_SetPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		LogError("SetPlayerCredits: Invalid client %d.", client);
		return 0;
	}

	int credits = GetNativeCell(2);

	if (credits < 0)
	{
		LogError("SetPlayerCredits: Invalid credits %d.", credits);
		return 0;
	}

	Core_SetPlayerCredits(client, credits);

	return 1;
}

public int Native_AddPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		LogError("AddPlayerCredits: Invalid client %d.", client);
		return 0;
	}

	int credits = GetNativeCell(2);

	if (credits < 0)
	{
		LogError("AddPlayerCredits: Invalid credits %d.", credits);
		return 0;
	}

	int currentCredits = Core_GetPlayerCredits(client);

	Core_SetPlayerCredits(client, currentCredits + credits);

	return 1;
}

public int Native_RemovePlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		LogError("RemovePlayerCredits: Invalid client %d.", client);
		return 0;
	}

	int credits = GetNativeCell(2);

	if (credits < 0)
	{
		LogError("RemovePlayerCredits: Invalid credits %d.", credits);
		return 0;
	}

	int currentCredits = Core_GetPlayerCredits(client);

	Core_SetPlayerCredits(client, currentCredits - credits);

	return 1;
}

public void DatabaseConnectedCallback(Database db, const char[] error, any data)
{
	if (db == INVALID_HANDLE)
	{
		LogToFile(logFile, "Database failure: %s.", error);
		// g_connectingToDatabase = false;
		SetFailState("Database failure: %s.", error);
		return;
	}

	LogToFile(logFile, "Database connected.");

	DB = db;

	// Initialize the cache system
	Cache_Init();

	// Run migrations - this will create/update all tables
	// and bootstrap players when complete
	Migrations_Init();
}

/**
 * Called by migrations system when all migrations are complete.
 * This replaces the old table creation code.
 */
void CoreOnMigrationsComplete()
{
	LogToFile(logFile, "Migrations complete, initializing shop...");
	GetHubCategories();
}

/* Database Callbacks */
public void GetPlayerCreditsCallback(Database db, DBResultSet results, const char[] error, int data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
		// We failed to get the credits, so lets just set it to 0.
		hubPlayers[data].credits = 0;
		// We should try to make a query to create a new row for this player.
		char query[256];
		char escapedSteamID[64];
		DB.Escape(hubPlayers[data].steamID, escapedSteamID, sizeof(escapedSteamID));
		Format(query, sizeof(query), "INSERT INTO `%scredits` (`steamid`, `credits`) VALUES ('%s', '0');", databasePrefix, escapedSteamID);
		DB.Query(ErrorCheckCallback, query);
		return;
	}

	// if we have no rows, then we need to create a new row for this player.
	if (!results.MoreRows)
	{
		// We failed to get the credits, so lets just set it to 0.
		hubPlayers[data].credits = 0;
		// We should try to make a query to create a new row for this player.
		char query[256];
		char escapedSteamID[64];
		DB.Escape(hubPlayers[data].steamID, escapedSteamID, sizeof(escapedSteamID));
		Format(query, sizeof(query), "INSERT INTO `%scredits` (`steamid`, `credits`) VALUES ('%s', '0');", databasePrefix, escapedSteamID);
		DB.Query(ErrorCheckCallback, query);
		return;
	}

	int client	= data;
	int credits = 0;

	while (results.FetchRow())
	{
		credits = results.FetchInt(0);
	}

	hubPlayers[client].credits = credits;
}

/* ========================================
 * New Database/Cache Natives
 * ======================================== */

public int Native_IsDatabaseReady(Handle plugin, int numParams)
{
	return Migrations_IsComplete();
}

public int Native_GetSchemaVersion(Handle plugin, int numParams)
{
	return Migrations_GetCurrentVersion();
}

public int Native_GetPlayerSelection(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	char selectionType[32], buffer[256];
	GetNativeString(2, selectionType, sizeof(selectionType));
	int maxlen = GetNativeCell(4);

	// Check cache first
	JSON_Object cosmetics = Cache_GetCosmetic(client, selectionType);
	if (cosmetics != null && cosmetics.HasKey("value"))
	{
		cosmetics.GetString("value", buffer, sizeof(buffer));
		SetNativeString(3, buffer, maxlen);
		return 1;
	}

	return 0;
}

public int Native_SetPlayerSelection(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	char selectionType[32], value[256], extraData[512];
	GetNativeString(2, selectionType, sizeof(selectionType));
	GetNativeString(3, value, sizeof(value));
	GetNativeString(4, extraData, sizeof(extraData));

	// Create cosmetic object
	JSON_Object cosmeticData = new JSON_Object();
	cosmeticData.SetString("value", value);

	// Store in cache
	Cache_SetCosmetic(client, selectionType, cosmeticData);

	// Also store in database
	char steamId[32];
	GetSteamId(client, steamId, sizeof(steamId));
	HubDB.SetSelection(steamId, selectionType, value, extraData);

	return 1;
}

public int Native_ClearPlayerSelection(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	char selectionType[32];
	GetNativeString(2, selectionType, sizeof(selectionType));

	// Clear from cache
	Cache_ClearCosmetic(client, selectionType);

	// Clear from database
	char steamId[32];
	GetSteamId(client, steamId, sizeof(steamId));
	HubDB.ClearSelection(steamId, selectionType);

	return 1;
}

public int Native_GetPlayerSettingBool(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return GetNativeCell(3);  // Return default value
	}

	char settingKey[64];
	GetNativeString(2, settingKey, sizeof(settingKey));
	bool defaultValue = GetNativeCell(3);

	return Cache_GetSettingBool(client, settingKey, defaultValue);
}

public int Native_SetPlayerSettingBool(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	char settingKey[64];
	GetNativeString(2, settingKey, sizeof(settingKey));
	bool value = GetNativeCell(3);

	Cache_SetSettingBool(client, settingKey, value);
	return 1;
}

public int Native_GetPlayerSettingInt(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return GetNativeCell(3);  // Return default value
	}

	char settingKey[64];
	GetNativeString(2, settingKey, sizeof(settingKey));
	int defaultValue = GetNativeCell(3);

	return Cache_GetSettingInt(client, settingKey, defaultValue);
}

public int Native_SetPlayerSettingInt(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	char settingKey[64];
	GetNativeString(2, settingKey, sizeof(settingKey));
	int value = GetNativeCell(3);

	Cache_SetSettingInt(client, settingKey, value);
	return 1;
}

public int Native_GetPlayerSettingString(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	char settingKey[64], defaultValue[256];
	GetNativeString(2, settingKey, sizeof(settingKey));
	int maxlen = GetNativeCell(4);
	GetNativeString(5, defaultValue, sizeof(defaultValue));

	if (!IsValidPlayer(client))
	{
		SetNativeString(3, defaultValue, maxlen);
		return 0;
	}

	char buffer[256];
	bool exists = Cache_GetSetting(client, settingKey, buffer, sizeof(buffer));
	
	if (exists)
	{
		SetNativeString(3, buffer, maxlen);
		return 1;
	}
	
	SetNativeString(3, defaultValue, maxlen);
	return 0;
}

public int Native_SetPlayerSettingString(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	char settingKey[64], value[256];
	GetNativeString(2, settingKey, sizeof(settingKey));
	GetNativeString(3, value, sizeof(value));

	Cache_SetSetting(client, settingKey, value);
	return 1;
}

public int Native_IsPlayerDataLoaded(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	return Cache_IsLoaded(client);
}

public int Native_Hub_GetPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	return Cache_GetCredits(client);
}

public int Native_Hub_SetPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	int credits = GetNativeCell(2);
	int oldCredits = Cache_GetCredits(client);
	
	Cache_SetCredits(client, credits);
	
	// Also update legacy struct
	hubPlayers[client].credits = credits;
	
	// Audit log
	Audit_LogCreditChange(client, oldCredits, credits, "set", AUDIT_SOURCE_CORE);
	
	return 1;
}

public int Native_Hub_AddPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	int amount = GetNativeCell(2);
	int oldCredits = Cache_GetCredits(client);
	int newCredits = Cache_AddCredits(client, amount);
	
	// Also update legacy struct
	hubPlayers[client].credits = newCredits;
	
	// Audit log
	Audit_LogCreditChange(client, oldCredits, newCredits, "add", AUDIT_SOURCE_CORE);
	
	return newCredits;
}

public int Native_Hub_RemovePlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	int amount = GetNativeCell(2);
	int oldCredits = Cache_GetCredits(client);
	int newCredits = Cache_RemoveCredits(client, amount);
	
	// Also update legacy struct
	hubPlayers[client].credits = newCredits;
	
	// Audit log
	Audit_LogCreditChange(client, oldCredits, newCredits, "remove", AUDIT_SOURCE_CORE);
	
	return newCredits;
}

public int Native_FlushPlayerCache(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	Cache_FlushPlayer(client);
	return 1;
}

public int Native_GetPlayerSteamID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	
	if (!IsValidPlayer(client))
	{
		SetNativeString(2, "", maxlen);
		return 0;
	}

	char buffer[32];
	Cache_GetSteamID(client, buffer, sizeof(buffer));
	SetNativeString(2, buffer, maxlen);
	return strlen(buffer) > 0;
}

public int Native_GetPlayerSteamID64(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	
	if (!IsValidPlayer(client))
	{
		SetNativeString(2, "", maxlen);
		return 0;
	}

	SetNativeString(2, PlayerCache[client].steamID64, maxlen);
	return strlen(PlayerCache[client].steamID64) > 0;
}

public int Native_GetPlayerPlayTime(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	return PlayerCache[client].playTimeSeconds;
}

public int Native_GetPlayerSessionTime(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidPlayer(client))
	{
		return 0;
	}

	if (PlayerCache[client].joinTime <= 0.0)
	{
		return 0;
	}

	return RoundToFloor(GetGameTime() - PlayerCache[client].joinTime);
}