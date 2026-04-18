#define MENU_SHOP				 "shop"
#define MENU_PREFERENCES "preferences"
#define MENU_INVENTORY	 "inventory"
#define MENU_GAMBLING		 "gambling"
#define MENU_DAILY				 "daily"

// Menu history system
#define MAX_MENU_HISTORY 10

enum MenuType
{
	MenuType_None,
	MenuType_Hub,
	MenuType_Shop,
	MenuType_ShopItems,
	MenuType_Preferences,
	MenuType_Inventory,
	MenuType_InventoryItems,
	MenuType_Cosmetics,
	MenuType_CosmeticsTags,
	MenuType_CosmeticsTrails,
	MenuType_CosmeticsFootprints,
	MenuType_CosmeticsSpawnParticles,
	MenuType_CosmeticsChat
}

// Menu history stack for each player
MenuType g_MenuHistory[MAXPLAYERS + 1][MAX_MENU_HISTORY];
int g_MenuHistoryPos[MAXPLAYERS + 1];
int g_MenuHistoryData[MAXPLAYERS + 1][MAX_MENU_HISTORY]; // For storing category IDs, item IDs, etc.

/**
 * Clear menu history for a client
 */
void MenuHistory_Clear(int client)
{
	g_MenuHistoryPos[client] = 0;
	for (int i = 0; i < MAX_MENU_HISTORY; i++)
	{
		g_MenuHistory[client][i] = MenuType_None;
		g_MenuHistoryData[client][i] = 0;
	}
}

/**
 * Push a menu onto the history stack
 */
void MenuHistory_Push(int client, MenuType menuType, int data = 0)
{
	// Don't push if it's the same as the current top (prevents duplicate entries)
	if (g_MenuHistoryPos[client] > 0 && 
		g_MenuHistory[client][g_MenuHistoryPos[client] - 1] == menuType &&
		g_MenuHistoryData[client][g_MenuHistoryPos[client] - 1] == data)
	{
		return;
	}
	
	if (g_MenuHistoryPos[client] < MAX_MENU_HISTORY)
	{
		g_MenuHistory[client][g_MenuHistoryPos[client]] = menuType;
		g_MenuHistoryData[client][g_MenuHistoryPos[client]] = data;
		g_MenuHistoryPos[client]++;
	}
}

/**
 * Pop a menu from the history stack and return to previous menu
 */
void MenuHistory_GoBack(int client)
{
	// Pop current menu
	if (g_MenuHistoryPos[client] > 0)
	{
		g_MenuHistoryPos[client]--;
	}
	
	// Pop the previous menu entry and show it
	if (g_MenuHistoryPos[client] > 0)
	{
		g_MenuHistoryPos[client]--;
		MenuType prevMenu = g_MenuHistory[client][g_MenuHistoryPos[client]];
		int prevData = g_MenuHistoryData[client][g_MenuHistoryPos[client]];
		
		// Show the previous menu based on its type
		switch (prevMenu)
		{
			case MenuType_Hub:
			{
				ShowHubMenu(client);
			}
			case MenuType_Shop:
			{
				ShowShopMenu(client);
			}
			case MenuType_ShopItems:
			{
				CreateDynamicItemMenu(client, prevData);
			}
			case MenuType_Preferences:
			{
				ShowPreferencesMenu(client);
			}
			case MenuType_Inventory:
			{
				ShowInventoryMenu(client);
			}
			case MenuType_InventoryItems:
			{
				CreateInventoryItemsMenu(client, prevData);
			}
			case MenuType_Cosmetics:
			{
				ShowCosmeticsMenu(client);
			}
			case MenuType_CosmeticsTags:
			{
				ShowTagsMenu(client, 0);
			}
			case MenuType_CosmeticsTrails:
			{
				ShowTrailsMenu(client, 0);
			}
			case MenuType_CosmeticsFootprints:
			{
				ShowFootprintsMenu(client, 0);
			}
			case MenuType_CosmeticsSpawnParticles:
			{
				ShowSpawnParticlesMenu(client, 0);
			}
			case MenuType_CosmeticsChat:
			{
				Menu_ChatSettings(client);
			}
		}
	}
}

void MenuOnStart()
{
	RegConsoleCmd("sm_hub", CommandHub, "Opens the hub menu");
}

public Action CommandHub(int client, int args)
{
	MenuHistory_Clear(client);
	ShowHubMenu(client);
	return Plugin_Handled;
}

