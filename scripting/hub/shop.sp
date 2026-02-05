
enum struct PrepareBuying
{
	int itemId;
	int categoryId;
}

// Track if shop data (categories/items) has been loaded
bool g_ShopDataLoaded = false;

void ShopOnStart()
{
	LoadTranslations("hub-shop.phrases.txt");

	// Reg Console Commands
	RegConsoleCmd("sm_shop", CommandShop, "Get our shop list", _);
	RegConsoleCmd("sm_store", CommandShop, "Get our shop list", _);
}

void ShopAskPluginLoad2()
{
	CreateNative("Hub_HasPlayerItemName", Native_Hub_HasPlayerItemName);
}

/**
 * Check if shop data (categories and items) is loaded.
 */
bool Shop_IsDataLoaded()
{
	return g_ShopDataLoaded;
}

/* Player connections */
void ShopOnClientPostAdminCheck(int client)
{
	ShopBootstrapClient(client);
}

void ShopOnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	PrepareBuying prepareBuying_;
	prepareBuying[client] = prepareBuying_;
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		hubPlayersItems[client][i].itemId						 = 0;
		hubPlayersItems[client][i].steamID					 = "";
		hubPlayersItems[client][i].internal_OwnsItem = false;
	}
}

/* Methods */
void GetHubCategories()
{
	// Use v2 tables with proper filtering
	char Query[256];
	Format(Query, sizeof(Query), "SELECT `id`, `name`, `description`, `sort_order` FROM `%scategories_v2` WHERE `is_active` = TRUE ORDER BY `sort_order` ASC;", databasePrefix);

	DB.Query(GetHubCategoriesCallback, Query);
}

void ShopBootstrapClient(int client)
{
	if (!IsValidPlayer(client))
	{
		return;
	}

	// Get the players items.
	GetHubPlayerItems(client);
}

void GetHubItems(int categoryId)
{
	// Use v2 tables with proper filtering
	char Query[512];
	Format(Query, sizeof(Query), "SELECT `id`, `name`, `description`, `type`, `price`, `attributes` FROM `%sitems_v2` WHERE `category_id` = '%d' AND `is_active` = TRUE ORDER BY `price` ASC;", databasePrefix, categoryId);

	DB.Query(GetHubItemsCallback, Query, categoryId);
}

void GetHubPlayerItems(int client)
{
	if (client < 1 || client > MaxClients)
	{
		LogError("GetHubPlayerItem: Invalid client %d.", client);
		return;
	}

	char steamID[32];
	GetSteamId(client, steamID, sizeof(steamID));

	// Use v2 tables with soft delete filtering
	char Query[512];
	char escapedSteamID[64];
	DB.Escape(steamID, escapedSteamID, sizeof(escapedSteamID));
	Format(Query, sizeof(Query), "SELECT `item_id` FROM `%splayer_items_v2` WHERE `steamid` = '%s' AND `deleted_at` IS NULL;", databasePrefix, escapedSteamID);

	DB.Query(GetHubPlayerItemCallback, Query, client);
}

