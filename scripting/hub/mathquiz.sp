/**
 * HubCore Math Quiz
 *
 * Periodically broadcasts a random math question to all players.
 * The first player to answer correctly in chat wins the credit bounty.
 *
 * Difficulty tiers & default bounties:
 *   Easy   — simple +/-              — 10-25 credits
 *   Medium — multiplication / a+b*c  — 30-60 credits
 *   Hard   — multi-step / (a+b)*c    — 70-120 credits
 */

enum MathQuizDifficulty
{
	Difficulty_Easy,
	Difficulty_Medium,
	Difficulty_Hard
}

// ConVars
static ConVar g_MathQuiz_Enabled;
static ConVar g_MathQuiz_IntervalMin;
static ConVar g_MathQuiz_IntervalMax;
static ConVar g_MathQuiz_AnswerTime;
static ConVar g_MathQuiz_EasyBountyMin;
static ConVar g_MathQuiz_EasyBountyMax;
static ConVar g_MathQuiz_MediumBountyMin;
static ConVar g_MathQuiz_MediumBountyMax;
static ConVar g_MathQuiz_HardBountyMin;
static ConVar g_MathQuiz_HardBountyMax;

// State
static bool   g_QuizActive      = false;
static int    g_QuizAnswer      = 0;
static int    g_QuizBounty      = 0;
static Handle g_QuizExpireTimer = INVALID_HANDLE;
static Handle g_QuizNextTimer   = INVALID_HANDLE;

/* ------------------------------------------------------------------ */
/*  Lifecycle                                                          */
/* ------------------------------------------------------------------ */

void MathQuiz_Init()
{
	g_MathQuiz_Enabled = CreateConVar(
		"hub_mathquiz_enabled", "1",
		"Enable the math quiz feature. (0 = disabled, 1 = enabled)",
		_, true, 0.0, true, 1.0);

	g_MathQuiz_IntervalMin = CreateConVar(
		"hub_mathquiz_interval_min", "2",
		"Minimum minutes to wait before the next math quiz.");

	g_MathQuiz_IntervalMax = CreateConVar(
		"hub_mathquiz_interval_max", "5",
		"Maximum minutes to wait before the next math quiz.");

	g_MathQuiz_AnswerTime = CreateConVar(
		"hub_mathquiz_answer_time", "15",
		"Seconds players have to answer the math quiz.");

	g_MathQuiz_EasyBountyMin = CreateConVar(
		"hub_mathquiz_easy_bounty_min", "10",
		"Minimum credit bounty for easy math questions.");

	g_MathQuiz_EasyBountyMax = CreateConVar(
		"hub_mathquiz_easy_bounty_max", "25",
		"Maximum credit bounty for easy math questions.");

	g_MathQuiz_MediumBountyMin = CreateConVar(
		"hub_mathquiz_medium_bounty_min", "30",
		"Minimum credit bounty for medium math questions.");

	g_MathQuiz_MediumBountyMax = CreateConVar(
		"hub_mathquiz_medium_bounty_max", "60",
		"Maximum credit bounty for medium math questions.");

	g_MathQuiz_HardBountyMin = CreateConVar(
		"hub_mathquiz_hard_bounty_min", "70",
		"Minimum credit bounty for hard math questions.");

	g_MathQuiz_HardBountyMax = CreateConVar(
		"hub_mathquiz_hard_bounty_max", "120",
		"Maximum credit bounty for hard math questions.");

	AddCommandListener(MathQuiz_OnSay, "say");
	AddCommandListener(MathQuiz_OnSay, "say_team");

	MathQuiz_ScheduleNext();
}

/* ------------------------------------------------------------------ */
/*  Scheduling                                                         */
/* ------------------------------------------------------------------ */

