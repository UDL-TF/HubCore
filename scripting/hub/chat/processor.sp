/**
 * HubCore Chat Processor
 * 
 * Core chat message processing system - replaces Simple Chat Processor (SCP).
 * Hooks into TF2's SayText2 user message and provides forwards for other code
 * to manipulate chat messages.
 */

// Forwards
static GlobalForward g_FwdOnChatMessage;
static GlobalForward g_FwdOnChatMessagePost;

// Current chat state
static int g_CurrentChatFlags;
static StringMap g_ChatFormats;

// Whether the processor is initialized
static bool g_ProcessorInitialized = false;

// Data structure for deferred message sending
enum struct DeferredChatMessage
{
    int author;
    bool bChat;
    char name[HUB_CHAT_MAX_NAME];
    char message[512];
    int recipients[MAXPLAYERS + 1];
    int recipientCount;
}

/**
 * Initialize the chat processor.
 */
void Chat_Processor_Init()
{
    if (g_ProcessorInitialized)
    {
        return;
    }
    
    // Create forwards
    g_FwdOnChatMessage = new GlobalForward("OnHubChatMessage", 
        ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String, Param_Cell);
    g_FwdOnChatMessagePost = new GlobalForward("OnHubChatMessagePost",
        ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
    
    // Hook SayText2
    UserMsg msgSayText2 = GetUserMessageId("SayText2");
    if (msgSayText2 != INVALID_MESSAGE_ID)
    {
        HookUserMessage(msgSayText2, OnSayText2, true);
        LogMessage("[Hub Chat] Successfully hooked SayText2 user message");
    }
    else
    {
        LogError("[Hub Chat] Failed to hook SayText2 - chat processing disabled");
    }
    
    // Load chat format strings
    Chat_Processor_LoadFormats();
    
    g_ProcessorInitialized = true;
    LogMessage("[Hub Chat] Chat processor initialized");
}

/**
 * Load known TF2 chat format strings.
 */
void Chat_Processor_LoadFormats()
{
    g_ChatFormats = new StringMap();
    
    // TF2 chat format strings
    g_ChatFormats.SetValue("TF_Chat_All", 1);
    g_ChatFormats.SetValue("TF_Chat_AllDead", 1);
    g_ChatFormats.SetValue("TF_Chat_AllSpec", 1);
    g_ChatFormats.SetValue("TF_Chat_Team", 1);
    g_ChatFormats.SetValue("TF_Chat_Team_Dead", 1);
    g_ChatFormats.SetValue("TF_Chat_Spec", 1);
    g_ChatFormats.SetValue("TF_Chat_Team_Loc", 1);
    g_ChatFormats.SetValue("TF_Chat_Team_Loc_Dead", 1);
    g_ChatFormats.SetValue("TF_Chat_All_Loc", 1);
    g_ChatFormats.SetValue("TF_Chat_All_Loc_Dead", 1);
}

/**
 * SayText2 user message hook.
 */
public Action OnSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
    // Read author
    int author = msg.ReadByte();
    if (author <= 0 || author > MaxClients || !IsClientInGame(author))
    {
        return Plugin_Continue;
    }
    
    // Read chat flag
    bool bChat = view_as<bool>(msg.ReadByte());
    
    // Read translation name (format string)
    char translationName[64];
    msg.ReadString(translationName, sizeof(translationName));
    Chat_StripColors(translationName, translationName, sizeof(translationName));
    
    // Check if this is a format we handle
    int buffer;
    if (!g_ChatFormats.GetValue(translationName, buffer))
    {
        return Plugin_Continue;
    }
    
    // Parse chat flags from translation name
    g_CurrentChatFlags = Chat_ParseFlags(translationName);
    
    // Read sender name
    char senderName[HUB_CHAT_MAX_NAME];
    if (msg.BytesLeft > 0)
    {
        msg.ReadString(senderName, sizeof(senderName));
        Chat_StripColors(senderName, senderName, sizeof(senderName));
    }
    else
    {
        g_CurrentChatFlags = HUB_CHATFLAG_INVALID;
        return Plugin_Continue;
    }
    
    // Read message
    char message[HUB_CHAT_MAX_MESSAGE];
    if (msg.BytesLeft > 0)
    {
        msg.ReadString(message, sizeof(message));
        Chat_StripColors(message, message, sizeof(message));
    }
    else
    {
        g_CurrentChatFlags = HUB_CHATFLAG_INVALID;
        return Plugin_Continue;
    }
    
    // Build recipients list
    ArrayList recipients = new ArrayList();
    for (int i = 0; i < playersNum; i++)
    {
        if (players[i] > 0 && players[i] <= MaxClients && IsClientInGame(players[i]))
        {
            recipients.Push(players[i]);
        }
    }
    
    // Apply chat colors before firing forward
    Chat_Colors_ApplyToMessage(author, senderName, sizeof(senderName), message, sizeof(message));
    
    // Fire pre-forward
    Action result = Plugin_Continue;
    Call_StartForward(g_FwdOnChatMessage);
    Call_PushCellRef(author);
    Call_PushCell(recipients);
    Call_PushStringEx(senderName, sizeof(senderName), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushStringEx(message, sizeof(message), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(g_CurrentChatFlags);
    Call_Finish(result);
    
    if (result == Plugin_Handled || result == Plugin_Stop)
    {
        delete recipients;
        g_CurrentChatFlags = HUB_CHATFLAG_INVALID;
        return Plugin_Handled;
    }
    
    // Defer message sending to next frame to avoid "Unable to execute a new message while in hook"
    DataPack pack = new DataPack();
    pack.WriteCell(author);
    pack.WriteCell(bChat);
    pack.WriteString(senderName);
    pack.WriteString(message);
    pack.WriteCell(recipients.Length);
    for (int i = 0; i < recipients.Length; i++)
    {
        pack.WriteCell(recipients.Get(i));
    }
    RequestFrame(Frame_SendChatMessage, pack);
    
    // Fire post-forward
    Call_StartForward(g_FwdOnChatMessagePost);
    Call_PushCell(author);
    Call_PushCell(recipients);
    Call_PushString(senderName);
    Call_PushString(message);
    Call_Finish();
    
    delete recipients;
    g_CurrentChatFlags = HUB_CHATFLAG_INVALID;
    
    return Plugin_Handled;
}

/**
 * Frame callback for sending deferred chat messages.
 */
void Frame_SendChatMessage(DataPack pack)
{
    pack.Reset();
    
    int author = pack.ReadCell();
    bool bChat = pack.ReadCell();
    
    char name[HUB_CHAT_MAX_NAME];
    char message[512];
    pack.ReadString(name, sizeof(name));
    pack.ReadString(message, sizeof(message));
    
    int recipientCount = pack.ReadCell();
    ArrayList recipients = new ArrayList();
    for (int i = 0; i < recipientCount; i++)
    {
        recipients.Push(pack.ReadCell());
    }
    
    delete pack;
    
    // Send the message now that we're outside the hook
    Chat_SendMessage(author, recipients, name, message, bChat);
    
    delete recipients;
}

/**
 * Parse chat flags from translation name.
 */
int Chat_ParseFlags(const char[] translationName)
{
    int flags = HUB_CHATFLAG_INVALID;
    
    if (StrContains(translationName, "All", false) != -1)
        flags |= HUB_CHATFLAG_ALL;
    if (StrContains(translationName, "Team", false) != -1)
        flags |= HUB_CHATFLAG_TEAM;
    if (StrContains(translationName, "Spec", false) != -1)
        flags |= HUB_CHATFLAG_SPEC;
    if (StrContains(translationName, "Dead", false) != -1)
        flags |= HUB_CHATFLAG_DEAD;
    
    return flags;
}

/**
 * Send a chat message to recipients.
 */
void Chat_SendMessage(int author, ArrayList recipients, const char[] name, const char[] message, bool bChat)
{
    // Format the complete message
    char formattedMsg[512];
    
    // Build final message format: \x01<name>\x01 :  <message>
    Format(formattedMsg, sizeof(formattedMsg), "\x01%s\x01 :  %s", name, message);
    
    // Send to each recipient
    for (int i = 0; i < recipients.Length; i++)
    {
        int client = recipients.Get(i);
        if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
        {
            continue;
        }
        
        Handle bf = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
        if (bf != null)
        {
            BfWriteByte(bf, author);
            BfWriteByte(bf, bChat);
            BfWriteString(bf, formattedMsg);
            EndMessage();
        }
    }
}

/**
 * Strip all color codes from text.
 */
void Chat_StripColors(const char[] input, char[] output, int maxlen)
{
    int j = 0;
    for (int i = 0; input[i] != '\0' && j < maxlen - 1; i++)
    {
        // Skip color codes: \x01-\x09
        if (input[i] >= 0x01 && input[i] <= 0x09)
        {
            // \x07 is followed by 6 hex chars
            if (input[i] == 0x07)
            {
                // Skip up to 6 hex characters
                int skip = 0;
                while (skip < 6 && input[i + 1 + skip] != '\0')
                {
                    char c = input[i + 1 + skip];
                    if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')))
                    {
                        break;
                    }
                    skip++;
                }
                i += skip;
                continue;
            }
            // \x08 is followed by 8 hex chars
            if (input[i] == 0x08)
            {
                int skip = 0;
                while (skip < 8 && input[i + 1 + skip] != '\0')
                {
                    char c = input[i + 1 + skip];
                    if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')))
                    {
                        break;
                    }
                    skip++;
                }
                i += skip;
                continue;
            }
            continue;
        }
        output[j++] = input[i];
    }
    output[j] = '\0';
}

/**
 * Get current chat flags.
 */
int Chat_Processor_GetCurrentFlags()
{
    return g_CurrentChatFlags;
}

// ==================== Native Implementation ====================

int Native_HubChat_GetChatFlags(Handle plugin, int numParams)
{
    return g_CurrentChatFlags;
}