void ShowHubMenu(int client)
{
	MenuHistory_Push(client, MenuType_Hub, 0);
	
	Menu menu = new Menu(MenuHandlerHub, MenuAction_Select | MenuAction_End | MenuAction_DrawItem | MenuAction_DisplayItem);

	menu.SetTitle("%t", "Hub_Menu_Title");

	menu.AddItem(MENU_SHOP, "Hub_Menu_Shop");
	menu.AddItem(MENU_INVENTORY, "Hub_Menu_Inventory");
	menu.AddItem(MENU_PREFERENCES, "Hub_Menu_Preferences");
	menu.AddItem(MENU_DAILY, "Hub_Menu_Daily");

	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowShopMenu(int client)
{
	// Check if shop data is loaded
	if (!g_ShopDataLoaded)
	{
		CPrintToChat(client, "%t", "Hub_Shop_Loading");
		return;
	}

	MenuHistory_Push(client, MenuType_Shop, 0);
	
	Menu menu						= new Menu(MenuHandlerShop);
	menu.ExitButton			= true;
	menu.ExitBackButton = true;

	int	 credits				= Core_GetPlayerCredits(client);

	char title[256];
	Format(title, sizeof(title), "%t", HUB_PHRASE_SHOP_TITLE, credits);

	menu.SetTitle(title);

	for (int i = 0; i < MAX_CATEGORIES; i++)
	{
		// Skip empty categories (categories are stored at their database ID position)
		if (hubCategories[i].id <= 0) continue;
		if (strcmp(hubCategories[i].name, "") == 0) continue;
		
		char str[8];
		IntToString(hubCategories[i].id, str, sizeof(str));
		menu.AddItem(str, hubCategories[i].name, ITEMDRAW_DEFAULT);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowPreferencesMenu(int client)
{
	MenuHistory_Push(client, MenuType_Preferences, 0);
	
	Menu menu						= new Menu(MenuHandlerPreferences, MenuAction_Select | MenuAction_End);
	menu.ExitBackButton = true;

	menu.SetTitle("%t", "Hub_Menu_Preferences");

	// Set translation target for Format %t support
	SetGlobalTransTarget(client);

	for (int i = 0; i < sizeof(preferenceData); i++)
	{
		char info[4];
		if (IntToString(i, info, sizeof(info)) > 0)
		{
			char preferenceName[128], display[128], translatedName[128];
			Format(preferenceName, sizeof(preferenceName), "%s", preferenceData[i]);

			Cookie cookie			 = GetCookieByName(preferenceName);
			if (cookie == null)
			{
				// Cookie not found, skip this preference
				continue;
			}
			
			int		 cookieValue = GetCookieValue(client, cookie);

			// Get the translated name
			Format(translatedName, sizeof(translatedName), "%t", preferenceName);

			if (cookieValue == 0)
				Format(display, sizeof(display), "[ ] %s", translatedName);
			else
				Format(display, sizeof(display), "[x] %s", translatedName);

			menu.AddItem(info, display, ITEMDRAW_DEFAULT);
		}
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowGamblingMenu(int client)
{}

void ShowInventoryMenu(int client)
{
	// Check if shop data is loaded
	if (!g_ShopDataLoaded)
	{
		CPrintToChat(client, "%t", "Hub_Shop_Loading");
		return;
	}

	MenuHistory_Push(client, MenuType_Inventory, 0);
	
	Menu menu						= new Menu(MenuHandlerInventory);
	menu.ExitButton			= true;
	menu.ExitBackButton = true;

	char title[256];
	Format(title, sizeof(title), "%t", "Hub_Menu_Inventory");

	menu.SetTitle(title);

	// Count owned items per category for display
	for (int i = 0; i < MAX_CATEGORIES; i++)
	{
		// Skip empty categories (categories are stored at their database ID position)
		if (hubCategories[i].id <= 0) continue;
		if (strcmp(hubCategories[i].name, "") == 0) continue;
		
		// Count owned items in this category
		int ownedCount = 0;
		int categoryId = hubCategories[i].id;
		
		for (int j = 0; j < MAX_ITEMS; j++)
		{
			if (hubItems[categoryId][j].id > 0 && hubPlayersItems[client][hubItems[categoryId][j].id].internal_OwnsItem)
			{
				ownedCount++;
			}
		}
		
		char str[8];
		IntToString(categoryId, str, sizeof(str));
		
		char displayName[64];
		if (ownedCount > 0)
		{
			Format(displayName, sizeof(displayName), "%s (%d items)", hubCategories[i].name, ownedCount);
		}
		else
		{
			Format(displayName, sizeof(displayName), "%s (empty)", hubCategories[i].name);
		}
		
		menu.AddItem(str, displayName, ownedCount > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

/* Menu Handlers */
public int MenuHandlerHub(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			if (StrEqual(info, MENU_SHOP))
			{
				ShowShopMenu(param1);
			}

			if (StrEqual(info, MENU_PREFERENCES))
			{
				ShowPreferencesMenu(param1);
			}

			if (StrEqual(info, MENU_INVENTORY))
			{
				ShowInventoryMenu(param1);
			}

			if (StrEqual(info, MENU_GAMBLING))
			{
				ShowGamblingMenu(param1);
			}

			if (StrEqual(info, MENU_DAILY))
			{
				FakeClientCommand(param1, "sm_daily");
			}
		}
		case MenuAction_Cancel:
		{
				// Clear history when menu is closed (not using back button)
				if (param2 == MenuCancel_Exit || param2 == MenuCancel_Timeout || param2 == MenuCancel_Interrupted)
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
			char info[64], display[128];
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

			Format(display, sizeof(display), "%T", display, param1);
			return RedrawMenuItem(display);
		}
	}

	return 0;
}

// Shops related content
public int MenuHandlerShop(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int categoryId									 = StringToInt(strOption);

			prepareBuying[param1].categoryId = categoryId;

			CreateDynamicItemMenu(param1, categoryId);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				MenuHistory_GoBack(param1);
			else
				MenuHistory_Clear(param1);
		}
	}

	return 1;
}

public void CreateDynamicItemMenu(int client, int categoryId)
{
	MenuHistory_Push(client, MenuType_ShopItems, categoryId);
	
	Menu menu						= new Menu(ItemMenuHandler);
	menu.ExitButton			= true;
	menu.ExitBackButton = true;

	menu.SetTitle(hubCategories[categoryId].name);

	int clientCredits = Core_GetPlayerCredits(client);

	GetHubItems(categoryId);

	// First, collect all valid item IDs in this category
	int validItemIds[MAX_ITEMS];
	int validItemCount = 0;
	
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		// Items are stored at their database ID position, so check if this slot has a valid item
		if (hubItems[categoryId][i].id > 0 &&
			strcmp(hubItems[categoryId][i].name, "") != 0 &&
			!StrEqual(hubItems[categoryId][i].name, "\\0") &&
			!StrEqual(hubItems[categoryId][i].name, "{null}", false) &&
			!StrEqual(hubItems[categoryId][i].name, "{empty}", false))
		{
			validItemIds[validItemCount] = i;  // Store the ID (which equals the array index)
			validItemCount++;
		}
	}

	// Bubble Sort valid items by price
	for (int i = 0; i < validItemCount - 1; i++)
	{
		for (int j = 0; j < validItemCount - i - 1; j++)
		{
			int idA = validItemIds[j];
			int idB = validItemIds[j + 1];
			if (hubItems[categoryId][idA].price > hubItems[categoryId][idB].price)
			{
				// Swap
				int temp = validItemIds[j];
				validItemIds[j] = validItemIds[j + 1];
				validItemIds[j + 1] = temp;
			}
		}
	}

	// Now add items to the menu in sorted order
	for (int i = 0; i < validItemCount; i++)
	{
		int itemId = validItemIds[i];
		
		// Store the actual item ID in the menu info
		char str[8];
		IntToString(itemId, str, sizeof(str));

		char betterName[128];
		Format(betterName, sizeof(betterName), "%s - %d", hubItems[categoryId][itemId].name, hubItems[categoryId][itemId].price);

		bool hasEnoughToBuy = clientCredits >= hubItems[categoryId][itemId].price;
		bool alreadyOwns		= hubPlayersItems[client][itemId].internal_OwnsItem;

		if (alreadyOwns)
		{
			Format(betterName, sizeof(betterName), "%s - %d (Owned)", hubItems[categoryId][itemId].name, hubItems[categoryId][itemId].price);
			menu.AddItem(str, betterName, ITEMDRAW_DISABLED);
			continue;
		}

		bool enable = hasEnoughToBuy;

		menu.AddItem(str, betterName, enable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int ItemMenuHandler(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			prepareBuying[param1].itemId = StringToInt(strOption);

			ConfirmBuyItemMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				MenuHistory_GoBack(param1);
			else
				MenuHistory_Clear(param1);
		}
	}

	return 1;
}

public void ConfirmBuyItemMenu(int client)
{
	Menu menu				= new Menu(ConfirmBuyItemMenuHandler);
	menu.ExitButton = true;

	int	 categoryId = prepareBuying[client].categoryId;
	int	 itemId			= prepareBuying[client].itemId;

	char betterName[128];
	Format(betterName, sizeof(betterName), "%t", HUB_PHRASE_SHOP_CONFIRM_BUY, hubItems[categoryId][itemId].name, hubItems[categoryId][itemId].price);

	menu.SetTitle(betterName);
	menu.AddItem("1", "Yes", ITEMDRAW_DEFAULT);
	menu.AddItem("2", "Cancel", ITEMDRAW_DEFAULT);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int ConfirmBuyItemMenuHandler(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int option = StringToInt(strOption);

			if (option == 1)
			{
				int	 client						= param1;
				int	 cache_categoryId = prepareBuying[client].categoryId;
				int	 cahce_itemId			= prepareBuying[client].itemId;
				char cache_itemName[32];
				Format(cache_itemName, sizeof(cache_itemName), "%s", hubItems[cache_categoryId][cahce_itemId].name);
				StateSetPlayerItem state = SetHubPlayerItem(client);

				switch (state)
				{
					case GENERIC_ERROR:
					{
						CPrintToChat(client, "%t", HUB_PHRASE_SOMETHING_WENT_WRONG);
					}
					case ALREADY_HAS_ITEM:
					{
						CPrintToChat(client, "%t", HUB_PHRASE_YOU_ALREADY_OWN_THIS_ITEM, cache_itemName);
					}
					case NOT_ENOUGH_CREDITS:
					{
						CPrintToChat(client, "%t", HUB_PHRASE_YOU_DONT_HAVE_ENOUGH_CREDITS_TO_BUY_THIS, cache_itemName);
					}
					case PAID_FOR_ITEM:
					{
						CPrintToChat(client, "%t", HUB_PHRASE_SUCCESSFULLY_BOUGHT_ITEM, cache_itemName);
					}
				}
			}
		}
	}

	return 1;
}

// Preferences related content
public int MenuHandlerPreferences(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int	 option = StringToInt(strOption);
			char preferenceName[128];
			Format(preferenceName, sizeof(preferenceName), "%s", preferenceData[option]);

			char preferenceFormatted[128];
			Format(preferenceFormatted, sizeof(preferenceFormatted), "%t", preferenceName, param1);

			Cookie cookie = GetCookieByName(preferenceName);
			int		 value	= GetCookieValue(param1, cookie);

			if (value == 1)
			{
				SetCookieValue(param1, cookie, "0");
				CPrintToChat(param1, "%t", "Hub_Preference_Disabled", preferenceFormatted);
			}
			else
			{
				SetCookieValue(param1, cookie, "1");
				CPrintToChat(param1, "%t", "Hub_Preference_Enabled", preferenceFormatted);
			}
			
			// Refresh cookie cache
			OnClientCookiesCached(param1);

			ShowPreferencesMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				MenuHistory_GoBack(param1);
			else
				MenuHistory_Clear(param1);
		}
	}

	return 1;
}

// Inventory related content
public int MenuHandlerInventory(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int categoryId = StringToInt(strOption);

			CreateInventoryItemsMenu(param1, categoryId);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				MenuHistory_GoBack(param1);
			else
				MenuHistory_Clear(param1);
		}
	}

	return 1;
}

