/**
 * HubCore Footprints Include
 * 
 * Provides functions for managing player footprint effects.
 */

#if defined _hub_footprints_included
 #endinput
#endif
#define _hub_footprints_included

#include <json>

#define FOOTPRINTS_NONE 0

/**
 * Footprint data structure.
 */
enum struct FootprintInfo
{
    char id[16];         // Internal ID (the TF2 attribute value)
    char name[64];       // Display name
    float value;         // Attribute value
}

/**
 * Get a player's current footprint.
 * 
 * @param client         Client index
 * @param buffer         Buffer to store the footprint name
 * @param maxlen         Maximum buffer length
 * @return               True if player has a footprint, false otherwise
 */
native bool Footprints_GetPlayerFootprint(int client, char[] buffer, int maxlen);

/**
 * Set a player's footprint.
 * 
 * @param client         Client index
 * @param footprintName  Footprint name (from config)
 * @return               True on success
 */
native bool Footprints_SetPlayerFootprint(int client, const char[] footprintName);

/**
 * Clear a player's footprint.
 * 
 * @param client         Client index
 * @return               True on success
 */
native bool Footprints_ClearPlayerFootprint(int client);

/**
 * Open the footprints menu for a player.
 * 
 * @param client         Client index
 */
native void Footprints_OpenMenu(int client);


public SharedPlugin __pl_hub_footprints = 
{
    name = "hub-footprints",
    file = "hub.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_hub_footprints_SetNTVOptional()
{
    MarkNativeAsOptional("Footprints_GetPlayerFootprint");
    MarkNativeAsOptional("Footprints_SetPlayerFootprint");
    MarkNativeAsOptional("Footprints_ClearPlayerFootprint");
    MarkNativeAsOptional("Footprints_OpenMenu");
}
#endif

