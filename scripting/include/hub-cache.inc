/**
 * HubCore Cache Include
 * 
 * Provides cache-related functions for external plugins.
 * Include this file to access player cache data.
 */

#if defined _hub_cache_included
 #endinput
#endif
#define _hub_cache_included

/**
 * Check if player data is fully loaded in cache.
 * 
 * @param client  Client index
 * @return        True if player data is loaded, false otherwise
 */
native bool Hub_IsPlayerDataLoaded(int client);

/**
 * Get player credits from cache.
 * This is faster than querying the database directly.
 * 
 * @param client  Client index
 * @return        Player's credit balance
 */
native int Hub_GetPlayerCredits(int client);

/**
 * Set player credits in cache.
 * Changes are batched and written to database periodically.
 * 
 * @param client   Client index
 * @param credits  New credit amount
 * @return         True on success
 */
native bool Hub_SetPlayerCredits(int client, int credits);

/**
 * Add credits to player's cache.
 * 
 * @param client  Client index
 * @param amount  Amount to add
 * @return        New credit balance
 */
native int Hub_AddPlayerCredits(int client, int amount);

/**
 * Remove credits from player's cache.
 * 
 * @param client  Client index
 * @param amount  Amount to remove
 * @return        New credit balance
 */
native int Hub_RemovePlayerCredits(int client, int amount);

/**
 * Force flush player cache to database immediately.
 * Normally you don't need to call this - cache is flushed automatically.
 * 
 * @param client  Client index
 */
native void Hub_FlushPlayerCache(int client);

/**
 * Get player's SteamID from cache.
 * 
 * @param client  Client index
 * @param buffer  Buffer to store SteamID
 * @param maxlen  Maximum buffer length
 * @return        True if SteamID is available
 */
native bool Hub_GetPlayerSteamID(int client, char[] buffer, int maxlen);

/**
 * Get player's SteamID64 from cache.
 * 
 * @param client  Client index
 * @param buffer  Buffer to store SteamID64
 * @param maxlen  Maximum buffer length
 * @return        True if SteamID64 is available
 */
native bool Hub_GetPlayerSteamID64(int client, char[] buffer, int maxlen);

/**
 * Get player's total play time in seconds.
 * 
 * @param client  Client index
 * @return        Total play time in seconds
 */
native int Hub_GetPlayerPlayTime(int client);

/**
 * Get player's current session time in seconds.
 * 
 * @param client  Client index
 * @return        Session time in seconds
 */
native int Hub_GetPlayerSessionTime(int client);
