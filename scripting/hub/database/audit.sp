/**
 * HubCore Audit Log System
 * 
 * Tracks all important player actions for debugging, analytics, and rollback support.
 */

// Audit event type constants
#define AUDIT_PLAYER_LOGIN          "player_login"
#define AUDIT_PLAYER_LOGOUT         "player_logout"
#define AUDIT_CREDITS_ADDED         "credits_added"
#define AUDIT_CREDITS_REMOVED       "credits_removed"
#define AUDIT_CREDITS_SET           "credits_set"
#define AUDIT_ITEM_PURCHASED        "item_purchased"
#define AUDIT_ITEM_EQUIPPED         "item_equipped"
#define AUDIT_ITEM_UNEQUIPPED       "item_unequipped"
#define AUDIT_ITEM_REMOVED          "item_removed"
#define AUDIT_COSMETIC_CHANGED      "cosmetic_changed"
#define AUDIT_COSMETIC_CLEARED      "cosmetic_cleared"
#define AUDIT_SETTING_CHANGED       "setting_changed"
#define AUDIT_COINFLIP_WIN          "coinflip_win"
#define AUDIT_COINFLIP_LOSE         "coinflip_lose"
#define AUDIT_DAILY_CLAIMED         "daily_claimed"
#define AUDIT_SELECTION_SET         "selection_set"
#define AUDIT_SELECTION_CLEARED     "selection_cleared"

// Source constants
#define AUDIT_SOURCE_CORE           "core"
#define AUDIT_SOURCE_SHOP           "shop"
#define AUDIT_SOURCE_CREDITS        "credits"
#define AUDIT_SOURCE_GAMBLING       "gambling"
#define AUDIT_SOURCE_COSMETICS      "cosmetics"
#define AUDIT_SOURCE_ADMIN          "admin"
#define AUDIT_SOURCE_SYSTEM         "system"

/**
 * Log an audit event for a client.
 * 
 * @param client     Client index
 * @param eventType  Type of event (use AUDIT_* constants)
 * @param eventData  JSON string of event data
 * @param source     Source of the event (use AUDIT_SOURCE_* constants)
 */
void Audit_Log(int client, const char[] eventType, const char[] eventData, const char[] source)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    char steamId[32], ip[45];
    GetSteamId(client, steamId, sizeof(steamId));
    GetClientIP(client, ip, sizeof(ip));
    
    Audit_LogBySteamId(steamId, eventType, eventData, source, ip);
}

/**
 * Log an audit event by SteamID.
 * 
 * @param steamId    Player's SteamID
 * @param eventType  Type of event
 * @param eventData  JSON string of event data
 * @param source     Source of the event
 * @param ip         Optional IP address
 */
void Audit_LogBySteamId(const char[] steamId, const char[] eventType, const char[] eventData, 
                         const char[] source, const char[] ip = "")
{
    if (DB == INVALID_HANDLE)
    {
        return;
    }
    
    char query[2048];
    char escapedSteamId[64], escapedEventType[100], escapedEventData[1024];
    char escapedSource[100], escapedIp[64];
    
    DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
    DB.Escape(eventType, escapedEventType, sizeof(escapedEventType));
    DB.Escape(eventData, escapedEventData, sizeof(escapedEventData));
    DB.Escape(source, escapedSource, sizeof(escapedSource));
    DB.Escape(ip, escapedIp, sizeof(escapedIp));
    
    if (strlen(ip) > 0)
    {
        Format(query, sizeof(query),
            "INSERT INTO `%saudit_log` (`steamid`, `event_type`, `event_data`, `source`, `ip_address`) VALUES ('%s', '%s', '%s', '%s', '%s');",
            databasePrefix, escapedSteamId, escapedEventType, escapedEventData, escapedSource, escapedIp);
    }
    else
    {
        Format(query, sizeof(query),
            "INSERT INTO `%saudit_log` (`steamid`, `event_type`, `event_data`, `source`) VALUES ('%s', '%s', '%s', '%s');",
            databasePrefix, escapedSteamId, escapedEventType, escapedEventData, escapedSource);
    }
    
    DB.Query(ErrorCheckCallback, query);
}

/**
 * Log an audit event with old and new values for tracking changes.
 * 
 * @param client     Client index
 * @param eventType  Type of event
 * @param eventData  JSON string of event data
 * @param oldValue   JSON string of old value
 * @param newValue   JSON string of new value
 * @param source     Source of the event
 */
void Audit_LogWithValues(int client, const char[] eventType, const char[] eventData, 
                          const char[] oldValue, const char[] newValue, const char[] source)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    char steamId[32], ip[45];
    GetSteamId(client, steamId, sizeof(steamId));
    GetClientIP(client, ip, sizeof(ip));
    
    Audit_LogWithValuesBySteamId(steamId, eventType, eventData, oldValue, newValue, source, ip);
}

