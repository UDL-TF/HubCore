/**
 * HubCore Selections Include
 * 
 * Provides functions for managing player cosmetic selections.
 * Selections are stored in the player's cosmetics JSON column.
 */

#if defined _hub_selections_included
 #endinput
#endif
#define _hub_selections_included

#include <json>

// Selection type constants (same as in hub-database.inc for convenience)
#if !defined SELECTION_TAG
    #define SELECTION_TAG              "tag"
    #define SELECTION_TRAIL            "trail"
    #define SELECTION_FOOTPRINT        "footprint"
    #define SELECTION_SPAWN_PARTICLE   "spawn_particle"
    #define SELECTION_TAG_COLOR        "tag_color"
    #define SELECTION_NAME_COLOR       "name_color"
    #define SELECTION_CHAT_COLOR       "chat_color"
#endif

/**
 * Get a player's selection as a JSON object.
 * 
 * @param client         Client index
 * @param selectionType  Selection type constant (SELECTION_*)
 * @return               JSON_Object with selection data, or null if no selection
 * @note                 The returned JSON object must be cleaned up by the caller using json_cleanup_and_delete()
 */
native JSON_Object Selections_GetPlayer(int client, const char[] selectionType);

/**
 * Set a player's selection from a JSON object.
 * 
 * @param client         Client index
 * @param selectionType  Selection type constant (SELECTION_*)
 * @param data           JSON_Object with selection data (ownership is transferred)
 * @return               True on success, false on failure
 */
native bool Selections_SetPlayer(int client, const char[] selectionType, JSON_Object data);

/**
 * Clear a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type constant (SELECTION_*)
 * @return               True on success, false on failure
 */
native bool Selections_ClearPlayer(int client, const char[] selectionType);

/**
 * Check if player has a selection of a specific type.
 * 
 * @param client         Client index
 * @param selectionType  Selection type constant (SELECTION_*)
 * @return               True if selection exists, false otherwise
 */
native bool Selections_HasPlayer(int client, const char[] selectionType);

/**
 * Get an integer value from a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type constant (SELECTION_*)
 * @param key            Key to get from the selection JSON
 * @param defaultValue   Default value if key doesn't exist
 * @return               Integer value or default
 */
native int Selections_GetPlayerInt(int client, const char[] selectionType, const char[] key, int defaultValue = 0);

/**
 * Get a string value from a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type constant (SELECTION_*)
 * @param key            Key to get from the selection JSON
 * @param buffer         Buffer to store the string
 * @param maxlen         Maximum buffer length
 * @param defaultValue   Default value if key doesn't exist
 * @return               True if key exists, false otherwise
 */
native bool Selections_GetPlayerString(int client, const char[] selectionType, const char[] key, 
                                        char[] buffer, int maxlen, const char[] defaultValue = "");

/**
 * Get a boolean value from a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type constant (SELECTION_*)
 * @param key            Key to get from the selection JSON
 * @param defaultValue   Default value if key doesn't exist
 * @return               Boolean value or default
 */
native bool Selections_GetPlayerBool(int client, const char[] selectionType, const char[] key, bool defaultValue = false);

/**
 * Get a float value from a player's selection.
 * 
 * @param client         Client index
 * @param selectionType  Selection type constant (SELECTION_*)
 * @param key            Key to get from the selection JSON
 * @param defaultValue   Default value if key doesn't exist
 * @return               Float value or default
 */
native float Selections_GetPlayerFloat(int client, const char[] selectionType, const char[] key, float defaultValue = 0.0);

/**
 * Called when a player's selection changes.
 * 
 * @param client         Client index
 * @param selectionType  Selection type that changed
 * @param oldValue       Previous selection value (may be empty)
 * @param newValue       New selection value (may be empty if cleared)
 */
forward void Selections_OnPlayerSelectionChanged(int client, const char[] selectionType, const char[] oldValue, const char[] newValue);

/**
 * Called when a player's selections are loaded from the database.
 * Use this to apply cosmetics on player join.
 * 
 * @param client         Client index
 */
forward void Selections_OnPlayerSelectionsLoaded(int client);


public SharedPlugin __pl_hub_selections = 
{
    name = "hub-selections",
    file = "hub.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_hub_selections_SetNTVOptional()
{
    MarkNativeAsOptional("Selections_GetPlayer");
    MarkNativeAsOptional("Selections_SetPlayer");
    MarkNativeAsOptional("Selections_ClearPlayer");
    MarkNativeAsOptional("Selections_HasPlayer");
    MarkNativeAsOptional("Selections_GetPlayerInt");
    MarkNativeAsOptional("Selections_GetPlayerString");
    MarkNativeAsOptional("Selections_GetPlayerBool");
    MarkNativeAsOptional("Selections_GetPlayerFloat");
}
#endif
