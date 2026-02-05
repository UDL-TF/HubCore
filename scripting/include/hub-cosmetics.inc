/**
 * HubCore Cosmetics Include
 * 
 * Provides shared types and functions for the cosmetics system.
 */

#if defined _hub_cosmetics_included
 #endinput
#endif
#define _hub_cosmetics_included

#include <json>
#include <hub-selections>

// Forward declare the native if hub.inc wasn't already included
#if !defined _hub_included
native int Hub_HasPlayerItemName(int client, const char[] category, const char[] name);
#endif

/**
 * Cosmetic types enumeration.
 */
enum CosmeticType
{
    Cosmetic_Tag = 0,
    Cosmetic_Trail,
    Cosmetic_Footprint,
    Cosmetic_SpawnParticle,
    Cosmetic_ChatColors,
    Cosmetic_MAX
}

/**
 * Cosmetic type string constants.
 */
stock char g_CosmeticTypeStrings[Cosmetic_MAX][] = {
    SELECTION_TAG,
    SELECTION_TRAIL,
    SELECTION_FOOTPRINT,
    SELECTION_SPAWN_PARTICLE,
    "" // Chat colors don't use selection system
};

/**
 * Cosmetic display names for menus.
 */
stock char g_CosmeticDisplayNames[Cosmetic_MAX][] = {
    "Tags",
    "Trails",
    "Footprints",
    "Spawn Particles",
    "Chat Colors"
};

/**
 * Get the selection type string for a cosmetic type.
 * 
 * @param type           Cosmetic type
 * @param buffer         Buffer to store the string
 * @param maxlen         Maximum buffer length
 */
stock void GetCosmeticSelectionType(CosmeticType type, char[] buffer, int maxlen)
{
    if (view_as<int>(type) >= view_as<int>(Cosmetic_Tag) && view_as<int>(type) < view_as<int>(Cosmetic_MAX))
    {
        strcopy(buffer, maxlen, g_CosmeticTypeStrings[view_as<int>(type)]);
    }
    else
    {
        buffer[0] = '\0';
    }
}

/**
 * Get the display name for a cosmetic type.
 * 
 * @param type           Cosmetic type
 * @param buffer         Buffer to store the string
 * @param maxlen         Maximum buffer length
 */
stock void GetCosmeticDisplayName(CosmeticType type, char[] buffer, int maxlen)
{
    if (view_as<int>(type) >= view_as<int>(Cosmetic_Tag) && view_as<int>(type) < view_as<int>(Cosmetic_MAX))
    {
        strcopy(buffer, maxlen, g_CosmeticDisplayNames[view_as<int>(type)]);
    }
    else
    {
        buffer[0] = '\0';
    }
}

/**
 * Check if a player has a specific cosmetic item.
 * 
 * @param client         Client index
 * @param type           Cosmetic type
 * @param itemName       Name of the item to check
 * @return               True if player owns the item
 */
stock bool HasCosmeticItem(int client, CosmeticType type, const char[] itemName)
{
    char category[64];
    GetCosmeticDisplayName(type, category, sizeof(category));
    return Hub_HasPlayerItemName(client, category, itemName) > 0;
}

/**
 * Typedef for cosmetic menu callbacks.
 */
typedef CosmeticMenuCallback = function void (int client, int choice, const char[] itemName);

/**
 * Cosmetic registration structure.
 */
enum struct CosmeticInfo
{
    CosmeticType type;
    char name[64];
    char command[32];
    bool registered;
}

// Forward declarations for cosmetic-specific functions
forward void Cosmetics_OnTagChanged(int client, const char[] oldTag, const char[] newTag);
forward void Cosmetics_OnTrailChanged(int client, int oldTrailId, int newTrailId);
forward void Cosmetics_OnFootprintChanged(int client, int oldFootprintId, int newFootprintId);
forward void Cosmetics_OnSpawnParticleChanged(int client, const char[] oldParticle, const char[] newParticle);