/**
 * Log an audit event with old and new values by SteamID.
 * 
 * @param steamId    Player's SteamID
 * @param eventType  Type of event
 * @param eventData  JSON string of event data
 * @param oldValue   JSON string of old value
 * @param newValue   JSON string of new value
 * @param source     Source of the event
 * @param ip         Optional IP address
 */
void Audit_LogWithValuesBySteamId(const char[] steamId, const char[] eventType, const char[] eventData,
                                   const char[] oldValue, const char[] newValue, const char[] source,
                                   const char[] ip = "")
{
    if (DB == INVALID_HANDLE)
    {
        return;
    }
    
    char query[4096];
    char escapedSteamId[64], escapedEventType[100], escapedEventData[1024];
    char escapedOldValue[1024], escapedNewValue[1024];
    char escapedSource[100], escapedIp[64];
    
    DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
    DB.Escape(eventType, escapedEventType, sizeof(escapedEventType));
    DB.Escape(eventData, escapedEventData, sizeof(escapedEventData));
    DB.Escape(oldValue, escapedOldValue, sizeof(escapedOldValue));
    DB.Escape(newValue, escapedNewValue, sizeof(escapedNewValue));
    DB.Escape(source, escapedSource, sizeof(escapedSource));
    DB.Escape(ip, escapedIp, sizeof(escapedIp));
    
    if (strlen(ip) > 0)
    {
        Format(query, sizeof(query),
            "INSERT INTO `%saudit_log` (`steamid`, `event_type`, `event_data`, `old_value`, `new_value`, `source`, `ip_address`) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s');",
            databasePrefix, escapedSteamId, escapedEventType, escapedEventData, 
            escapedOldValue, escapedNewValue, escapedSource, escapedIp);
    }
    else
    {
        Format(query, sizeof(query),
            "INSERT INTO `%saudit_log` (`steamid`, `event_type`, `event_data`, `old_value`, `new_value`, `source`) VALUES ('%s', '%s', '%s', '%s', '%s', '%s');",
            databasePrefix, escapedSteamId, escapedEventType, escapedEventData, 
            escapedOldValue, escapedNewValue, escapedSource);
    }
    
    DB.Query(ErrorCheckCallback, query);
}

/**
 * Log a credit change event.
 * 
 * @param client     Client index
 * @param oldCredits Previous credit amount
 * @param newCredits New credit amount
 * @param reason     Reason for the change
 * @param source     Source of the event
 */
void Audit_LogCreditChange(int client, int oldCredits, int newCredits, const char[] reason, const char[] source)
{
    int diff = newCredits - oldCredits;
    char eventType[64];
    
    if (diff > 0)
    {
        strcopy(eventType, sizeof(eventType), AUDIT_CREDITS_ADDED);
    }
    else if (diff < 0)
    {
        strcopy(eventType, sizeof(eventType), AUDIT_CREDITS_REMOVED);
    }
    else
    {
        strcopy(eventType, sizeof(eventType), AUDIT_CREDITS_SET);
    }
    
    char eventData[256], oldValue[64], newValue[64];
    Format(eventData, sizeof(eventData), "{\"reason\":\"%s\",\"diff\":%d}", reason, diff);
    Format(oldValue, sizeof(oldValue), "{\"credits\":%d}", oldCredits);
    Format(newValue, sizeof(newValue), "{\"credits\":%d}", newCredits);
    
    Audit_LogWithValues(client, eventType, eventData, oldValue, newValue, source);
}

/**
 * Log an item purchase event.
 * 
 * @param client    Client index
 * @param itemId    Item ID purchased
 * @param itemName  Item name
 * @param price     Price paid
 */
void Audit_LogPurchase(int client, int itemId, const char[] itemName, int price)
{
    char eventData[512];
    char escapedName[128];
    
    // Escape item name for JSON
    strcopy(escapedName, sizeof(escapedName), itemName);
    ReplaceString(escapedName, sizeof(escapedName), "\"", "\\\"");
    
    Format(eventData, sizeof(eventData), 
        "{\"item_id\":%d,\"item_name\":\"%s\",\"price\":%d}",
        itemId, escapedName, price);
    
    Audit_Log(client, AUDIT_ITEM_PURCHASED, eventData, AUDIT_SOURCE_SHOP);
}

/**
 * Log a coinflip result.
 * 
 * @param client     Client index
 * @param bet        Amount bet
 * @param won        Whether the player won
 * @param payout     Amount won/lost
 * @param multiplier Multiplier used
 */