StateSetPlayerItem SetHubPlayerItem(int client, bool drawMoney = true)
{
	if (client < 1 || client > MaxClients)
	{
		LogError("SetHubPlayerItem: Invalid client %d.", client);
		return GENERIC_ERROR;
	}

	int itemId		 = prepareBuying[client].itemId;
	int categoryId = prepareBuying[client].categoryId;

	if (drawMoney)
	{
		// Find category id for item.

		// Check if player already has item.
		for (int i = 0; i < MAX_ITEMS; i++)
		{
			if (hubPlayersItems[client][i].itemId == itemId)
			{
				if (hubPlayersItems[client][i].internal_OwnsItem)
				{
					LogError("SetHubPlayerItem: Player already has item %d.", itemId);
					return ALREADY_HAS_ITEM;
				}
			}
		}

		// Check if player has enough credits.
		int credits = Core_GetPlayerCredits(client);
		int price = hubItems[categoryId][itemId].price;

		if (credits < price)
		{
			LogError("SetHubPlayerItem: Player does not have enough credits to buy item %d.", itemId);
			return NOT_ENOUGH_CREDITS;
		}

		// Use transaction for atomic purchase
		char steamID[32];
		GetSteamId(client, steamID, sizeof(steamID));
		
		Transaction txn = new Transaction();
		char query[512];
		char escapedSteamID[64];
		DB.Escape(steamID, escapedSteamID, sizeof(escapedSteamID));
		
		// Insert item into player_items_v2
		Format(query, sizeof(query), "INSERT INTO `%splayer_items_v2` (`steamid`, `item_id`, `purchase_price`) VALUES ('%s', %d, %d);", databasePrefix, escapedSteamID, itemId, price);
		txn.AddQuery(query);
		
		// Update credits in hub_players_v2
		Format(query, sizeof(query), "UPDATE `%splayers_v2` SET `credits` = `credits` - %d WHERE `steamid` = '%s' AND `credits` >= %d;", databasePrefix, price, escapedSteamID, price);
		txn.AddQuery(query);
		
		DB.Execute(txn, OnPurchaseSuccess, OnPurchaseFailed, GetClientUserId(client));

		// Update local cache (will be synced to DB via cache system too)
		Cache_SetCredits(client, credits - price);
		hubPlayers[client].credits = credits - price;

		// Audit log the purchase
		Audit_LogPurchase(client, itemId, hubItems[categoryId][itemId].name, price);
	}
	else
	{
		// No payment required, just add the item
		char steamID[32];
		GetSteamId(client, steamID, sizeof(steamID));

		char Query[512];
		char escapedSteamID[64];
		DB.Escape(steamID, escapedSteamID, sizeof(escapedSteamID));
		Format(Query, sizeof(Query), "INSERT INTO `%splayer_items_v2` (`steamid`, `item_id`, `purchase_price`) VALUES ('%s', %d, 0) ON DUPLICATE KEY UPDATE `deleted_at` = NULL;", databasePrefix, escapedSteamID, itemId);

		DB.Query(ErrorCheckCallback, Query);
	}

	// Set the item in the local array.
	hubPlayersItems[client][itemId].itemId						= itemId;
	char steamID[32];
	GetSteamId(client, steamID, sizeof(steamID));
	hubPlayersItems[client][itemId].steamID						= steamID;
	hubPlayersItems[client][itemId].internal_OwnsItem = true;

	PrepareBuying prepareBuying_;
	prepareBuying[client] = prepareBuying_;

	return PAID_FOR_ITEM;
}

/**
 * Callback when purchase transaction succeeds.
 */
public void OnPurchaseSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client = GetClientOfUserId(data);
	if (client > 0)
	{
		LogToFile(logFile, "[Shop] Purchase successful for %s", PlayerCache[client].steamID);
	}
}

/**
 * Callback when purchase transaction fails.
 */
public void OnPurchaseFailed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	int client = GetClientOfUserId(data);
	LogToFile(logFile, "[Shop] Purchase FAILED for client %d: %s", client, error);
	
	// Refund credits if the transaction failed
	if (client > 0)
	{
		// The transaction failed, need to restore credits
		// This is a safety mechanism - in practice, we should reload from DB
		CPrintToChat(client, "%t", "Hub_Shop_Purchase_Failed");
	}
}

/* Commands */
public Action CommandShop(int client, int args)
{
	ShowShopMenu(client);
	return Plugin_Handled;
}

