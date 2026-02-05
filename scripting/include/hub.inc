/**
 * HubCore Main Include
 * 
 * Provides core natives for the Hub plugin system.
 */

#if defined _hub_included
 #endinput
#endif
#define _hub_included

/**
 * Gets player credits
 * 
 * @param client The client index
 * @return The player credits
 */
native int GetPlayerCredits(int client);

/**
 * Sets player credits
 * 
 * @param client The client index
 * @param credits The new player credits
 * @return 1 on success, 0 on failure
 */
native int SetPlayerCredits(int client, int credits);

/**
 * Adds credits to a player
 *  
 * @param client The client index
 * @param credits The credits to add
 * @return 1 on success, 0 on failure
 */
native int AddPlayerCredits(int client, int credits);

/**
 * Removes credits from a player
 *  
 * @param client The client index
 * @param credits The credits to remove
 * @return 1 on success, 0 on failure
 */
native int RemovePlayerCredits(int client, int credits);

/**
 * Checks if the client has the item
 * 
 * @param client The client index
 * @param category The item category
 * @param name The item name
 * @return 1 if the client has the item, 0 if not
 */
native int Hub_HasPlayerItemName(int client, const char[] category, const char[] name);