public void CreateInventoryItemsMenu(int client, int categoryId)
{
	// Get the items this user has on this category
	GetHubItems(categoryId);

	MenuHistory_Push(client, MenuType_InventoryItems, categoryId);
	
	Menu menu						= new Menu(MenuHandlerInventoryItem);
	menu.ExitButton			= true;
	menu.ExitBackButton = true;

	// Store category ID for handler
	char categoryName[64];
	Format(categoryName, sizeof(categoryName), "%s", hubCategories[categoryId].name);
	menu.SetTitle("%t: %s", "Hub_Menu_Inventory", categoryName);

	// Determine the cosmetic type from category name
	char selectionType[32];
	GetSelectionTypeFromCategory(categoryName, selectionType, sizeof(selectionType));
	bool isColorCategory = (StrContains(categoryName, "Chat Color", false) != -1 || StrContains(categoryName, "Name Color", false) != -1);

	int itemCount = 0;
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		int itemId = hubItems[categoryId][i].id;
		if (itemId <= 0) continue;
		if (strcmp(hubItems[categoryId][i].name, "") == 0) continue;
		if (StrEqual(hubItems[categoryId][i].name, "\\0")) continue;
		if (StrEqual(hubItems[categoryId][i].name, "{null}", false)) continue;
		if (StrEqual(hubItems[categoryId][i].name, "{empty}", false)) continue;

		bool ownsItem = hubPlayersItems[client][itemId].internal_OwnsItem;
		if (!ownsItem)
			continue;

			// Check if this item is currently equipped
			bool isEquipped = Inventory_IsSelectionEquipped(client, selectionType, hubItems[categoryId][i].name);
			bool isChatEquipped = false;
			bool isNameEquipped = false;
			if (isColorCategory)
			{
				isChatEquipped = Inventory_IsSelectionEquipped(client, SELECTION_CHAT_COLOR, hubItems[categoryId][i].name);
				isNameEquipped = Inventory_IsSelectionEquipped(client, SELECTION_NAME_COLOR, hubItems[categoryId][i].name);
				isEquipped = isChatEquipped || isNameEquipped;
			}

		char info[16];
		Format(info, sizeof(info), "%d:%d", categoryId, itemId);

		char betterName[128];
			if (isColorCategory)
			{
				if (isChatEquipped && isNameEquipped)
				{
					Format(betterName, sizeof(betterName), "[C/N] %s", hubItems[categoryId][i].name);
				}
				else if (isChatEquipped)
				{
					Format(betterName, sizeof(betterName), "[C] %s", hubItems[categoryId][i].name);
				}
				else if (isNameEquipped)
				{
					Format(betterName, sizeof(betterName), "[N] %s", hubItems[categoryId][i].name);
				}
				else
				{
					Format(betterName, sizeof(betterName), "  %s", hubItems[categoryId][i].name);
				}
			}
			else if (isEquipped)
			{
				Format(betterName, sizeof(betterName), "[E] %s [%t]", hubItems[categoryId][i].name, "Hub_Cosmetics_Equipped");
			}
		else
		{
			Format(betterName, sizeof(betterName), "  %s", hubItems[categoryId][i].name);
		}

		menu.AddItem(info, betterName, ITEMDRAW_DEFAULT);
		itemCount++;
	}

	if (itemCount == 0)
	{
		menu.AddItem("", "No items owned", ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerInventoryItem(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[32];
			menu.GetItem(param2, strOption, sizeof(strOption));

			// Parse categoryId:itemId format
			char parts[2][16];
			ExplodeString(strOption, ":", parts, sizeof(parts), sizeof(parts[]));
			
			int categoryId = StringToInt(parts[0]);
			int itemId = StringToInt(parts[1]);
			
			ShowInventoryItemOptionsMenu(param1, categoryId, itemId);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				MenuHistory_GoBack(param1);
			else
				MenuHistory_Clear(param1);
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 1;
}

bool Inventory_GetColorValueByName(const char[] itemName, char[] colorValue, int maxlen)
{
	int cost = 0;
	return Chat_GetColorByName(itemName, colorValue, maxlen, cost) >= 0;
}

bool Inventory_IsSelectionEquipped(int client, const char[] selectionType, const char[] itemName)
{
	if (selectionType[0] == '\0')
	{
		return false;
	}

	if (StrEqual(selectionType, SELECTION_CHAT_COLOR) || StrEqual(selectionType, SELECTION_NAME_COLOR) || StrEqual(selectionType, SELECTION_TAG_COLOR))
	{
		char selectedValue[16];
		Selections_GetPlayerString(client, selectionType, "value", selectedValue, sizeof(selectedValue), "");
		if (selectedValue[0] == '\0')
		{
			return false;
		}

		char itemColorValue[16];
		if (!Inventory_GetColorValueByName(itemName, itemColorValue, sizeof(itemColorValue)))
		{
			return false;
		}

		return StrEqual(selectedValue, itemColorValue, false);
	}

	char currentSelection[64];
	Selections_GetPlayerString(client, selectionType, "name", currentSelection, sizeof(currentSelection), "");
	return (currentSelection[0] != '\0' && strcmp(itemName, currentSelection) == 0);
}

/**
 * Get the selection type from a category name.
 * 
 * @param categoryName   Category name (e.g., "Tags", "Trails")
 * @param buffer         Buffer to store selection type
 * @param maxlen         Maximum buffer length
 */
void GetSelectionTypeFromCategory(const char[] categoryName, char[] buffer, int maxlen)
{
	// Map category names to selection types
	if (StrContains(categoryName, "Tag Color", false) != -1)
	{
		strcopy(buffer, maxlen, SELECTION_TAG_COLOR);
	}
	else if (StrContains(categoryName, "Name Color", false) != -1)
	{
		strcopy(buffer, maxlen, SELECTION_NAME_COLOR);
	}
	else if (StrContains(categoryName, "Chat Color", false) != -1)
	{
		strcopy(buffer, maxlen, SELECTION_CHAT_COLOR);
	}
	else if (StrContains(categoryName, "Tag", false) != -1)
	{
		strcopy(buffer, maxlen, SELECTION_TAG);
	}
	else if (StrContains(categoryName, "Trail", false) != -1)
	{
		strcopy(buffer, maxlen, SELECTION_TRAIL);
	}
	else if (StrContains(categoryName, "Footprint", false) != -1 || StrContains(categoryName, "Footstep", false) != -1)
	{
		strcopy(buffer, maxlen, SELECTION_FOOTPRINT);
	}
	else if (StrContains(categoryName, "Particle", false) != -1 || StrContains(categoryName, "Spawn", false) != -1)
	{
		strcopy(buffer, maxlen, SELECTION_SPAWN_PARTICLE);
	}
	else
	{
		buffer[0] = '\0';
	}
}

/**
 * Show inventory item options menu (equip/unequip).
 * 
 * @param client         Client index
 * @param categoryId     Category ID
 * @param itemId         Item ID
 */
void ShowInventoryItemOptionsMenu(int client, int categoryId, int itemId)
{
	Menu menu = new Menu(MenuHandlerInventoryItemOptions);
	menu.ExitBackButton = true;
	
	char itemName[64];
	strcopy(itemName, sizeof(itemName), hubItems[categoryId][itemId].name);
	
	menu.SetTitle(itemName);
	
	// Determine the cosmetic type from category name
	char categoryName[64];
	Format(categoryName, sizeof(categoryName), "%s", hubCategories[categoryId].name);
	
	char selectionType[32];
	GetSelectionTypeFromCategory(categoryName, selectionType, sizeof(selectionType));
	bool isColorCategory = (StrContains(categoryName, "Chat Color", false) != -1 || StrContains(categoryName, "Name Color", false) != -1);
	
	// Check if this item is currently equipped
	bool isEquipped = Inventory_IsSelectionEquipped(client, selectionType, itemName);
	bool isChatEquipped = Inventory_IsSelectionEquipped(client, SELECTION_CHAT_COLOR, itemName);
	bool isNameEquipped = Inventory_IsSelectionEquipped(client, SELECTION_NAME_COLOR, itemName);
	
	// Build info strings with action + item context
	char info[80];

	if (isColorCategory)
	{
		if (isChatEquipped)
		{
			Format(info, sizeof(info), "unequip_chat:%d:%d:%s", categoryId, itemId, SELECTION_CHAT_COLOR);
			menu.AddItem(info, "Unequip Chat Color", ITEMDRAW_DEFAULT);
		}
		else
		{
			Format(info, sizeof(info), "equip_chat:%d:%d:%s", categoryId, itemId, SELECTION_CHAT_COLOR);
			menu.AddItem(info, "Equip as Chat Color", ITEMDRAW_DEFAULT);
		}

		if (isNameEquipped)
		{
			Format(info, sizeof(info), "unequip_name:%d:%d:%s", categoryId, itemId, SELECTION_NAME_COLOR);
			menu.AddItem(info, "Unequip Name Color", ITEMDRAW_DEFAULT);
		}
		else
		{
			Format(info, sizeof(info), "equip_name:%d:%d:%s", categoryId, itemId, SELECTION_NAME_COLOR);
			menu.AddItem(info, "Equip as Name Color", ITEMDRAW_DEFAULT);
		}
	}
	else
	{
		if (isEquipped)
		{
			Format(info, sizeof(info), "unequip:%d:%d:%s", categoryId, itemId, selectionType);
			menu.AddItem(info, "Unequip", ITEMDRAW_DEFAULT);
		}
		else
		{
			Format(info, sizeof(info), "equip:%d:%d:%s", categoryId, itemId, selectionType);
			menu.AddItem(info, "Equip", ITEMDRAW_DEFAULT);
		}
	}

	int sellPrice = hubPlayersItems[client][itemId].purchasePrice / 3;
	Format(info, sizeof(info), "sell:%d:%d:%s", categoryId, itemId, selectionType);
	if (sellPrice > 0)
	{
		char sellDisplay[64];
		Format(sellDisplay, sizeof(sellDisplay), "Sell (+%d credits)", sellPrice);
		menu.AddItem(info, sellDisplay, ITEMDRAW_DEFAULT);
	}
	else
	{
		menu.AddItem(info, "Sell (Not sellable)", ITEMDRAW_DISABLED);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

/**
 * Handle inventory item options (equip/unequip).
 */
public int MenuHandlerInventoryItemOptions(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[64];
			menu.GetItem(param2, strOption, sizeof(strOption));
			
			// Parse action:categoryId:itemId:selectionType format
			char parts[4][32];
			int partCount = ExplodeString(strOption, ":", parts, sizeof(parts), sizeof(parts[]));

			if (partCount < 3)
			{
				return 1;
			}

			char action[16];
			strcopy(action, sizeof(action), parts[0]);

			int categoryId = StringToInt(parts[1]);
			int itemId = StringToInt(parts[2]);
			char selectionType[32];
			selectionType[0] = '\0';
			if (partCount >= 4)
			{
				strcopy(selectionType, sizeof(selectionType), parts[3]);
			}
			
				char itemName[64];
				strcopy(itemName, sizeof(itemName), hubItems[categoryId][itemId].name);
				char categoryName[64];
				strcopy(categoryName, sizeof(categoryName), hubCategories[categoryId].name);
				bool isColorCategory = (StrContains(categoryName, "Chat Color", false) != -1 || StrContains(categoryName, "Name Color", false) != -1);

				if (StrEqual(action, "equip"))
				{
					// Equip the item
					EquipInventoryItem(param1, selectionType, itemName, categoryId, itemId);
					CPrintToChat(param1, "%t", "Hub_Inventory_Item_Equipped", itemName);
				}
				else if (StrEqual(action, "equip_chat"))
				{
					EquipInventoryItem(param1, SELECTION_CHAT_COLOR, itemName, categoryId, itemId);
					CPrintToChat(param1, "%t", "Hub_Inventory_Item_Equipped", itemName);
				}
				else if (StrEqual(action, "equip_name"))
				{
					EquipInventoryItem(param1, SELECTION_NAME_COLOR, itemName, categoryId, itemId);
					CPrintToChat(param1, "%t", "Hub_Inventory_Item_Equipped", itemName);
				}
				else if (StrEqual(action, "unequip"))
				{
					// Unequip the item
					UnequipInventoryItem(param1, selectionType);
					CPrintToChat(param1, "%t", "Hub_Inventory_Item_Unequipped", itemName);
				}
				else if (StrEqual(action, "unequip_chat"))
				{
					UnequipInventoryItem(param1, SELECTION_CHAT_COLOR);
					CPrintToChat(param1, "%t", "Hub_Inventory_Item_Unequipped", itemName);
				}
				else if (StrEqual(action, "unequip_name"))
				{
					UnequipInventoryItem(param1, SELECTION_NAME_COLOR);
					CPrintToChat(param1, "%t", "Hub_Inventory_Item_Unequipped", itemName);
				}
				else if (StrEqual(action, "sell"))
				{
					bool isEquipped = false;
					if (isColorCategory)
					{
						if (Inventory_IsSelectionEquipped(param1, SELECTION_CHAT_COLOR, itemName))
						{
							UnequipInventoryItem(param1, SELECTION_CHAT_COLOR);
							isEquipped = true;
						}
						if (Inventory_IsSelectionEquipped(param1, SELECTION_NAME_COLOR, itemName))
						{
							UnequipInventoryItem(param1, SELECTION_NAME_COLOR);
							isEquipped = true;
						}
					}
					else if (selectionType[0] != '\0')
					{
						isEquipped = Inventory_IsSelectionEquipped(param1, selectionType, itemName);
					}

					if (isEquipped)
					{
						if (!isColorCategory)
						{
							UnequipInventoryItem(param1, selectionType);
						}
					}

				int sellPrice = 0;
				StateSellPlayerItem sellState = SellHubPlayerItem(param1, itemId, sellPrice);

				switch (sellState)
				{
					case SELL_NOT_OWNED:
					{
						CPrintToChat(param1, "%t", "Hub_Inventory_Item_Not_Owned", itemName);
					}
					case SELL_NOT_SELLABLE:
					{
						CPrintToChat(param1, "%t", "Hub_Inventory_Item_Not_Sellable", itemName);
					}
					case SELL_SUCCESS:
					{
						CPrintToChat(param1, "%t", "Hub_Inventory_Item_Sold", itemName, sellPrice);
					}
					default:
					{
						CPrintToChat(param1, "%t", "Hub_Inventory_Item_Sell_Failed");
					}
				}
			}
			
			// Return to the inventory items menu
			CreateInventoryItemsMenu(param1, categoryId);
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
	
	return 1;
}

/**
 * Equip an inventory item.
 * 
 * @param client         Client index
 * @param selectionType  Selection type (e.g., SELECTION_TAG)
 * @param itemName       Name of the item
 * @param categoryId     Category ID
 * @param itemId         Item ID
 */
void EquipInventoryItem(int client, const char[] selectionType, const char[] itemName, int categoryId, int itemId)
{
	if (selectionType[0] == '\0')
	{
		return;
	}
	
	// Create JSON data for the selection
	JSON_Object data = new JSON_Object();
	data.SetInt("id", itemId);
	data.SetString("name", itemName);
	data.SetInt("category_id", categoryId);

	char selectionValue[64];
	strcopy(selectionValue, sizeof(selectionValue), itemName);

	// Color selections must store a parseable color value (hex/team/etc), not display name.
	if (StrEqual(selectionType, SELECTION_CHAT_COLOR) || StrEqual(selectionType, SELECTION_NAME_COLOR) || StrEqual(selectionType, SELECTION_TAG_COLOR))
	{
		char colorValue[16];
		if (Inventory_GetColorValueByName(itemName, colorValue, sizeof(colorValue)))
		{
			strcopy(selectionValue, sizeof(selectionValue), colorValue);
		}
	}

	data.SetString("value", selectionValue);
	
	// Set the selection through the proper system
	Selections_SetPlayer(client, selectionType, data);
	
	// Apply the cosmetic based on type
	ApplyCosmeticFromInventory(client, selectionType, itemName);
}

/**
 * Unequip an inventory item.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 */
void UnequipInventoryItem(int client, const char[] selectionType)
{
	if (selectionType[0] == '\0')
	{
		return;
	}
	
	// Clear the selection
	Selections_ClearPlayer(client, selectionType);
	
	// Clear the cosmetic effect
	ClearCosmeticFromInventory(client, selectionType);
}

/**
 * Apply a cosmetic from inventory selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 * @param itemName       Item name
 */
void ApplyCosmeticFromInventory(int client, const char[] selectionType, const char[] itemName)
{
	if (StrEqual(selectionType, SELECTION_TAG))
	{
		// Apply tag - find the tag by name and apply
		Tags_ApplyByName(client, itemName);
	}
	else if (StrEqual(selectionType, SELECTION_TRAIL))
	{
		// Apply trail - find trail by name and apply
		Trails_ApplyByName(client, itemName);
	}
	else if (StrEqual(selectionType, SELECTION_FOOTPRINT))
	{
		// Apply footprint
		Footprints_ApplyByName(client, itemName);
	}
	else if (StrEqual(selectionType, SELECTION_SPAWN_PARTICLE))
	{
		// Apply spawn particle - sets the selection so it shows on next spawn
		SpawnParticles_ApplyByName(client, itemName);
	}
	else if (StrEqual(selectionType, SELECTION_CHAT_COLOR) || StrEqual(selectionType, SELECTION_NAME_COLOR) || StrEqual(selectionType, SELECTION_TAG_COLOR))
	{
		char colorValue[16];
		Selections_GetPlayerString(client, selectionType, "value", colorValue, sizeof(colorValue), "");
		if (colorValue[0] == '\0')
		{
			return;
		}

		int color = 0;
		HubChatColorType colorType = HubChat_ParseColorString(colorValue, color);
		if (colorType == HubChatColor_None && !StrEqual(colorValue, "none", false) && !StrEqual(colorValue, "default", false))
		{
			return;
		}

		if (StrEqual(selectionType, SELECTION_CHAT_COLOR))
		{
			HubChat_SetClientChatColor(client, colorType, color);
		}
		else if (StrEqual(selectionType, SELECTION_NAME_COLOR))
		{
			HubChat_SetClientNameColor(client, colorType, color);
		}
		else
		{
			HubChat_SetClientTagColor(client, colorType, color);
		}
	}
}

/**
 * Clear a cosmetic from inventory.
 * 
 * @param client         Client index
 * @param selectionType  Selection type
 */
void ClearCosmeticFromInventory(int client, const char[] selectionType)
{
	if (StrEqual(selectionType, SELECTION_TAG))
	{
		Tags_Clear(client);
	}
	else if (StrEqual(selectionType, SELECTION_TRAIL))
	{
		Trails_Clear(client);
	}
	else if (StrEqual(selectionType, SELECTION_FOOTPRINT))
	{
		Footprints_Clear(client);
	}
	else if (StrEqual(selectionType, SELECTION_SPAWN_PARTICLE))
	{
		SpawnParticles_Clear(client);
	}
	else if (StrEqual(selectionType, SELECTION_CHAT_COLOR))
	{
		HubChat_SetClientChatColor(client, HubChatColor_None, 0);
	}
	else if (StrEqual(selectionType, SELECTION_NAME_COLOR))
	{
		HubChat_SetClientNameColor(client, HubChatColor_Team, 0);
	}
	else if (StrEqual(selectionType, SELECTION_TAG_COLOR))
	{
		HubChat_SetClientTagColor(client, HubChatColor_None, 0);
	}
}