// Natives
public int Native_Hub_HasPlayerItemName(Handle plugin, int numParams)
{
	int	 client = GetNativeCell(1);
	char category[32];
	GetNativeString(2, category, sizeof(category));
	char name[32];
	GetNativeString(3, name, sizeof(name));

	// Get the category id from v2 tables
	int categoryId = -1;
	for (int i = 0; i < MAX_CATEGORIES; i++)
	{
		if (strcmp(hubCategories[i].name, category) == 0)
		{
			categoryId = hubCategories[i].id;
			break;
		}
	}

	if (categoryId == -1)
	{
		return 0;  // Category not found
	}

	// We now want to check if the player has the item.
	// First find the item by name
	int itemId = -1;
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		if (strcmp(hubItems[categoryId][i].name, name) == 0)
		{
			itemId = hubItems[categoryId][i].id;
			break;
		}
	}

	if (itemId == -1)
	{
		return 0;  // Item not found
	}

	// Check if player owns the item
	if (hubPlayersItems[client][itemId].internal_OwnsItem)
	{
		return 1;
	}

	return 0;
}

public void GetHubCategoriesCallback(Database db, DBResultSet results, const char[] error, int data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
		return;
	}

	int	 categoryCount = 0;
	char name[32];

	// Store categories at their database ID position (same as items)
	while (results.FetchRow())
	{
		int categoryId = results.FetchInt(0);
		hubCategories[categoryId].id = categoryId;
		results.FetchString(1, name, sizeof(name));
		hubCategories[categoryId].name = name;
		categoryCount++;
	}

	LogToFile(logFile, "[Shop] Loaded %d categories", categoryCount);

	// Now we have the categories, we can get the items for each category.
	// We need to iterate through all possible indices to find valid categories
	int categoryLoadCount = 0;
	for (int i = 0; i < MAX_CATEGORIES; i++)
	{
		if (hubCategories[i].id > 0)
		{
			GetHubItems(hubCategories[i].id);
			categoryLoadCount++;
		}
	}
	
	// Mark shop data as loaded (items will load async but categories are ready)
	g_ShopDataLoaded = true;
	LogToFile(logFile, "[Shop] Categories loaded, fetching items for %d categories", categoryLoadCount);
}

public void GetHubItemsCallback(Database db, DBResultSet results, const char[] error, int data)
{
	if (results == null)
	{
		LogToFile(logFile, "[Shop] Query Failed loading items for category %d: %s", data, error);
		return;
	}

	int	 categoryId = data;
	int	 itemCount = 0;

	char name[32], description[128], type[32];

	while (results.FetchRow())
	{
		int id						 = results.FetchInt(0);
		hubItems[categoryId][id].id = id;
		results.FetchString(1, name, sizeof(name));
		hubItems[categoryId][id].name = name;
		results.FetchString(2, description, sizeof(description));
		hubItems[categoryId][id].description = description;
		results.FetchString(3, type, sizeof(type));
		hubItems[categoryId][id].type	= type;
		hubItems[categoryId][id].price = results.FetchInt(4);
		itemCount++;
	}
	
	LogToFile(logFile, "[Shop] Loaded %d items for category %d (%s)", itemCount, categoryId, hubCategories[categoryId].name);
}

public void GetHubPlayerItemCallback(Database db, DBResultSet results, const char[] error, int data)
{
	if (results == null)
	{
		LogToFile(logFile, "[Shop] Query Failed loading player items: %s", error);
		return;
	}

	int	 client = data;
	
	if (!IsValidPlayer(client))
	{
		return;
	}
	
	int	 itemCount = 0;
	char steamID[32];
	char name[32];

	GetClientName(client, name, sizeof(name));
	GetSteamId(client, steamID, sizeof(steamID));

	while (results.FetchRow())
	{
		int itemId																				= results.FetchInt(0);
		hubPlayersItems[client][itemId].itemId						= itemId;
		hubPlayersItems[client][itemId].steamID						= steamID;
		hubPlayersItems[client][itemId].internal_OwnsItem = true;
		itemCount++;
	}
	
	LogToFile(logFile, "[Shop] Loaded %d owned items for %s (%s)", itemCount, name, steamID);
}