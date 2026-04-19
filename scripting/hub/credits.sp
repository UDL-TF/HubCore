enum Coinflip
{
	COINFLIP_HEAD,
	COINFLIP_TAIL
}

enum struct CreditPlayers
{
	Handle	 currentCreditsPerMinute;
	Coinflip currentCoinflip;
	int			 currentCoinflipAmount;
	int			 coinflipLastUsed;
}

CreditPlayers creditPlayers[MAXPLAYERS + 1];

void					CreditsOnStart()
{
	RegConsoleCmd("sm_credits", CommandCredits, "Shows clients credits.");
	RegConsoleCmd("sm_coins", CommandCredits, "Shows clients credits.");
	RegConsoleCmd("sm_coinflip", CommandCoinflip, "Coinflip.");
	RegConsoleCmd("sm_daily", CommandDaily, "Claim your daily credit reward.");

	// Create ConVars
	Hub_Credits_Minute									= CreateConVar("hub_credits_minute", "4", "How minutes when to give credits.");
	Hub_Credits_Amount									= CreateConVar("hub_credits_amount", "20", "How many credits to give per minute.");
	Hub_Credits_Coinflip_Multiplier			= CreateConVar("hub_credits_coinflip_multiplier", "1.1", "How much to multiply the coinflip amount by.");
	Hub_Credits_Coinflip_Cooldown				= CreateConVar("hub_credits_coinflip_cooldown", "15", "Cooldown in seconds between coinflip uses.");
	Hub_Credits_Kill_For_Credits				= CreateConVar("hub_credits_kill_for_credits", "1", "Get credits when you kill someone, either enabled or not.", _, true, 0.0, true, 1.0);
	Hub_Credits_Kill_For_Credits_Points = CreateConVar("hub_credits_kill_for_credits_points", "2", "How much points to give/extract when death.");
	Hub_Daily_Base_Credits = CreateConVar("hub_daily_base_credits", "100", "Base credits awarded for the daily reward.");

	HookConVarChange(Hub_Credits_Minute, CreditsMinuteChange);
	HookEvent("player_death", CreditsOnPlayerDeath);

	for (int i = 1; i <= MaxClients; i++)
	{
		CreditsBootstrapClient(i);
	}
}

void CreditsAskPluginLoad2() {}

/* Events */
public void CreditsMinuteChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (!IsValidPlayer(i)) continue;

		if (creditPlayers[i].currentCreditsPerMinute != INVALID_HANDLE)
		{
			CloseHandle(creditPlayers[i].currentCreditsPerMinute);
		}

		CreditsBootstrapClient(i);
	}
}

void CreditsOnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	CloseHandle(creditPlayers[client].currentCreditsPerMinute);
	creditPlayers[client].coinflipLastUsed			= 0;
	creditPlayers[client].currentCoinflipAmount = 0;
}

void CreditsOnClientPostAdminCheck(int client)
{
	CreditsBootstrapClient(client);
}

/* Timers */
public Action Timer_Credits(Handle timer, int client)
{
	int amount = Hub_Credits_Amount.IntValue;

	if (amount <= 0) return Plugin_Continue;

	Core_AddPlayerCredits(client, amount);

	Cookie cookie			 = GetCookieByName(HUB_COOKIE_DISABLED_CREDIT_RECEIVED_MESSAGE);
	int		 cookieValue = GetCookieValue(client, cookie);

	if (cookieValue != 1)
		CPrintToChat(client, "%t", HUB_PHRASE_PLAYER_RECIEVE_CREDITS, amount);

	return Plugin_Continue;
}

/* Methods */
public void CreditsBootstrapClient(int client)
{
	if (!IsValidPlayer(client)) return;
	float minToSecond															= Hub_Credits_Minute.FloatValue * 60;
	creditPlayers[client].currentCreditsPerMinute = CreateTimer(minToSecond, Timer_Credits, client, TIMER_REPEAT);
}

public void DecideCoinflip(int client)
{
	if (!IsValidPlayer(client)) return;

	int amount = creditPlayers[client].currentCoinflipAmount;

	if (amount <= 0) return;

	int currentAmount = Core_GetPlayerCredits(client);

	if (amount > currentAmount)
	{
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_COINFLIP_NOT_ENOUGH_CREDITS);
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	int random = GetRandomInt(0, 1);
	float multiplier = Hub_Credits_Coinflip_Multiplier.FloatValue;

	if (random == view_as<int>(creditPlayers[client].currentCoinflip))
	{
		int payout = RoundToCeil(amount * multiplier);
		Core_AddPlayerCredits(client, payout);
		
		// Audit log the coinflip win
		Audit_LogCoinflip(client, amount, true, payout, multiplier);
		
		CPrintToChatAll("%t", HUB_PHRASE_CREDITS_COINFLIP_WIN, payout, name);
	}
	else
	{
		Core_RemovePlayerCredits(client, amount);
		
		// Audit log the coinflip loss
		Audit_LogCoinflip(client, amount, false, amount, multiplier);
		
		CPrintToChatAll("%t", HUB_PHRASE_CREDITS_COINFLIP_LOSE, amount, name);
	}

	creditPlayers[client].currentCoinflip				= view_as<Coinflip>(INVALID_HANDLE);
	creditPlayers[client].currentCoinflipAmount = view_as<int>(INVALID_HANDLE);
}

/* Commands */
public Action CommandCredits(int client, int args)
{
	int	 credits = Core_GetPlayerCredits(client);

	char name[32];
	GetClientName(client, name, sizeof(name));

	// Send message back to client
	CPrintToChatAll("%t", HUB_PHRASE_PLAYER_CREDITS, credits, name);

	return Plugin_Handled;
}

