/**
 * HubCore Database Manager
 * 
 * Centralized API for all database operations.
 * Provides a clean interface for queries and transactions.
 */

/**
 * Methodmap for database operations.
 * All database operations should go through this class.
 */
methodmap HubDB
{
    /**
     * Get player data from hub_players_v2 table.
     * 
     * @param steamId   Player's SteamID
     * @param callback  Callback function for results
     * @param data      Optional data to pass to callback
     */
    public static void GetPlayer(const char[] steamId, SQLQueryCallback callback, any data = 0)
    {
        char query[512];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "SELECT `id`, `steamid`, `steamid64`, `name`, `ip`, `credits`, `first_join`, `last_seen`, `play_time_seconds`, `settings`, `cosmetics`, `metadata` FROM `%splayers_v2` WHERE `steamid` = '%s';",
            databasePrefix, escapedSteamId);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Get player by SteamID64.
     * 
     * @param steamId64  Player's SteamID64
     * @param callback   Callback function for results
     * @param data       Optional data to pass to callback
     */
    public static void GetPlayerBySteamId64(const char[] steamId64, SQLQueryCallback callback, any data = 0)
    {
        char query[512];
        
        Format(query, sizeof(query),
            "SELECT `id`, `steamid`, `steamid64`, `name`, `ip`, `credits`, `first_join`, `last_seen`, `play_time_seconds`, `settings`, `cosmetics`, `metadata` FROM `%splayers_v2` WHERE `steamid64` = %s;",
            databasePrefix, steamId64);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Insert or update player record.
     * 
     * @param steamId   Player's SteamID
     * @param steamId64 Player's SteamID64
     * @param name      Player's name
     * @param ip        Player's IP address
     * @param callback  Optional callback function
     * @param data      Optional data to pass to callback
     */
    public static void UpsertPlayer(const char[] steamId, const char[] steamId64, const char[] name, 
                                     const char[] ip, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[1024];
        char escapedSteamId[64], escapedName[128], escapedIp[64];
        
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        DB.Escape(name, escapedName, sizeof(escapedName));
        DB.Escape(ip, escapedIp, sizeof(escapedIp));
        
        Format(query, sizeof(query),
            "INSERT INTO `%splayers_v2` (`steamid`, `steamid64`, `name`, `ip`, `settings`, `cosmetics`, `metadata`) VALUES ('%s', %s, '%s', '%s', '{}', '{}', '{}') ON DUPLICATE KEY UPDATE `name` = '%s', `ip` = '%s', `last_seen` = CURRENT_TIMESTAMP;",
            databasePrefix, escapedSteamId, steamId64, escapedName, escapedIp, escapedName, escapedIp);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Update player credits.
     * 
     * @param steamId   Player's SteamID
     * @param credits   New credit amount
     * @param callback  Optional callback function
     * @param data      Optional data to pass to callback
     */
    public static void UpdateCredits(const char[] steamId, int credits, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[256];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "UPDATE `%splayers_v2` SET `credits` = %d WHERE `steamid` = '%s';",
            databasePrefix, credits, escapedSteamId);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Add credits to player (atomic operation).
     * 
     * @param steamId   Player's SteamID
     * @param amount    Amount to add
     * @param callback  Optional callback function
     * @param data      Optional data to pass to callback
     */
    public static void AddCredits(const char[] steamId, int amount, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[256];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "UPDATE `%splayers_v2` SET `credits` = `credits` + %d WHERE `steamid` = '%s';",
            databasePrefix, amount, escapedSteamId);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Remove credits from player (atomic operation).
     * 
     * @param steamId   Player's SteamID
     * @param amount    Amount to remove
     * @param callback  Optional callback function
     * @param data      Optional data to pass to callback
     */
    public static void RemoveCredits(const char[] steamId, int amount, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[256];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "UPDATE `%splayers_v2` SET `credits` = GREATEST(`credits` - %d, 0) WHERE `steamid` = '%s';",
            databasePrefix, amount, escapedSteamId);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Update player settings JSON.
     * 
     * @param steamId   Player's SteamID
     * @param settings  JSON string of settings
     * @param callback  Optional callback function
     * @param data      Optional data to pass to callback
     */
    public static void UpdateSettings(const char[] steamId, const char[] settings, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[2048];
        char escapedSteamId[64], escapedSettings[1024];
        
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        DB.Escape(settings, escapedSettings, sizeof(escapedSettings));
        
        Format(query, sizeof(query),
            "UPDATE `%splayers_v2` SET `settings` = '%s' WHERE `steamid` = '%s';",
            databasePrefix, escapedSettings, escapedSteamId);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Update player cosmetics JSON.
     * 
     * @param steamId    Player's SteamID
     * @param cosmetics  JSON string of cosmetics
     * @param callback   Optional callback function
     * @param data       Optional data to pass to callback
     */
    public static void UpdateCosmetics(const char[] steamId, const char[] cosmetics, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[4096];
        char escapedSteamId[64], escapedCosmetics[2048];
        
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        DB.Escape(cosmetics, escapedCosmetics, sizeof(escapedCosmetics));
        
        Format(query, sizeof(query),
            "UPDATE `%splayers_v2` SET `cosmetics` = '%s' WHERE `steamid` = '%s';",
            databasePrefix, escapedCosmetics, escapedSteamId);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Update player play time.
     * 
     * @param steamId         Player's SteamID
     * @param additionalTime  Seconds to add to play time
     * @param callback        Optional callback function
     * @param data            Optional data to pass to callback
     */
    public static void UpdatePlayTime(const char[] steamId, int additionalTime, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[256];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "UPDATE `%splayers_v2` SET `play_time_seconds` = `play_time_seconds` + %d WHERE `steamid` = '%s';",
            databasePrefix, additionalTime, escapedSteamId);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Get player's owned items.
     * 
     * @param steamId   Player's SteamID
     * @param callback  Callback function for results
     * @param data      Optional data to pass to callback
     */
    public static void GetPlayerItems(const char[] steamId, SQLQueryCallback callback, any data = 0)
    {
        char query[512];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "SELECT pi.`id`, pi.`item_id`, pi.`equipped`, pi.`purchase_price`, pi.`purchased_at`, i.`name`, i.`description`, i.`type`, i.`price`, i.`attributes` FROM `%splayer_items_v2` pi INNER JOIN `%sitems_v2` i ON pi.`item_id` = i.`id` WHERE pi.`steamid` = '%s' AND pi.`deleted_at` IS NULL;",
            databasePrefix, databasePrefix, escapedSteamId);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Add item to player's inventory.
     * 
     * @param steamId   Player's SteamID
     * @param itemId    Item ID to add
     * @param price     Price paid for the item
     * @param callback  Optional callback function
     * @param data      Optional data to pass to callback
     */
    public static void AddPlayerItem(const char[] steamId, int itemId, int price, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[512];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "INSERT INTO `%splayer_items_v2` (`steamid`, `item_id`, `purchase_price`) VALUES ('%s', %d, %d);",
            databasePrefix, escapedSteamId, itemId, price);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Check if player owns an item.
     * 
     * @param steamId   Player's SteamID
     * @param itemId    Item ID to check
     * @param callback  Callback function for results
     * @param data      Optional data to pass to callback
     */
    public static void HasPlayerItem(const char[] steamId, int itemId, SQLQueryCallback callback, any data = 0)
    {
        char query[256];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "SELECT 1 FROM `%splayer_items_v2` WHERE `steamid` = '%s' AND `item_id` = %d AND `deleted_at` IS NULL;",
            databasePrefix, escapedSteamId, itemId);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Soft delete a player's item.
     * 
     * @param steamId   Player's SteamID
     * @param itemId    Item ID to remove
     * @param callback  Optional callback function
     * @param data      Optional data to pass to callback
     */
    public static void RemovePlayerItem(const char[] steamId, int itemId, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[256];
        char escapedSteamId[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "UPDATE `%splayer_items_v2` SET `deleted_at` = CURRENT_TIMESTAMP WHERE `steamid` = '%s' AND `item_id` = %d AND `deleted_at` IS NULL;",
            databasePrefix, escapedSteamId, itemId);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Get ALL selections for a player.
     * 
     * @param steamId        Player's SteamID
     * @param callback       Callback function for results
     * @param data           Optional data to pass to callback
     */
    public static void GetAllSelections(const char[] steamId, SQLQueryCallback callback, any data = 0)
    {
        char query[512];
        char escapedSteamId[64];
        
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        
        Format(query, sizeof(query),
            "SELECT `selection_type`, `selection_value`, `extra_data` FROM `%splayer_selections` WHERE `steamid` = '%s';",
            databasePrefix, escapedSteamId);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Get or set a player selection.
     * 
     * @param steamId        Player's SteamID
     * @param selectionType  Type of selection (e.g., "tag", "trail")
     * @param callback       Callback function for results
     * @param data           Optional data to pass to callback
     */
    public static void GetSelection(const char[] steamId, const char[] selectionType, SQLQueryCallback callback, any data = 0)
    {
        char query[512];
        char escapedSteamId[64], escapedType[64];
        
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        DB.Escape(selectionType, escapedType, sizeof(escapedType));
        
        Format(query, sizeof(query),
            "SELECT `selection_value`, `extra_data` FROM `%splayer_selections` WHERE `steamid` = '%s' AND `selection_type` = '%s';",
            databasePrefix, escapedSteamId, escapedType);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Set a player selection.
     * 
     * @param steamId        Player's SteamID
     * @param selectionType  Type of selection
     * @param value          Selection value
     * @param extraData      Optional JSON extra data
     * @param callback       Optional callback function
     * @param data           Optional data to pass to callback
     */
    public static void SetSelection(const char[] steamId, const char[] selectionType, const char[] value, 
                                     const char[] extraData = "{}", SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[1024];
        char escapedSteamId[64], escapedType[64], escapedValue[256], escapedExtra[512];
        
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        DB.Escape(selectionType, escapedType, sizeof(escapedType));
        DB.Escape(value, escapedValue, sizeof(escapedValue));
        DB.Escape(extraData, escapedExtra, sizeof(escapedExtra));
        
        Format(query, sizeof(query),
            "INSERT INTO `%splayer_selections` (`steamid`, `selection_type`, `selection_value`, `extra_data`) VALUES ('%s', '%s', '%s', '%s') ON DUPLICATE KEY UPDATE `selection_value` = '%s', `extra_data` = '%s';",
            databasePrefix, escapedSteamId, escapedType, escapedValue, escapedExtra, escapedValue, escapedExtra);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Clear a player selection.
     * 
     * @param steamId        Player's SteamID
     * @param selectionType  Type of selection to clear
     * @param callback       Optional callback function
     * @param data           Optional data to pass to callback
     */
    public static void ClearSelection(const char[] steamId, const char[] selectionType, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[256];
        char escapedSteamId[64], escapedType[64];
        
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        DB.Escape(selectionType, escapedType, sizeof(escapedType));
        
        Format(query, sizeof(query),
            "DELETE FROM `%splayer_selections` WHERE `steamid` = '%s' AND `selection_type` = '%s';",
            databasePrefix, escapedSteamId, escapedType);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
    
    /**
     * Get all categories.
     * 
     * @param callback  Callback function for results
     * @param data      Optional data to pass to callback
     */
    public static void GetCategories(SQLQueryCallback callback, any data = 0)
    {
        char query[256];
        
        Format(query, sizeof(query),
            "SELECT `id`, `name`, `description`, `sort_order` FROM `%scategories_v2` WHERE `is_active` = TRUE ORDER BY `sort_order` ASC;",
            databasePrefix);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Get items by category.
     * 
     * @param categoryId  Category ID
     * @param callback    Callback function for results
     * @param data        Optional data to pass to callback
     */
    public static void GetItemsByCategory(int categoryId, SQLQueryCallback callback, any data = 0)
    {
        char query[512];
        
        Format(query, sizeof(query),
            "SELECT `id`, `category_id`, `name`, `description`, `type`, `price`, `attributes` FROM `%sitems_v2` WHERE `category_id` = %d AND `is_active` = TRUE ORDER BY `name` ASC;",
            databasePrefix, categoryId);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Get all active items.
     * 
     * @param callback  Callback function for results
     * @param data      Optional data to pass to callback
     */
    public static void GetAllItems(SQLQueryCallback callback, any data = 0)
    {
        char query[512];
        
        Format(query, sizeof(query),
            "SELECT `id`, `category_id`, `name`, `description`, `type`, `price`, `attributes` FROM `%sitems_v2` WHERE `is_active` = TRUE ORDER BY `category_id`, `name` ASC;",
            databasePrefix);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Execute a transaction.
     * 
     * @param txn        Transaction to execute
     * @param onSuccess  Success callback
     * @param onFailure  Failure callback
     * @param data       Optional data to pass to callbacks
     */
    public static void ExecuteTransaction(Transaction txn, SQLTxnSuccess onSuccess, SQLTxnFailure onFailure, any data = 0)
    {
        DB.Execute(txn, onSuccess, onFailure, data);
    }
    
    /**
     * Get a player timer record.
     * Returns: seconds_ago (INT), claim_count (INT), streak (INT)
     * 
     * @param steamId    Player's SteamID
     * @param timerType  Timer type (e.g. 'daily')
     * @param callback   Callback function for results
     * @param data       Optional data to pass to callback
     */
    public static void GetPlayerTimer(const char[] steamId, const char[] timerType, SQLQueryCallback callback, any data = 0)
    {
        char query[512];
        char escapedSteamId[64], escapedType[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        DB.Escape(timerType, escapedType, sizeof(escapedType));
        
        Format(query, sizeof(query),
            "SELECT TIMESTAMPDIFF(SECOND, `last_claimed`, NOW()) AS seconds_ago, `claim_count`, `streak` FROM `%splayer_timers` WHERE `steamid` = '%s' AND `timer_type` = '%s';",
            databasePrefix, escapedSteamId, escapedType);
        
        DB.Query(callback, query, data);
    }
    
    /**
     * Insert or update a player timer record.
     * 
     * @param steamId    Player's SteamID
     * @param timerType  Timer type (e.g. 'daily')
     * @param streak     Current streak value to store
     * @param callback   Optional callback function
     * @param data       Optional data to pass to callback
     */
    public static void UpsertPlayerTimer(const char[] steamId, const char[] timerType, int streak, SQLQueryCallback callback = INVALID_FUNCTION, any data = 0)
    {
        char query[512];
        char escapedSteamId[64], escapedType[64];
        DB.Escape(steamId, escapedSteamId, sizeof(escapedSteamId));
        DB.Escape(timerType, escapedType, sizeof(escapedType));
        
        Format(query, sizeof(query),
            "INSERT INTO `%splayer_timers` (`steamid`, `timer_type`, `last_claimed`, `claim_count`, `streak`) VALUES ('%s', '%s', NOW(), 1, %d) ON DUPLICATE KEY UPDATE `last_claimed` = NOW(), `claim_count` = `claim_count` + 1, `streak` = %d;",
            databasePrefix, escapedSteamId, escapedType, streak, streak);
        
        if (callback != INVALID_FUNCTION)
        {
            DB.Query(callback, query, data);
        }
        else
        {
            DB.Query(ErrorCheckCallback, query);
        }
    }
}
