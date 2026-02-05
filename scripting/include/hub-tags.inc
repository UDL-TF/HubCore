/**
 * HubCore Tags Include
 * 
 * Provides functions for managing player chat tags.
 */

#if defined _hub_tags_included
 #endinput
#endif
#define _hub_tags_included

#include <json>

#define TAGS_CONFIG_PATH "configs/hub/tags.cfg"
#define TAGS_MAX_COUNT 255
#define TAGS_NONE -1

/**
 * Tag data structure.
 */
enum struct TagInfo
{
    char name[64];
    char color[16];      // Hex color string (e.g., "FF0000")
    int colorInt;        // Parsed color as integer
    bool isEnabled;
}

/**
 * Get a player's current tag.
 * 
 * @param client         Client index
 * @param buffer         Buffer to store the tag
 * @param maxlen         Maximum buffer length
 * @return               True if player has a tag, false otherwise
 */
native bool Tags_GetPlayerTag(int client, char[] buffer, int maxlen);

/**
 * Get a player's current tag color.
 * 
 * @param client         Client index
 * @param buffer         Buffer to store the color (hex format)
 * @param maxlen         Maximum buffer length
 * @return               True if player has a tag color, false otherwise
 */
native bool Tags_GetPlayerTagColor(int client, char[] buffer, int maxlen);

/**
 * Set a player's tag.
 * 
 * @param client         Client index
 * @param tag            Tag text (empty string to clear)
 * @param color          Tag color in hex format (optional)
 * @return               True on success
 */
native bool Tags_SetPlayerTag(int client, const char[] tag, const char[] color = "");

/**
 * Clear a player's tag.
 * 
 * @param client         Client index
 * @return               True on success
 */
native bool Tags_ClearPlayerTag(int client);

/**
 * Open the tags menu for a player.
 * 
 * @param client         Client index
 */
native void Tags_OpenMenu(int client);


public SharedPlugin __pl_hub_tags = 
{
    name = "hub-tags",
    file = "hub.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_hub_tags_SetNTVOptional()
{
    MarkNativeAsOptional("Tags_GetPlayerTag");
    MarkNativeAsOptional("Tags_GetPlayerTagColor");
    MarkNativeAsOptional("Tags_SetPlayerTag");
    MarkNativeAsOptional("Tags_ClearPlayerTag");
    MarkNativeAsOptional("Tags_OpenMenu");
}
#endif

