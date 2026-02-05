/**
 * HubCore Trails Include
 * 
 * Provides functions for managing player trail effects.
 */

#if defined _hub_trails_included
 #endinput
#endif
#define _hub_trails_included

#include <json>

#define TRAILS_CONFIG_PATH "configs/hub/trails.cfg"
#define TRAILS_MAX_COUNT 255
#define TRAILS_NONE -1

#define TRAILS_BEAM_SPRITE_VMT "materials/trails/beam_01.vmt"
#define TRAILS_BEAM_SPRITE_VTF "materials/trails/beam_01.vtf"
#define TRAILS_GROUND_OFFSET 5.0

/**
 * Trail color type enumeration.
 */
enum TrailColorType
{
    TrailColorType_SolidColor = 0,
    TrailColorType_SpectrumCycle,
    TrailColorType_VelocityBased,
    TrailColorType_MAX
}

/**
 * Spectrum cycle mode enumeration.
 */
enum TrailSpectrumCycleMode
{
    TrailSpectrumCycleMode_Off = 0,
    TrailSpectrumCycleMode_RedToYellow,
    TrailSpectrumCycleMode_YellowToGreen,
    TrailSpectrumCycleMode_GreenToCyan,
    TrailSpectrumCycleMode_CyanToBlue,
    TrailSpectrumCycleMode_BlueToMagenta,
    TrailSpectrumCycleMode_MagentaToRed
}

/**
 * Breathing mode enumeration.
 */
enum TrailBreathingMode
{
    TrailBreathingMode_Off = 0,
    TrailBreathingMode_Inhale,
    TrailBreathingMode_Exhale
}

/**
 * Bow mode enumeration.
 */
enum TrailBowMode
{
    TrailBowMode_Off = 0,
    TrailBowMode_Expand,
    TrailBowMode_Shrink
}

/**
 * Trail color structure.
 */
enum struct TrailColor
{
    int r;
    int g;
    int b;
    int a;
}

/**
 * Trail data structure.
 */
enum struct TrailInfo
{
    char name[255];
    TrailColorType colorType;
    
    TrailColor color;
    
    float width;
    float duration;
    
    bool isCheap;
    bool isAdminsOnly;
    
    int spectrumCycleSpeed;
    int breathingSpeed;
    float bowTransformSpeed;
    
    int breathingMinAlpha;
    int breathingMaxAlpha;
    
    float bowMinWidth;
    float bowMaxWidth;
}

/**
 * Get a player's current trail.
 * 
 * @param client         Client index
 * @param buffer         Buffer to store the trail name
 * @param maxlen         Maximum buffer length
 * @return               True if player has a trail, false otherwise
 */
native bool Trails_GetPlayerTrail(int client, char[] buffer, int maxlen);

/**
 * Set a player's trail by name.
 * 
 * @param client         Client index
 * @param trailName      Trail name (from config)
 * @return               True on success
 */
native bool Trails_SetPlayerTrail(int client, const char[] trailName);

/**
 * Clear a player's trail.
 * 
 * @param client         Client index
 * @return               True on success
 */
native bool Trails_ClearPlayerTrail(int client);

/**
 * Toggle trail visibility for a player.
 * 
 * @param client         Client index
 * @return               New visibility state (true = visible)
 */
native bool Trails_ToggleHideTrails(int client);

/**
 * Check if a player is hiding trails.
 * 
 * @param client         Client index
 * @return               True if hiding trails
 */
native bool Trails_IsHidingTrails(int client);

/**
 * Open the trails menu for a player.
 * 
 * @param client         Client index
 */
native void Trails_OpenMenu(int client);


public SharedPlugin __pl_hub_trails = 
{
    name = "hub-trails",
    file = "hub.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_hub_trails_SetNTVOptional()
{
    MarkNativeAsOptional("Trails_GetPlayerTrail");
    MarkNativeAsOptional("Trails_SetPlayerTrail");
    MarkNativeAsOptional("Trails_ClearPlayerTrail");
    MarkNativeAsOptional("Trails_ToggleHideTrails");
    MarkNativeAsOptional("Trails_IsHidingTrails");
    MarkNativeAsOptional("Trails_OpenMenu");
}
#endif

