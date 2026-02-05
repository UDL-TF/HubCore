/**
 * HubCore Chat Formatting Utilities
 * 
 * Utility functions for message formatting, color manipulation,
 * and common chat operations.
 */

/**
 * Gets team color hex for a client.
 * 
 * @param client  Client index
 * @return        Hex color for the client's team
 */
int Chat_GetTeamColorHex(int client)
{
    if (!IsValidPlayer(client))
    {
        return 0xCCCCCC; // Gray default
    }
    
    switch (GetClientTeam(client))
    {
        case 2: return 0xFF4040; // RED
        case 3: return 0x99CCFF; // BLU
        default: return 0xCCCCCC; // SPEC/Unassigned
    }
}

/**
 * Validates hex color string.
 * 
 * @param color   Color string to validate
 * @return        True if valid hex color
 */
bool Chat_IsValidHexColor(const char[] color)
{
    int start = 0;
    if (color[0] == '#')
    {
        start = 1;
    }
    
    int len = strlen(color) - start;
    if (len != 6 && len != 8)
    {
        return false;
    }
    
    for (int i = start; color[i] != '\0'; i++)
    {
        char c = color[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')))
        {
            return false;
        }
    }
    
    return true;
}

/**
 * Sends a colored message to a single client.
 * 
 * @param client   Recipient client index
 * @param author   Message author client index (for team color)
 * @param format   Message format string
 * @param ...      Format arguments
 */
void Chat_PrintToClient(int client, int author, const char[] format, any ...)
{
    if (!IsValidPlayer(client) || IsFakeClient(client))
    {
        return;
    }
    
    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 4);
    
    Handle bf = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
    if (bf != null)
    {
        BfWriteByte(bf, author > 0 ? author : client);
        BfWriteByte(bf, true);
        BfWriteString(bf, buffer);
        EndMessage();
    }
}

/**
 * Broadcasts a colored message to all clients.
 * 
 * @param author   Message author client index (for team color)
 * @param format   Message format string
 * @param ...      Format arguments
 */
void Chat_PrintToAll(int author, const char[] format, any ...)
{
    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 3);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            Chat_PrintToClient(i, author, "%s", buffer);
        }
    }
}

/**
 * Broadcasts a colored message to a team.
 * 
 * @param team     Team index (2 = RED, 3 = BLU)
 * @param author   Message author client index
 * @param format   Message format string
 * @param ...      Format arguments
 */
void Chat_PrintToTeam(int team, int author, const char[] format, any ...)
{
    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 4);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
        {
            Chat_PrintToClient(i, author, "%s", buffer);
        }
    }
}

/**
 * Removes duplicate spaces from text.
 * 
 * @param input    Input string
 * @param output   Output buffer
 * @param maxlen   Maximum output length
 */
void Chat_RemoveDuplicateSpaces(const char[] input, char[] output, int maxlen)
{
    int j = 0;
    bool lastWasSpace = false;
    
    for (int i = 0; input[i] != '\0' && j < maxlen - 1; i++)
    {
        if (input[i] == ' ')
        {
            if (!lastWasSpace)
            {
                output[j++] = input[i];
                lastWasSpace = true;
            }
        }
        else
        {
            output[j++] = input[i];
            lastWasSpace = false;
        }
    }
    output[j] = '\0';
}

/**
 * Trims whitespace from both ends of a string.
 * 
 * @param str      String to trim (modified in place)
 */
void Chat_TrimString(char[] str)
{
    int len = strlen(str);
    if (len == 0)
    {
        return;
    }
    
    // Trim leading
    int start = 0;
    while (str[start] == ' ' || str[start] == '\t' || str[start] == '\n' || str[start] == '\r')
    {
        start++;
    }
    
    // Trim trailing
    int end = len - 1;
    while (end > start && (str[end] == ' ' || str[end] == '\t' || str[end] == '\n' || str[end] == '\r'))
    {
        end--;
    }
    
    // Copy trimmed string
    if (start > 0 || end < len - 1)
    {
        int newLen = end - start + 1;
        for (int i = 0; i < newLen; i++)
        {
            str[i] = str[start + i];
        }
        str[newLen] = '\0';
    }
}

/**
 * Checks if a string contains any color codes.
 * 
 * @param str      String to check
 * @return         True if string contains color codes
 */
bool Chat_HasColorCodes(const char[] str)
{
    for (int i = 0; str[i] != '\0'; i++)
    {
        if (str[i] >= 0x01 && str[i] <= 0x09)
        {
            return true;
        }
    }
    return false;
}