public Action CommandCoinflip(int client, int args)
{
	if (args < 1)
	{
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_COINFLIP_USAGE);
		return Plugin_Handled;
	}

	int cooldown = Hub_Credits_Coinflip_Cooldown.IntValue;
	int elapsed	 = GetTime() - creditPlayers[client].coinflipLastUsed;

	if (elapsed < cooldown)
	{
		int remaining = cooldown - elapsed;
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_COINFLIP_COOLDOWN, remaining);
		return Plugin_Handled;
	}

	int currentAmount = Core_GetPlayerCredits(client);
	int amount				= GetCmdArgInt(1);

	// Can't bet more than you have
	if (amount > currentAmount)
	{
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_COINFLIP_NOT_ENOUGH_CREDITS);
		return Plugin_Handled;
	}

	creditPlayers[client].currentCoinflipAmount = amount;
	creditPlayers[client].coinflipLastUsed			= GetTime();

	DisplayCoinflipMenu(client);

	return Plugin_Handled;
}

// Hooks
public void CreditsOnPlayerDeath(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	int client	 = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if (!IsValidPlayer(client) || !IsValidPlayer(attacker)) return;

	if (client == attacker) return;

	if (Hub_Credits_Kill_For_Credits.BoolValue)
	{
		int victimCredits = Core_GetPlayerCredits(client);
		int points = Hub_Credits_Kill_For_Credits_Points.IntValue;
		int transferAmount = victimCredits < points ? victimCredits : points;

		if (transferAmount <= 0) return;

		char attackerName[MAX_NAME_LENGTH];
		GetClientName(attacker, attackerName, sizeof(attackerName));
		char clientName[MAX_NAME_LENGTH];
		GetClientName(client, clientName, sizeof(clientName));

		Core_RemovePlayerCredits(client, transferAmount);
		Core_AddPlayerCredits(attacker, transferAmount);

		Cookie creditMessageCookie = GetCookieByName(HUB_COOKIE_DISABLED_CREDIT_KILL_REWARD_MESSAGE);
		int		 attackerValue			 = GetCookieValue(attacker, creditMessageCookie);
		int		 clientValue				 = GetCookieValue(client, creditMessageCookie);

		if (clientValue != 1)
			CPrintToChat(client, "%t", HUB_CREDITS_EARNED_POINTS_DIED, transferAmount, attackerName);

		if (attackerValue != 1)
			CPrintToChat(attacker, "%t", HUB_PHRASE_EARNED_POINTS_KILLED, transferAmount, clientName);
	}
}

/* Menus */
void DisplayCoinflipMenu(int client)
{
	Menu hMenu = new Menu(CoinflipMenuHandler);

	hMenu.SetTitle("Coinflip");
	hMenu.AddItem("0", "Heads", ITEMDRAW_DEFAULT);
	hMenu.AddItem("1", "Tails", ITEMDRAW_DEFAULT);

	hMenu.ExitButton = true;

	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int CoinflipMenuHandler(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int iOption = StringToInt(strOption);

			switch (iOption)
			{
				case 0:
				{
					creditPlayers[param1].currentCoinflip = COINFLIP_HEAD;
					DecideCoinflip(param1);
				}

				case 1:
				{
					creditPlayers[param1].currentCoinflip = COINFLIP_TAIL;
					DecideCoinflip(param1);
				}
			}
		}
	}

	return 1;
}

/* Daily reward */
public Action CommandDaily(int client, int args)
{
	if (!IsValidPlayer(client)) return Plugin_Handled;

	char steamId[32];
	GetSteamId(client, steamId, sizeof(steamId));
	HubDB.GetPlayerTimer(steamId, "daily", OnDailyTimerLoaded, GetClientUserId(client));

	return Plugin_Handled;
}

public void OnDailyTimerLoaded(Database db, DBResultSet results, const char[] error, int userId)
{
	int client = GetClientOfUserId(userId);
	if (client == 0) return;

	if (results == null)
	{
		LogToFile(logFile, "[Daily] Failed to query timer: %s", error);
		CPrintToChat(client, "%t", HUB_PHRASE_SOMETHING_WENT_WRONG);
		return;
	}

	int streak = 1;

	if (results.FetchRow())
	{
		int secondsAgo    = results.FetchInt(0);
		int currentStreak = results.FetchInt(2);

		// Already claimed in the last 24 hours
		if (secondsAgo < 86400)
		{
			int remaining = 86400 - secondsAgo;
			int hours     = remaining / 3600;
			int minutes   = (remaining % 3600) / 60;
			CPrintToChat(client, "%t", HUB_PHRASE_DAILY_ALREADY_CLAIMED, hours, minutes);
			return;
		}

		// Streak continues if claimed within 48 hours, otherwise reset
		streak = (secondsAgo <= 172800) ? (currentStreak + 1) : 1;
	}

	int baseCredits = Hub_Daily_Base_Credits.IntValue;
	int bonus       = (streak - 1) * 5;
	int total       = baseCredits + bonus;

	Core_AddPlayerCredits(client, total);

	char steamId[32];
	GetSteamId(client, steamId, sizeof(steamId));
	HubDB.UpsertPlayerTimer(steamId, "daily", streak);

	char eventData[128];
	Format(eventData, sizeof(eventData), "{\"credits\":%d,\"streak\":%d,\"bonus\":%d}", total, streak, bonus);
	Audit_Log(client, AUDIT_DAILY_CLAIMED, eventData, AUDIT_SOURCE_CREDITS);

	if (bonus > 0)
		CPrintToChat(client, "%t", HUB_PHRASE_DAILY_CLAIMED_STREAK, total, streak, bonus);
	else
		CPrintToChat(client, "%t", HUB_PHRASE_DAILY_CLAIMED, total, streak);
}
