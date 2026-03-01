/**
 * HubCore Native Chat System Include
 * 
 * Replaces third-party CCC (Custom Chat Colors) and SCP (Simple Chat Processor)
 * with a native, modern chat system integrated into HubCore.
 */

#if defined _hub_chat_included
    #endinput
#endif
#define _hub_chat_included

#include <hub>

// Maximum lengths
#define HUB_CHAT_MAX_NAME      128
#define HUB_CHAT_MAX_MESSAGE   256
#define HUB_CHAT_MAX_TAG       32

// Chat flags
#define HUB_CHATFLAG_INVALID   0
#define HUB_CHATFLAG_ALL       (1<<0)
#define HUB_CHATFLAG_TEAM      (1<<1)
#define HUB_CHATFLAG_SPEC      (1<<2)
#define HUB_CHATFLAG_DEAD      (1<<3)

// Color code constants
#define HUB_COLOR_DEFAULT   "\x01"
#define HUB_COLOR_TEAM      "\x03"
#define HUB_COLOR_GREEN     "\x04"
#define HUB_COLOR_OLIVE     "\x05"

// Special color values (matching CCC for compatibility)
#define COLOR_NONE          -1
#define COLOR_GREEN         -2
#define COLOR_OLIVE         -3
#define COLOR_TEAM          -4

/**
 * Color types for chat
 */
enum HubChatColorType
{
    HubChatColor_None = 0,     // No color / default
    HubChatColor_Team,         // \x03 - Team-based color
    HubChatColor_Green,        // \x04
    HubChatColor_Olive,        // \x05
    HubChatColor_Hex,          // \x07RRGGBB
    HubChatColor_HexAlpha      // \x08RRGGBBAA
};

/**
 * Called before a chat message is processed.
 * Modify name/message buffers to change what's displayed.
 *
 * @param author      Client index of message author (can be modified)
 * @param recipients  ArrayList of client indices who will receive the message
 * @param name        Display name buffer (can be modified, max HUB_CHAT_MAX_NAME)
 * @param message     Message buffer (can be modified, max HUB_CHAT_MAX_MESSAGE)
 * @param chatFlags   Chat flags (HUB_CHATFLAG_*)
 * @return            Plugin_Continue to allow, Plugin_Handled to block, Plugin_Changed if modified
 */
forward Action OnHubChatMessage(int &author, ArrayList recipients, char[] name, char[] message, int chatFlags);

/**
 * Called after chat message has been fully processed and sent.
 *
 * @param author      Client index of message author
 * @param recipients  ArrayList of client indices who received the message
 * @param name        Final display name
 * @param message     Final message content
 */
forward void OnHubChatMessagePost(int author, ArrayList recipients, const char[] name, const char[] message);

/**
 * Called when a client's chat colors are loaded from database
 *
 * @param client     Client index
 */
forward void OnClientChatColorsLoaded(int client);

/**
 * Called when a client's tag is changed
 *
 * @param client     Client index
 * @param oldTag     Previous tag
 * @param newTag     New tag
 */
forward void OnClientTagChanged(int client, const char[] oldTag, const char[] newTag);

/**
 * Gets the current chat message flags.
 * Should only be called within OnHubChatMessage or OnHubChatMessagePost.
 *
 * @return           Chat flags (HUB_CHATFLAG_*)
 */
native int HubChat_GetChatFlags();

/**
 * Gets a client's chat tag
 *
 * @param client     Client index
 * @param buffer     Buffer to store tag
 * @param maxlen     Maximum buffer length
 * @noreturn
 */
native void HubChat_GetClientTag(int client, char[] buffer, int maxlen);

/**
 * Sets a client's chat tag
 *
 * @param client     Client index
 * @param tag        Tag text (empty string to clear)
 * @noreturn
 */
native void HubChat_SetClientTag(int client, const char[] tag);

/**
 * Gets a client's tag color
 *
 * @param client     Client index
 * @param color      Variable to store color value (hex or special constant)
 * @return           Color type
 */
native HubChatColorType HubChat_GetClientTagColor(int client, int &color);

/**
 * Sets a client's tag color
 *
 * @param client     Client index
 * @param type       Color type
 * @param color      Color value (hex for Hex types, ignored for special types)
 * @noreturn
 */
native void HubChat_SetClientTagColor(int client, HubChatColorType type, int color = 0);

/**
 * Gets a client's name color
 *
 * @param client     Client index
 * @param color      Variable to store color value
 * @return           Color type
 */
native HubChatColorType HubChat_GetClientNameColor(int client, int &color);

/**
 * Sets a client's name color
 *
 * @param client     Client index
 * @param type       Color type
 * @param color      Color value
 * @noreturn
 */
native void HubChat_SetClientNameColor(int client, HubChatColorType type, int color = 0);

/**
 * Gets a client's chat text color
 *
 * @param client     Client index
 * @param color      Variable to store color value
 * @return           Color type
 */
native HubChatColorType HubChat_GetClientChatColor(int client, int &color);

/**
 * Sets a client's chat text color
 *
 * @param client     Client index
 * @param type       Color type
 * @param color      Color value
 * @noreturn
 */
native void HubChat_SetClientChatColor(int client, HubChatColorType type, int color = 0);

/**
 * Resets all of a client's chat colors to defaults
 *
 * @param client     Client index
 * @noreturn
 */
native void HubChat_ResetClientColors(int client);