static void MathQuiz_ScheduleNext()
{
	if (g_QuizNextTimer != INVALID_HANDLE)
	{
		KillTimer(g_QuizNextTimer);
		g_QuizNextTimer = INVALID_HANDLE;
	}

	float intervalMin = g_MathQuiz_IntervalMin.FloatValue * 60.0;
	float intervalMax = g_MathQuiz_IntervalMax.FloatValue * 60.0;

	if (intervalMin > intervalMax)
		intervalMin = intervalMax;

	float delay      = GetRandomFloat(intervalMin, intervalMax);
	g_QuizNextTimer  = CreateTimer(delay, MathQuiz_Timer_Start);
}

public Action MathQuiz_Timer_Start(Handle timer)
{
	g_QuizNextTimer = INVALID_HANDLE;

	if (!g_MathQuiz_Enabled.BoolValue)
	{
		MathQuiz_ScheduleNext();
		return Plugin_Stop;
	}

	// Don't run if no real players are in-game
	int playerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i))
			playerCount++;
	}

	if (playerCount == 0)
	{
		MathQuiz_ScheduleNext();
		return Plugin_Stop;
	}

	MathQuiz_StartQuiz();
	return Plugin_Stop;
}

/* ------------------------------------------------------------------ */
/*  Quiz logic                                                         */
/* ------------------------------------------------------------------ */

static void MathQuiz_StartQuiz()
{
	MathQuizDifficulty difficulty = view_as<MathQuizDifficulty>(GetRandomInt(0, 2));

	char question[64];
	int  answer;
	int  bounty;

	switch (difficulty)
	{
		case Difficulty_Easy:
		{
			MathQuiz_GenerateEasy(question, sizeof(question), answer);
			bounty = GetRandomInt(
				g_MathQuiz_EasyBountyMin.IntValue,
				g_MathQuiz_EasyBountyMax.IntValue);
		}
		case Difficulty_Medium:
		{
			MathQuiz_GenerateMedium(question, sizeof(question), answer);
			bounty = GetRandomInt(
				g_MathQuiz_MediumBountyMin.IntValue,
				g_MathQuiz_MediumBountyMax.IntValue);
		}
		case Difficulty_Hard:
		{
			MathQuiz_GenerateHard(question, sizeof(question), answer);
			bounty = GetRandomInt(
				g_MathQuiz_HardBountyMin.IntValue,
				g_MathQuiz_HardBountyMax.IntValue);
		}
	}

	g_QuizActive = true;
	g_QuizAnswer = answer;
	g_QuizBounty = bounty;

	int answerTime = g_MathQuiz_AnswerTime.IntValue;
	CPrintToChatAll("%t", HUB_PHRASE_MATHQUIZ_QUESTION, question, bounty, answerTime);

	if (g_QuizExpireTimer != INVALID_HANDLE)
	{
		KillTimer(g_QuizExpireTimer);
		g_QuizExpireTimer = INVALID_HANDLE;
	}

	g_QuizExpireTimer = CreateTimer(float(answerTime), MathQuiz_Timer_Expire);
}

public Action MathQuiz_Timer_Expire(Handle timer)
{
	g_QuizExpireTimer = INVALID_HANDLE;

	if (!g_QuizActive)
		return Plugin_Stop;

	g_QuizActive = false;
	CPrintToChatAll("%t", HUB_PHRASE_MATHQUIZ_NO_WINNER, g_QuizAnswer);
	MathQuiz_ScheduleNext();

	return Plugin_Stop;
}

/* ------------------------------------------------------------------ */
/*  Chat listener                                                      */
/* ------------------------------------------------------------------ */