/**
 * Creates a gradient colored string.
 * 
 * @param input       Input text
 * @param output      Output buffer
 * @param maxlen      Maximum output length
 * @param startColor  Starting hex color
 * @param endColor    Ending hex color
 */
void Chat_ApplyGradient(const char[] input, char[] output, int maxlen, int startColor, int endColor)
{
    int len = strlen(input);
    if (len == 0)
    {
        output[0] = '\0';
        return;
    }
    
    int sr, sg, sb, er, eg, eb;
    HubChat_HexToRGB(startColor, sr, sg, sb);
    HubChat_HexToRGB(endColor, er, eg, eb);
    
    char buffer[1024];
    int pos = 0;
    
    for (int i = 0; i < len && pos < maxlen - 10; i++)
    {
        // Skip color codes in input
        if (input[i] >= 0x01 && input[i] <= 0x09)
        {
            continue;
        }
        
        // Calculate interpolated color
        float t = (len > 1) ? float(i) / float(len - 1) : 0.0;
        int r = RoundToFloor(float(sr) + float(er - sr) * t);
        int g = RoundToFloor(float(sg) + float(eg - sg) * t);
        int b = RoundToFloor(float(sb) + float(eb - sb) * t);
        
        int color = HubChat_RGBToHex(r, g, b);
        pos += Format(buffer[pos], sizeof(buffer) - pos, "\x07%06X%c", color, input[i]);
    }
    
    strcopy(output, maxlen, buffer);
}

/**
 * Creates a rainbow colored string.
 * 
 * @param input    Input text
 * @param output   Output buffer
 * @param maxlen   Maximum output length
 */
void Chat_ApplyRainbow(const char[] input, char[] output, int maxlen)
{
    // Rainbow colors
    int colors[] = {
        0xFF0000, // Red
        0xFF7F00, // Orange
        0xFFFF00, // Yellow
        0x00FF00, // Green
        0x0000FF, // Blue
        0x4B0082, // Indigo
        0x9400D3  // Violet
    };
    int numColors = sizeof(colors);
    
    int len = strlen(input);
    if (len == 0)
    {
        output[0] = '\0';
        return;
    }
    
    char buffer[1024];
    int pos = 0;
    int colorIdx = 0;
    
    for (int i = 0; i < len && pos < maxlen - 10; i++)
    {
        // Skip color codes in input
        if (input[i] >= 0x01 && input[i] <= 0x09)
        {
            continue;
        }
        
        // Skip spaces for color cycling
        if (input[i] == ' ')
        {
            buffer[pos++] = ' ';
            continue;
        }
        
        int color = colors[colorIdx % numColors];
        pos += Format(buffer[pos], sizeof(buffer) - pos, "\x07%06X%c", color, input[i]);
        colorIdx++;
    }
    
    strcopy(output, maxlen, buffer);
}

/**
 * Escapes special characters in chat messages.
 * 
 * @param input    Input string
 * @param output   Output buffer
 * @param maxlen   Maximum output length
 */
void Chat_EscapeString(const char[] input, char[] output, int maxlen)
{
    int j = 0;
    for (int i = 0; input[i] != '\0' && j < maxlen - 2; i++)
    {
        // Escape percent signs for format strings
        if (input[i] == '%')
        {
            output[j++] = '%';
            output[j++] = '%';
        }
        // Escape backslashes
        else if (input[i] == '\\')
        {
            output[j++] = '\\';
            output[j++] = '\\';
        }
        else
        {
            output[j++] = input[i];
        }
    }
    output[j] = '\0';
}

/**
 * Formats a chat message with proper colors applied.
 * 
 * @param author     Message author
 * @param name       Player name
 * @param message    Message content
 * @param output     Output buffer
 * @param maxlen     Maximum output length
 */
void Chat_FormatFullMessage(int author, const char[] name, const char[] message, char[] output, int maxlen)
{
    char coloredName[HUB_CHAT_MAX_NAME];
    char coloredMessage[HUB_CHAT_MAX_MESSAGE];
    
    strcopy(coloredName, sizeof(coloredName), name);
    strcopy(coloredMessage, sizeof(coloredMessage), message);
    
    // Apply chat colors
    Chat_Colors_ApplyToMessage(author, coloredName, sizeof(coloredName), coloredMessage, sizeof(coloredMessage));
    
    Format(output, maxlen, "\x01%s\x01 :  %s", coloredName, coloredMessage);
}