void Audit_LogCoinflip(int client, int bet, bool won, int payout, float multiplier)
{
    char eventType[64], eventData[256];
    char oldValue[64], newValue[64];
    int oldCredits = hubPlayers[client].credits;
    int newCredits = won ? (oldCredits + payout) : (oldCredits - bet);
    
    strcopy(eventType, sizeof(eventType), won ? AUDIT_COINFLIP_WIN : AUDIT_COINFLIP_LOSE);
    
    Format(eventData, sizeof(eventData), 
        "{\"bet\":%d,\"won\":%s,\"payout\":%d,\"multiplier\":%.2f}",
        bet, won ? "true" : "false", payout, multiplier);
    Format(oldValue, sizeof(oldValue), "{\"credits\":%d}", oldCredits);
    Format(newValue, sizeof(newValue), "{\"credits\":%d}", newCredits);
    
    Audit_LogWithValues(client, eventType, eventData, oldValue, newValue, AUDIT_SOURCE_GAMBLING);
}

/**
 * Log a cosmetic change.
 * 
 * @param client        Client index
 * @param cosmeticType  Type of cosmetic (tag, trail, footprint, etc.)
 * @param oldValue      Previous cosmetic value
 * @param newValue      New cosmetic value
 */
void Audit_LogCosmeticChange(int client, const char[] cosmeticType, const char[] oldValue, const char[] newValue)
{
    char eventData[256];
    char escapedOld[128], escapedNew[128];
    
    strcopy(escapedOld, sizeof(escapedOld), oldValue);
    strcopy(escapedNew, sizeof(escapedNew), newValue);
    ReplaceString(escapedOld, sizeof(escapedOld), "\"", "\\\"");
    ReplaceString(escapedNew, sizeof(escapedNew), "\"", "\\\"");
    
    Format(eventData, sizeof(eventData), "{\"type\":\"%s\"}", cosmeticType);
    
    char oldJson[256], newJson[256];
    Format(oldJson, sizeof(oldJson), "{\"value\":\"%s\"}", escapedOld);
    Format(newJson, sizeof(newJson), "{\"value\":\"%s\"}", escapedNew);
    
    Audit_LogWithValues(client, AUDIT_COSMETIC_CHANGED, eventData, oldJson, newJson, AUDIT_SOURCE_COSMETICS);
}

/**
 * Log a setting change.
 * 
 * @param client       Client index
 * @param settingName  Name of the setting
 * @param oldValue     Previous value
 * @param newValue     New value
 */
void Audit_LogSettingChange(int client, const char[] settingName, const char[] oldValue, const char[] newValue)
{
    char eventData[256];
    char escapedOld[128], escapedNew[128];
    
    strcopy(escapedOld, sizeof(escapedOld), oldValue);
    strcopy(escapedNew, sizeof(escapedNew), newValue);
    ReplaceString(escapedOld, sizeof(escapedOld), "\"", "\\\"");
    ReplaceString(escapedNew, sizeof(escapedNew), "\"", "\\\"");
    
    Format(eventData, sizeof(eventData), "{\"setting\":\"%s\"}", settingName);
    
    char oldJson[256], newJson[256];
    Format(oldJson, sizeof(oldJson), "{\"value\":\"%s\"}", escapedOld);
    Format(newJson, sizeof(newJson), "{\"value\":\"%s\"}", escapedNew);
    
    Audit_LogWithValues(client, AUDIT_SETTING_CHANGED, eventData, oldJson, newJson, AUDIT_SOURCE_CORE);
}

/**
 * Log player login event.
 * 
 * @param client  Client index
 */
void Audit_LogLogin(int client)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    
    char escapedName[MAX_NAME_LENGTH * 2];
    strcopy(escapedName, sizeof(escapedName), name);
    ReplaceString(escapedName, sizeof(escapedName), "\"", "\\\"");
    
    char eventData[256];
    Format(eventData, sizeof(eventData), "{\"name\":\"%s\"}", escapedName);
    
    Audit_Log(client, AUDIT_PLAYER_LOGIN, eventData, AUDIT_SOURCE_CORE);
}

/**
 * Log player logout event.
 * 
 * @param client       Client index
 * @param playTime     Session play time in seconds
 */
void Audit_LogLogout(int client, int playTime)
{
    if (!IsValidPlayer(client))
    {
        return;
    }
    
    char eventData[256];
    Format(eventData, sizeof(eventData), "{\"session_play_time\":%d,\"credits\":%d}", 
        playTime, hubPlayers[client].credits);
    
    Audit_Log(client, AUDIT_PLAYER_LOGOUT, eventData, AUDIT_SOURCE_CORE);
}