public Action MathQuiz_OnSay(int client, const char[] command, int argc)
{
	if (!g_QuizActive)
		return Plugin_Continue;

	if (!IsValidPlayer(client))
		return Plugin_Continue;

	char arg[64];
	GetCmdArgString(arg, sizeof(arg));
	StripQuotes(arg);
	TrimString(arg);

	// Only process pure integer strings
	if (!MathQuiz_IsInteger(arg))
		return Plugin_Continue;

	int answer = StringToInt(arg);
	if (answer != g_QuizAnswer)
		return Plugin_Continue;

	// Correct answer — award the bounty
	g_QuizActive = false;

	if (g_QuizExpireTimer != INVALID_HANDLE)
	{
		KillTimer(g_QuizExpireTimer);
		g_QuizExpireTimer = INVALID_HANDLE;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	Core_AddPlayerCredits(client, g_QuizBounty);
	CPrintToChatAll("%t", HUB_PHRASE_MATHQUIZ_WINNER, name, g_QuizBounty);

	MathQuiz_ScheduleNext();

	return Plugin_Continue;
}

/* ------------------------------------------------------------------ */
/*  Question generators                                                */
/* ------------------------------------------------------------------ */

/**
 * Easy: simple addition or subtraction with small numbers.
 *   a + b  where a,b ∈ [5, 30]
 *   a - b  where a ∈ [15, 50], b ∈ [1, a-1]   (result always positive)
 */
static void MathQuiz_GenerateEasy(char[] question, int maxlen, int& answer)
{
	int a, b;

	if (GetRandomInt(0, 1) == 0)
	{
		a = GetRandomInt(5, 30);
		b = GetRandomInt(5, 30);
		Format(question, maxlen, "%d + %d", a, b);
		answer = a + b;
	}
	else
	{
		a = GetRandomInt(15, 50);
		b = GetRandomInt(1, a - 1);
		Format(question, maxlen, "%d - %d", a, b);
		answer = a - b;
	}
}

/**
 * Medium: multiplication or a + b*c (order of operations).
 *   a * b        where a,b ∈ [3, 12]
 *   a + b * c    where a ∈ [5, 20], b,c ∈ [2, 8]
 */
static void MathQuiz_GenerateMedium(char[] question, int maxlen, int& answer)
{
	int a, b, c;

	if (GetRandomInt(0, 1) == 0)
	{
		a = GetRandomInt(3, 12);
		b = GetRandomInt(3, 12);
		Format(question, maxlen, "%d * %d", a, b);
		answer = a * b;
	}
	else
	{
		a = GetRandomInt(5, 20);
		b = GetRandomInt(2, 8);
		c = GetRandomInt(2, 8);
		Format(question, maxlen, "%d + %d * %d", a, b, c);
		answer = a + b * c;
	}
}

/**
 * Hard: multi-step expressions with parentheses or larger numbers.
 *   (a + b) * c    where a,b ∈ [5, 15], c ∈ [3, 8]
 *   a * b - c      where a,b ∈ [5, 12], c ∈ [1, 20]
 *   a * b + c      where a,b ∈ [5, 12], c ∈ [5, 30]
 */
static void MathQuiz_GenerateHard(char[] question, int maxlen, int& answer)
{
	int a, b, c;

	switch (GetRandomInt(0, 2))
	{
		case 0:
		{
			a = GetRandomInt(5, 15);
			b = GetRandomInt(5, 15);
			c = GetRandomInt(3, 8);
			Format(question, maxlen, "(%d + %d) * %d", a, b, c);
			answer = (a + b) * c;
		}
		case 1:
		{
			a = GetRandomInt(5, 12);
			b = GetRandomInt(5, 12);
			c = GetRandomInt(1, 20);
			Format(question, maxlen, "%d * %d - %d", a, b, c);
			answer = a * b - c;
		}
		case 2:
		{
			a = GetRandomInt(5, 12);
			b = GetRandomInt(5, 12);
			c = GetRandomInt(5, 30);
			Format(question, maxlen, "%d * %d + %d", a, b, c);
			answer = a * b + c;
		}
	}
}

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

/**
 * Returns true if the string is a valid integer (optionally negative).
 */
static bool MathQuiz_IsInteger(const char[] str)
{
	if (str[0] == '\0')
		return false;

	int start = 0;
	if (str[0] == '-')
		start = 1;

	if (str[start] == '\0')
		return false;

	for (int i = start; str[i] != '\0'; i++)
	{
		if (str[i] < '0' || str[i] > '9')
			return false;
	}

	return true;
}