/**
 * Checks if a client's tag is enabled (visible)
 *
 * @param client     Client index
 * @return           True if enabled, false otherwise
 */
native bool HubChat_IsClientTagEnabled(int client);

/**
 * Sets whether a client's tag is enabled (visible)
 *
 * @param client     Client index
 * @param enabled    True to enable, false to disable
 * @noreturn
 */
native void HubChat_SetClientTagEnabled(int client, bool enabled);

// ==================== Stock Functions ====================

/**
 * Converts hex color to color code string
 */
stock void HubChat_HexToColorCode(int hex, char[] buffer, int maxlen, bool hasAlpha = false)
{
    if (hasAlpha)
        Format(buffer, maxlen, "\x08%08X", hex);
    else
        Format(buffer, maxlen, "\x07%06X", hex);
}

/**
 * Converts color type and value to color code string
 */
stock void HubChat_ColorToCode(HubChatColorType type, int color, char[] buffer, int maxlen)
{
    switch (type)
    {
        case HubChatColor_None:
            strcopy(buffer, maxlen, HUB_COLOR_DEFAULT);
        case HubChatColor_Team:
            strcopy(buffer, maxlen, HUB_COLOR_TEAM);
        case HubChatColor_Green:
            strcopy(buffer, maxlen, HUB_COLOR_GREEN);
        case HubChatColor_Olive:
            strcopy(buffer, maxlen, HUB_COLOR_OLIVE);
        case HubChatColor_Hex:
            Format(buffer, maxlen, "\x07%06X", color);
        case HubChatColor_HexAlpha:
            Format(buffer, maxlen, "\x08%08X", color);
    }
}

/**
 * Parses color string (supports: "team", "green", "olive", "#RRGGBB", "RRGGBB", "#RRGGBBAA")
 */
stock HubChatColorType HubChat_ParseColorString(const char[] colorStr, int &colorValue)
{
    colorValue = 0;
    
    if (strlen(colorStr) == 0)
        return HubChatColor_None;
    
    if (StrEqual(colorStr, "team", false) || StrEqual(colorStr, "T", false))
        return HubChatColor_Team;
    if (StrEqual(colorStr, "green", false) || StrEqual(colorStr, "G", false))
        return HubChatColor_Green;
    if (StrEqual(colorStr, "olive", false) || StrEqual(colorStr, "O", false))
        return HubChatColor_Olive;
    if (StrEqual(colorStr, "none", false) || StrEqual(colorStr, "default", false))
        return HubChatColor_None;
    
    // Parse hex color
    char hex[16];
    int start = (colorStr[0] == '#') ? 1 : 0;
    int j = 0;
    for (int i = start; colorStr[i] != '\0' && j < sizeof(hex) - 1; i++)
    {
        hex[j++] = colorStr[i];
    }
    hex[j] = '\0';
    
    int len = strlen(hex);
    if (len == 6)
    {
        colorValue = StringToInt(hex, 16);
        return HubChatColor_Hex;
    }
    else if (len == 8)
    {
        colorValue = StringToInt(hex, 16);
        return HubChatColor_HexAlpha;
    }
    
    return HubChatColor_None;
}

/**
 * Converts color type and value back to string representation
 */
stock void HubChat_ColorTypeToString(HubChatColorType type, int color, char[] buffer, int maxlen)
{
    switch (type)
    {
        case HubChatColor_None:
            buffer[0] = '\0';
        case HubChatColor_Team:
            strcopy(buffer, maxlen, "team");
        case HubChatColor_Green:
            strcopy(buffer, maxlen, "green");
        case HubChatColor_Olive:
            strcopy(buffer, maxlen, "olive");
        case HubChatColor_Hex:
            Format(buffer, maxlen, "#%06X", color);
        case HubChatColor_HexAlpha:
            Format(buffer, maxlen, "#%08X", color);
    }
}

/**
 * Converts RGB values to hex integer
 */
stock int HubChat_RGBToHex(int r, int g, int b)
{
    return (r << 16) | (g << 8) | b;
}

/**
 * Converts RGBA values to hex integer
 */
stock int HubChat_RGBAToHex(int r, int g, int b, int a)
{
    return (r << 24) | (g << 16) | (b << 8) | a;
}

/**
 * Extracts RGB from hex
 */
stock void HubChat_HexToRGB(int hex, int &r, int &g, int &b)
{
    r = (hex >> 16) & 0xFF;
    g = (hex >> 8) & 0xFF;
    b = hex & 0xFF;
}

// ==================== Shared Plugin ====================

public SharedPlugin __pl_hub_chat = 
{
    name = "hub-chat",
    file = "hub.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_hub_chat_SetNTVOptional()
{
    MarkNativeAsOptional("HubChat_GetChatFlags");
    MarkNativeAsOptional("HubChat_GetClientTag");
    MarkNativeAsOptional("HubChat_SetClientTag");
    MarkNativeAsOptional("HubChat_GetClientTagColor");
    MarkNativeAsOptional("HubChat_SetClientTagColor");
    MarkNativeAsOptional("HubChat_GetClientNameColor");
    MarkNativeAsOptional("HubChat_SetClientNameColor");
    MarkNativeAsOptional("HubChat_GetClientChatColor");
    MarkNativeAsOptional("HubChat_SetClientChatColor");
    MarkNativeAsOptional("HubChat_ResetClientColors");
    MarkNativeAsOptional("HubChat_IsClientTagEnabled");
    MarkNativeAsOptional("HubChat_SetClientTagEnabled");
}
#endif
