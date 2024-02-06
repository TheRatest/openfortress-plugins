#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>
#include <morecolors>

Database g_hSQL;

ConVar g_cvarHugsEnabled = null;
ConVar g_cvarHugsTopEnabled = null;
ConVar g_cvarHugTime = null;
ConVar g_cvarDebugLog = null;
ConVar g_cvarOfflinePlayerStats = null;
ConVar g_cvarMinHeadshotsQualify = null;

bool g_abInitializedClients[MAXPLAYERS];
int g_aiKillstreaks[MAXPLAYERS];
char g_aszStoredAuth[MAXPLAYERS][32];
// someone may manipulate b_IsTopThree i guess? i hope no one finds out that im allocating a whole 8 extra bytes of memory!!
int g_aiTopThree[5];

bool g_abHuggable[MAXPLAYERS];
int g_aiHugger[MAXPLAYERS];

bool g_abMissDebounce[MAXPLAYERS];

public Plugin myinfo = {
	name = "Player Stats",
	author = "ratest",
	description = "Keeps track of your stats!",
	version = "1.03",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("ratsplugins.phrases.txt");
	
	g_cvarHugsEnabled = CreateConVar("sm_playerstats_hugs", "0", "Keep track of hugs (when players kill each other within a short timespan)", 0, true, 0.0, true, 1.0);
	g_cvarHugsTopEnabled = CreateConVar("sm_playerstats_hugs_top", "1", "Show the best hugger in !top (must have hugs enabled beforehand for this to apply)", 0, true, 0.0, true, 1.0);
	g_cvarHugTime = CreateConVar("sm_playerstats_hugtime", "1.25", "Maximum amount of time that can pass when players killing each other is considered a hug", 0, true, 0.0, true, 5.0);
	g_cvarOfflinePlayerStats = CreateConVar("sm_playerstats_offlineplayerstats", "0", "Whether players can see offline players' stats using their SteamID2", 0, true, 0.0, true, 1.0);
	g_cvarMinHeadshotsQualify = CreateConVar("sm_playerstats_minheadshots", "10", "How many headshots a player must have before they can be a headshotter in !top", 0, true, 0.0, true, 1000.0);
	g_cvarDebugLog = CreateConVar("sm_playerstats_debug", "0", "Print most stat changes to the corresponding player", 0, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_playerstats_stats", Command_ViewStats, "View your stats (or someone else's)");
	RegConsoleCmd("sm_playerstats_top", Command_ViewTop, "View the top players");
	RegAdminCmd("sm_playerstats_offlinestats", Command_ViewOfflineStats, ADMFLAG_CONVARS, "View an offline player's stats using their SteamID2");
	RegAdminCmd("sm_playerstats_reset", Command_ResetStats, ADMFLAG_RCON, "Reset a player's stats (u evil thing)");
	RegAdminCmd("sm_playerstats_erase", Command_EraseStats, ADMFLAG_RCON, "Delete all stats a player has without re-initializing new ones (also kicks the player)");
	
	char szErr[256];
	g_hSQL = SQL_Connect("player_stats", true, szErr, 256);
	if(!g_hSQL) {
		LogError("<!> Couldn't connect to the \"player_stats\" database! Please set up the database in addons/sourcemod/configs/databases.cfg before using this plugin.");
	} else {
		if(SQL_FastQuery(g_hSQL, "IF OBJECT_ID('player_stats') IS NOT NULL BEGIN RETURN TRUE END ELSE BEGIN RETURN FALSE END")) {
			PrintToServer("Table exists");
		} else {
			SQL_SetCharset(g_hSQL, "utf8mb4");
			if(!SQL_FastQuery(g_hSQL, "CREATE TABLE IF NOT EXISTS player_stats (\
																	steam_auth varchar(32) NOT NULL PRIMARY KEY,\
																	name varchar(128),\
																	color int,\
																	frags int,\
																	deaths int,\
																	kdr float,\
																	powerup_kills int,\
																	melee_kills int,\
																	headshots int,\
																	rg_headshots int,\
																	rg_bodyshots int,\
																	rg_headshotrate float,\
																	rl_airshots int,\
																	matches int,\
																	wins int,\
																	top3_wins int,\
																	join_count int,\
																	highest_killstreak smallint,\
																	highest_killstreak_map varchar(128),\
																	damage_dealt bigint,\
																	damage_taken bigint,\
																	hugs int,\
																	ssg_meatshots int,\
																	ssg_normalshots int,\
																	ssg_misses int,\
																	gl_airshots int,\
																	rg_misses int,\
																	suicides int\
																	) ENGINE=InnoDB DEFAULT CHARSET=utf8;")) {
				LogError("<!> Couldnt create player_stats table!");
			}
		}
	}

	for(int i = 1; i < MaxClients; ++i) {
		if(!IsClientInGame(i))
			continue;
			
		if(IsClientAuthorized(i)) {
			GetClientAuthId(i, AuthId_Steam2, g_aszStoredAuth[i], 32);
			g_abInitializedClients[i] = InitPlayerData(i, g_aszStoredAuth[i]);
			g_aiKillstreaks[i] = 0;
			
			SDKHook(i, SDKHook_OnTakeDamage, Event_PlayerDamaged);
		}
	}
	
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamplay_round_win", Event_RoundEnd);

	AutoExecConfig(true, "playerstats");
}

bool InitPlayerData(int iClient, const char[] szAuth) {
	if(iClient <= 0 || iClient >= MAXPLAYERS)
		return false;

	char szClientName[128];
	GetClientName(iClient, szClientName, 128);
	
	if(StrEqual(szAuth, "STEAM_ID_PENDING", false) || StrEqual(szAuth, "STEAM_ID_LAN", false) || StrEqual(szAuth, "LAN", false) || StrEqual(szAuth, "BOT", false))
		return false;
	
	if(g_hSQL == INVALID_HANDLE)
		return false;
	
	// this is my first time writing sql, i sure hope no one finds vulnerabilites in my plugin!!
	ReplaceString(szClientName, 128, "'", "''", false);
	
	char szQuery1[512];
	Format(szQuery1, 512, "SELECT steam_auth FROM player_stats WHERE steam_auth = '%s'", szAuth);
	char szQuery2[512];
	Format(szQuery2, 512, "INSERT INTO player_stats VALUES (\"%s\", \"%s\", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, \"None\", 0, 0, 0, 0, 0, 0, 0, 0, 0);", szAuth, szClientName);
	DBResultSet hResults = SQL_Query(g_hSQL, szQuery1);
	
	if(hResults.RowCount == 0) {
		if (!SQL_FastQuery(g_hSQL, szQuery2)) {
			char szErr[256];
			SQL_GetError(g_hSQL, szErr, 256);
			LogError("<!> InitPlayerData 2nd query failed, %s", szErr);
			CloseHandle(hResults);
			return false;
		}
	}
	
	int iPlayerColor = 0;
	char szPlrClrR[4];
	char szPlrClrG[4];
	char szPlrClrB[4];
	GetClientInfo(iClient, "of_color_r", szPlrClrR, 4);
	GetClientInfo(iClient, "of_color_g", szPlrClrG, 4);
	GetClientInfo(iClient, "of_color_b", szPlrClrB, 4);
	int iPlrClrRed = StringToInt(szPlrClrR);
	int iPlrClrGreen = StringToInt(szPlrClrG);
	int iPlrClrBlue = StringToInt(szPlrClrB);
	// theoretically the game won't let a player set their color above 255 but yeah, this extra check won't hurt anyone i suppose
	if(iPlrClrRed < 0)
		iPlrClrRed = 0;
	if(iPlrClrRed > 255)
		iPlrClrRed = 255;
	if(iPlrClrGreen < 0)
		iPlrClrGreen = 0;
	if(iPlrClrGreen > 255)
		iPlrClrGreen = 255;
	if(iPlrClrBlue < 0)
		iPlrClrBlue = 0;
	if(iPlrClrBlue > 255)
		iPlrClrBlue = 255;
	
	iPlayerColor = iPlrClrBlue + iPlrClrGreen * 256 + iPlrClrRed * 256 * 256;
	char szQueryColor[128];
	Format(szQueryColor, 128, "UPDATE player_stats SET color = %i WHERE steam_auth = '%s'", iPlayerColor, szAuth);
	SQL_FastQuery(g_hSQL, szQueryColor);
	
	CloseHandle(hResults);
	return true;
}

void IncrementField(int iClient, char[] szField, int iAdd = 1) {
	if(iClient <= 0 || iClient >= MAXPLAYERS)
		return;
		
	if(!g_abInitializedClients[iClient])
		return;
	
	char szQuery[200];
	Format(szQuery, 200, "UPDATE player_stats SET %s = %s + %i WHERE steam_auth = '%s'", szField, szField, iAdd, g_aszStoredAuth[iClient]);
	if(IsClientInGame(iClient) && GetConVarBool(g_cvarDebugLog))
		PrintToChat(iClient, "%s += %i", szField, iAdd);
	if (!SQL_FastQuery(g_hSQL, szQuery)) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> IncrementField query failed, %s", szErr);
		return;
	} else {
		if(StrEqual(szField, "rg_headshots", false) || StrEqual(szField, "rg_bodyshots", false) || StrEqual(szField, "rg_misses", false)) {
			char szRateUpdateQuery[256];
			Format(szRateUpdateQuery, 256, "UPDATE player_stats SET rg_headshotrate = rg_headshots / (rg_headshots + rg_bodyshots + rg_misses) WHERE steam_auth = '%s'", g_aszStoredAuth[iClient]);
			SQL_FastQuery(g_hSQL, szRateUpdateQuery);
		}
		if(StrEqual(szField, "deaths", false) || StrEqual(szField, "frags", false)) {
			char szRateUpdateQuery[256];
			Format(szRateUpdateQuery, 256, "UPDATE player_stats SET kdr = frags / deaths WHERE steam_auth = '%s'", g_aszStoredAuth[iClient]);
			SQL_FastQuery(g_hSQL, szRateUpdateQuery);
		}
	}
}

void ResetKillstreak(int iClient) {
	if(!g_abInitializedClients[iClient])
		return;
	
	char szQuery[256];
	Format(szQuery, 256, "SELECT highest_killstreak FROM player_stats WHERE steam_auth = '%s'", g_aszStoredAuth[iClient]);
	DBResultSet hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults == INVALID_HANDLE) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> ResetKillstreak 1st query failed, %s", szErr);
		return;
	}
	if(!SQL_FetchRow(hResults)) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> ResetKillstreak FetchRow failed, %s", szErr);
		return;
	}

	if(hResults.FetchInt(0) < g_aiKillstreaks[iClient]) {
		char szQueryUpdate[256];
		char szMap[128];
		GetCurrentMap(szMap, 128);
		Format(szQueryUpdate, 256, "UPDATE player_stats SET highest_killstreak = %i, highest_killstreak_map = \"%s\" WHERE steam_auth = '%s'", g_aiKillstreaks[iClient], szMap, g_aszStoredAuth[iClient]);
		if(!SQL_FastQuery(g_hSQL, szQueryUpdate)) {
			char szErr[256];
			SQL_GetError(g_hSQL, szErr, 256);
			LogError("<!> ResetKillstreak 2nd query failed, %s", szErr);
		}
	}
	
	CloseHandle(hResults);
	g_aiKillstreaks[iClient] = 0;
}

public void OnPluginEnd() {
	// free handle n shit !!
	CloseHandle(g_hSQL);
}

public void OnClientAuthorized(int iClient, const char[] szAuth) {
	char szClientName[128];
	GetClientName(iClient, szClientName, 128);
	g_abInitializedClients[iClient] = InitPlayerData(iClient, szAuth);
	strcopy(g_aszStoredAuth[iClient], 32, szAuth);
	g_aiKillstreaks[iClient] = 0;
	if(g_abInitializedClients[iClient]) {
		IncrementField(iClient, "join_count");
	} else {
		if(IsClientInGame(iClient))
			CPrintToChat(iClient, "%t %t", "Rat CommandPrefix", "Rat UninitializedSelf");
	}
}

public void OnClientDisconnect(int iClient) {
	g_abInitializedClients[iClient] = false;
	strcopy(g_aszStoredAuth[iClient], 32, "");
	ResetKillstreak(iClient);
}

public void OnMapStart() {
	for(int i = 0; i < MAXPLAYERS; ++i) {
		g_aiKillstreaks[i] = 0;
	}
}

public void OnClientPutInServer(int iClient) {
	SDKHook(iClient, SDKHook_OnTakeDamage, Event_PlayerDamaged);
}

void Event_PlayerHurt(Event event, const char[] szEvName, bool bDontBroadcast) {
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));

	int iDamageTaken = GetEventInt(event, "damageamount");
	if(iDamageTaken > 500)
		iDamageTaken = 500;

	IncrementField(iVictim, "damage_taken", iDamageTaken);
	
	if(iAttacker == iVictim)
		return;
	
	IncrementField(iAttacker, "damage_dealt", GetEventInt(event, "damageamount"));
}

public Action TF2_CalcIsAttackCritical(int iClient, int iWeapon, char[] szWeapon, bool& bResult) {
	if(StrEqual(szWeapon, "tf_weapon_railgun", false) || StrEqual(szWeapon, "railgun", false)) {
		IncrementField(iClient, "rg_misses");
		return Plugin_Continue;
	} else if(StrEqual(szWeapon, "tf_weapon_supershotgun", false) || StrEqual(szWeapon, "supershotgun", false)) {
		IncrementField(iClient, "ssg_misses");
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

Action Event_PlayerDamaged(int iVictim, int& iAttacker, int& iInflictor, float& flDamage, int& iDamageType, int& iWeapon, float vecDamageForce[3], float vecDamagePosition[3], int iDamageCustom) {
	if(iVictim <= 0 || iVictim > MaxClients || iAttacker < 0 || iAttacker > MaxClients)
		return Plugin_Continue;

	if(!g_abInitializedClients[iAttacker])
		return Plugin_Continue;

	if(iDamageCustom == 86 || iDamageCustom == 1) {
		IncrementField(iAttacker, "headshots");
	}

	if(iWeapon < 0)
		return Plugin_Continue;
	
	char szWeapon[128];
	GetEntityClassname(iWeapon, szWeapon, 128)
	if(StrEqual(szWeapon, "tf_weapon_railgun", false)) {
		if(iDamageCustom == 86 || iDamageCustom == 1) {
			IncrementField(iAttacker, "rg_headshots");
		} else {
			IncrementField(iAttacker, "rg_bodyshots");
		}
		IncrementField(iAttacker, "rg_misses", -1);
	} else if (StrEqual(szWeapon, "tf_weapon_supershotgun", false)) {
		if(g_abMissDebounce[iAttacker])
			return Plugin_Continue;
		
		g_abMissDebounce[iAttacker] = true;
		CreateTimer(0.05, Timer_ResetHitDebounce, iAttacker);
		
		if(flDamage >= 100.0)
			IncrementField(iAttacker, "ssg_meatshots");
		else
			IncrementField(iAttacker, "ssg_normalshots");
			
		IncrementField(iAttacker, "ssg_misses", -1);
	}

	return Plugin_Continue;
}

void Event_PlayerDeath(Event event, const char[] szEventName, bool bDontBroadcast) {
	int iVictimId = GetEventInt(event, "userid");
	int iAttackerId = GetEventInt(event, "attacker");
	
	int iVictim = GetClientOfUserId(iVictimId);
	int iClient = GetClientOfUserId(iAttackerId);
	
	if((!g_abInitializedClients[iVictim] || !g_abInitializedClients[iClient]) && !IsFakeClient(iVictim))
		return;
	
	char szWeapon[128];
	GetEventString(event, "weapon", szWeapon, 128);
	
	IncrementField(iVictim, "deaths");
	ResetKillstreak(iVictim);
	if(iVictim != iClient) {
		IncrementField(iClient, "frags");
		if(StrEqual(szWeapon, "crowbar", false) || StrEqual(szWeapon, "lead_pipe", false))
			IncrementField(iClient, "melee_kills");
		
		if(iClient > 0) {
			if(TF2_IsPlayerInCondition(iClient, TFCond_CritPowerup) || TF2_IsPlayerInCondition(iClient, TFCond_Haste) || TF2_IsPlayerInCondition(iClient, TFCond_Shield) || TF2_IsPlayerInCondition(iClient, TFCond_Berserk) || TF2_IsPlayerInCondition(iClient, TFCond_InvisPowerup))
				IncrementField(iClient, "powerup_kills");
		}
		
		g_aiKillstreaks[iClient] += 1;
		
		if(g_abHuggable[iVictim] && g_aiHugger[iVictim] == iClient) {
			IncrementField(iClient, "hugs");
			IncrementField(iVictim, "hugs");
			return;
		}
		
		g_aiHugger[iClient] = iVictim;
		g_abHuggable[iClient] = true;
		CreateTimer(GetConVarFloat(g_cvarHugTime), Timer_ResetHugData, iClient);
	} else {
		IncrementField(iClient, "suicides");
	}
}

Action Timer_ResetHugData(Handle hTimer, int iClient) {
	g_aiHugger[iClient] = 0;
	g_abHuggable[iClient] = false;
	
	return Plugin_Handled;
}

Action Timer_ResetHitDebounce(Handle hTimer, int iClient) {
	g_abMissDebounce[iClient] = false;
	return Plugin_Handled;
}

public void OnEntityCreated(int iEnt, const char[] szClassname) {
	if(!StrEqual(szClassname, "tf_projectile_rocket", false) && !StrEqual(szClassname, "tf_projectile_pipe", false))
		return;
		
	SDKHook(iEnt, SDKHook_StartTouch, Event_RocketTouch);
}

Action Event_RocketTouch(int iEntity, int iOther) {
	char szMyClassname[128];
	char szOtherClassname[128];
	GetEntityClassname(iEntity, szMyClassname, 128);
	GetEntityClassname(iOther, szOtherClassname, 128);
	if(!StrEqual(szOtherClassname, "player", false))
		return Plugin_Continue;
	int iAttacker = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	
	if(iAttacker == iOther)
		return Plugin_Continue;
	
	if(!(GetEntityFlags(iOther) & FL_ONGROUND)) {
		if(StrEqual(szMyClassname, "tf_projectile_rocket", false))
			IncrementField(iAttacker, "rl_airshots");
		else if(StrEqual(szMyClassname, "tf_projectile_pipe", false))
			IncrementField(iAttacker, "gl_airshots");
	}
	
	return Plugin_Continue;
}

int GetPlayerFrags(int iClient) {
	int iFrags = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iScore", 4, iClient);
	return iFrags;
}

void Event_RoundEnd(Event event, const char[] szEventName, bool bDontBroadcast) {
	int iTopThreeCounter = 0;
	for(int i = 1; i < MaxClients; ++i) {
		if(!IsClientInGame(i))
			continue;
			
		if(!g_abInitializedClients[i])
			continue;
			
		IncrementField(i, "matches");
		ResetKillstreak(i);
		
		bool bIsTopThree = LoadFromAddress(GetEntityAddress(i) + view_as<Address>(FindSendPropInfo("CTFPlayer", "m_bIsTopThree")), NumberType_Int8) & 255;
		
		if(bIsTopThree) {
			IncrementField(i, "top3_wins");
			g_aiTopThree[iTopThreeCounter] = i;
			++iTopThreeCounter;
		}
	}
	
	int iTopOneClient = g_aiTopThree[0];
	for(int i = 0; i < iTopThreeCounter; ++i) {
		if(GetPlayerFrags(g_aiTopThree[i]) > GetPlayerFrags(iTopOneClient))
			iTopOneClient = g_aiTopThree[i];
	}
	
	IncrementField(iTopOneClient, "wins");
}

void PrintPlayerStats(int iClient, int iStatsOwner, char[] szAuthArg = "") {
	bool bSelfRequest = iClient == iStatsOwner;
	char szAuthToUse[32];
	if(iStatsOwner != -1) {
		if(!g_abInitializedClients[iStatsOwner]) {
			char szClientName[128];
			GetClientName(iStatsOwner, szClientName, 128);
			
			if(bSelfRequest)
				CPrintToChat(iClient, "%t %t", "Rat CommandPrefix", "Rat UninitializedSelf");
			else
				CPrintToChat(iClient, "%t %t", "Rat CommandPrefix", "Rat UninitializedPlayer", szClientName);
			return;
		}
		
		strcopy(szAuthToUse, 32, g_aszStoredAuth[iStatsOwner]);
	} else {
		strcopy(szAuthToUse, 32, szAuthArg);
	}

	char szQuery[256];
	Format(szQuery, 256, "SELECT * FROM player_stats WHERE steam_auth = '%s'", szAuthToUse);
	DBResultSet hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults.RowCount < 1) {
		ReplyToCommand(iClient, "[PlayerStats] No target found!");
		return;
	}
	SQL_FetchRow(hResults);
	
	char szName[128];
	hResults.FetchString(1, szName, 128);
	int iUnresolvedColor = hResults.FetchInt(2);
	char szColor[12];
	IntColorToString(iUnresolvedColor, szColor);
	int iFrags = hResults.FetchInt(3);
	int iDeaths = hResults.FetchInt(4);
	float flKDR = hResults.FetchFloat(5);
	int iPowerupKills = hResults.FetchInt(6);
	int iMeleeKills = hResults.FetchInt(7);
	// int iHeadshots = hResults.FetchInt(8);
	int iRGHeadshots = hResults.FetchInt(9);
	//int iRGBodyshots = hResults.FetchInt(10);
	/*float iRGTotalShots = (0.0 + iRGHeadshots + iRGBodyshots);
	int iRGHeadshotPercentageHigh = RoundFloat(((0.0 + iRGHeadshots) / iRGTotalShots) * 1000) / 10;
	int iRGHeadshotPercentageLow = RoundFloat(((0.0 + iRGHeadshots) / iRGTotalShots) * 1000) % 10;
	if(iRGTotalShots == 0) {
		iRGHeadshotPercentageHigh = 0;
		iRGHeadshotPercentageLow = 0;
	}*/
	float flRGHeadshotRate = hResults.FetchFloat(11);
	// i dont like how sourcemod outputs floats to chat
	int iRGHeadshotPercentageHigh = RoundFloat(flRGHeadshotRate * 1000) / 10;
	int iRGHeadshotPercentageLow = RoundFloat(flRGHeadshotRate * 1000) % 10;
	
	int iRLAirshots = hResults.FetchInt(12);
	int iMatches = hResults.FetchInt(13);
	int iWins = hResults.FetchInt(14);
	int iTop3Wins = hResults.FetchInt(15);
	// int iJoinCount = hResults.FetchInt(16);
	int iHighestKS = hResults.FetchInt(17);
	char szHighestKSMap[128];
	hResults.FetchString(18, szHighestKSMap, 128);
	int iDamageDealt = hResults.FetchInt(19);
	int iDamageTaken = hResults.FetchInt(20);
	int iHugs = hResults.FetchInt(21);
	int iSSGMeatshots = hResults.FetchInt(22);
	int iSSGNormalShots = hResults.FetchInt(23);
	int iSSGMisses = hResults.FetchInt(24);
	int iGLAirshots = hResults.FetchInt(25);
	
	if(bSelfRequest)
		CPrintToChat(iClient, "%t %t", "Rat CommandPrefix", "Rat YourStats");
	else
		CPrintToChat(iClient, "%t %t", "Rat CommandPrefix", "Rat PlayerStats", szName, szColor);
	
	// max message length is a bitch
	CPrintToChat(iClient, "%t\n%t\n%t", "Rat StatsKD", iFrags, iDeaths, flKDR, "Rat StatsMeleeAndPowerupKills", iMeleeKills, iPowerupKills, "Rat StatsSSG", iSSGMeatshots, iSSGNormalShots, iSSGMisses);
	CPrintToChat(iClient, "%t\n%t", "Rat StatsRGHeadshots", iRGHeadshots, iRGHeadshotPercentageHigh, iRGHeadshotPercentageLow, "Rat StatsAirshots", iRLAirshots, iGLAirshots)
	if(GetConVarBool(g_cvarHugsEnabled))
		CPrintToChat(iClient, "%t\n%t\n%t\n%t", "Rat StatsMatches", iWins, iTop3Wins, iMatches, "Rat StatsHighestKillstreak", iHighestKS, szHighestKSMap, "Rat StatsDamage", iDamageDealt, iDamageTaken, "Rat StatsHugs", iHugs);
	else
		CPrintToChat(iClient, "%t\n%t\n%t", "Rat StatsMatches", iWins, iTop3Wins, iMatches, "Rat StatsHighestKillstreak", iHighestKS, szHighestKSMap, "Rat StatsDamage", iDamageDealt, iDamageTaken);
}

void IntColorToString(int iColor, char[] strColor, int iMaxLen = 10) {
	int iRed = iColor / 256 / 256;
	int iGreen = iColor / 256 % 256;
	int iBlue = iColor % 256;
	char szRed[4];
	char szGreen[4];
	char szBlue[4];
	if(iRed > 15)
		Format(szRed, 4, "%X", iRed);
	else
		Format(szRed, 4, "0%X", iRed);
		
	if(iGreen > 15)
		Format(szGreen, 4, "%X", iGreen);
	else
		Format(szGreen, 4, "0%X", iGreen);
		
	if(iBlue > 15)
		Format(szBlue, 4, "%X", iBlue);
	else
		Format(szBlue, 4, "0%X", iBlue);
	Format(strColor, iMaxLen, "%s%s%s%s", "\x07", szRed, szGreen, szBlue);
}

void PrintTopPlayers(int iClient) {
	char szQuery[256];
	DBResultSet hResults;
	
	char szBestFragger[128];
	char szBestFraggerColor[12];
	int iMostFrags = 0;
	
	Format(szQuery, 256, "SELECT * FROM player_stats WHERE (frags = (SELECT MAX(frags) FROM player_stats))");
	hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults == INVALID_HANDLE) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> PrintTopPlayers 1st query failed, %s", szErr);
	}
	SQL_FetchRow(hResults);
	hResults.FetchString(1, szBestFragger, 128);
	IntColorToString(hResults.FetchInt(2), szBestFraggerColor);
	iMostFrags = hResults.FetchInt(3);
	CloseHandle(hResults);
	
	char szBestPlayer[128];
	char szBestPlayerColor[12];
	int iMostWins = 0;
	
	Format(szQuery, 256, "SELECT * FROM player_stats WHERE (wins = (SELECT MAX(wins) FROM player_stats))");
	hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults == INVALID_HANDLE) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> PrintTopPlayers 1.5 query failed, %s", szErr);
	}
	SQL_FetchRow(hResults);
	hResults.FetchString(1, szBestPlayer, 128);
	IntColorToString(hResults.FetchInt(2), szBestPlayerColor);
	iMostWins = hResults.FetchInt(14);
	CloseHandle(hResults);
	
	// my head hurts
	char szBestHeadshotter[128];
	char szBestHeadshotterColor[12];
	float flBestHSRate = 0.0;
	
	Format(szQuery, 256, "SELECT * FROM player_stats WHERE (rg_headshotrate = (SELECT MAX(rg_headshotrate) FROM player_stats WHERE rg_headshots > %i))", GetConVarInt(g_cvarMinHeadshotsQualify));
	hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults == INVALID_HANDLE) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> PrintTopPlayers 2nd query failed, %s", szErr);
	}
	if(hResults.RowCount < 1) {
		Format(szQuery, 256, "SELECT * FROM player_stats WHERE (rg_headshotrate = (SELECT MAX(rg_headshotrate) FROM player_stats))");
		hResults = SQL_Query(g_hSQL, szQuery);
		if(hResults == INVALID_HANDLE) {
			char szErr[256];
			SQL_GetError(g_hSQL, szErr, 256);
			LogError("<!> PrintTopPlayers 2nd query failed, %s", szErr);
		}
	}
	SQL_FetchRow(hResults);
	hResults.FetchString(1, szBestHeadshotter, 128);
	IntColorToString(hResults.FetchInt(2), szBestHeadshotterColor);
	flBestHSRate = hResults.FetchFloat(11);
	CloseHandle(hResults);
	
	int iBestHSRateHigh = RoundFloat(flBestHSRate * 1000) / 10;
	int iBestHSRateLow = RoundFloat(flBestHSRate * 1000) % 10;
	
	char szBestKillstreaker[128];
	char szBestKillstreakerColor[12];
	char szBestKillstreakerMap[128];
	int iBestKillstreak = 0;
	
	Format(szQuery, 256, "SELECT * FROM player_stats WHERE (highest_killstreak = (SELECT MAX(highest_killstreak) FROM player_stats))");
	hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults == INVALID_HANDLE) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> PrintTopPlayers 3rd query failed, %s", szErr);
	}
	SQL_FetchRow(hResults);
	hResults.FetchString(1, szBestKillstreaker, 128);
	IntColorToString(hResults.FetchInt(2), szBestKillstreakerColor);
	hResults.FetchString(18, szBestKillstreakerMap, 128);
	iBestKillstreak = hResults.FetchInt(17);
	CloseHandle(hResults);
	
	char szBestSSGer[128];
	char szBestSSGerColor[12];
	int iMostMeatshots = 0;
	int iSSGNormalShots = 0;
	int iSSGMisses = 0;
	int iSSGTotalShots = 0;
	
	Format(szQuery, 256, "SELECT * FROM player_stats WHERE (ssg_meatshots = (SELECT MAX(ssg_meatshots) FROM player_stats))");
	hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults == INVALID_HANDLE) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> PrintTopPlayers 4th query failed, %s", szErr);
	}
	SQL_FetchRow(hResults);
	hResults.FetchString(1, szBestSSGer, 128);
	IntColorToString(hResults.FetchInt(2), szBestSSGerColor);
	iMostMeatshots = hResults.FetchInt(22);
	iSSGNormalShots = hResults.FetchInt(23);
	iSSGMisses = hResults.FetchInt(24);
	iSSGTotalShots = iMostMeatshots + iSSGNormalShots + iSSGMisses;
	if(iSSGTotalShots <= 0)
		iSSGTotalShots = 1;
	int iMeatshotRateHigh = RoundFloat(((0.0 + iMostMeatshots) / iSSGTotalShots) * 1000.0) / 10;
	int iMeatshotRateLow = RoundFloat(((0.0 + iMostMeatshots) / iSSGTotalShots) * 1000.0) % 10;
	
	CloseHandle(hResults);
	
	char szBestDamager[128];
	char szBestDamagerColor[12];
	int iMostDamage = 0;
	
	Format(szQuery, 256, "SELECT * FROM player_stats WHERE (damage_dealt = (SELECT MAX(damage_dealt) FROM player_stats))");
	hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults == INVALID_HANDLE) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> PrintTopPlayers 4th query failed, %s", szErr);
	}
	SQL_FetchRow(hResults);
	hResults.FetchString(1, szBestDamager, 128);
	IntColorToString(hResults.FetchInt(2), szBestDamagerColor);
	iMostDamage = hResults.FetchInt(19);
	CloseHandle(hResults);
	
	char szBestHugger[128];
	char szBestHuggerColor[12];
	int iMostHugs = 0;
	
	Format(szQuery, 256, "SELECT * FROM player_stats WHERE (hugs = (SELECT MAX(hugs) FROM player_stats))");
	hResults = SQL_Query(g_hSQL, szQuery);
	if(hResults == INVALID_HANDLE) {
		char szErr[256];
		SQL_GetError(g_hSQL, szErr, 256);
		LogError("<!> PrintTopPlayers 5th query failed, %s", szErr);
	}
	SQL_FetchRow(hResults);
	hResults.FetchString(1, szBestHugger, 128);
	IntColorToString(hResults.FetchInt(2), szBestHuggerColor);
	iMostHugs = hResults.FetchInt(21);
	CloseHandle(hResults);
	
	const int iMaxNameLen = 25;
	
	if(strlen(szBestFragger) > iMaxNameLen)
		strcopy(szBestFragger[iMaxNameLen-5], 4, "...");
	if(strlen(szBestPlayer) > iMaxNameLen)
		strcopy(szBestPlayer[iMaxNameLen-5], 4, "...");
	if(strlen(szBestHeadshotter) > iMaxNameLen)
		strcopy(szBestHeadshotter[iMaxNameLen-5], 4, "...");
	if(strlen(szBestKillstreaker) > iMaxNameLen)
		strcopy(szBestKillstreaker[iMaxNameLen-5], 4, "...");
	if(strlen(szBestSSGer) > iMaxNameLen)
		strcopy(szBestSSGer[iMaxNameLen-5], 4, "...");
	if(strlen(szBestDamager) > iMaxNameLen)
		strcopy(szBestDamager[iMaxNameLen-5], 4, "...");
	if(strlen(szBestHugger) > iMaxNameLen)
		strcopy(szBestHugger[iMaxNameLen-5], 4, "...");
	
	CPrintToChat(iClient, "%t %t", "Rat CommandPrefix", "Rat TopPlayers");
	CPrintToChat(iClient, "%t\n%t", "Rat TopFragger", szBestFragger, szBestFraggerColor, iMostFrags, "Rat TopWinner", szBestPlayer, szBestPlayerColor, iMostWins);
	CPrintToChat(iClient, "%t\n%t", "Rat TopHeadshotter", szBestHeadshotter, szBestHeadshotterColor, iBestHSRateHigh, iBestHSRateLow, "Rat TopKillstreaker", szBestKillstreaker, szBestKillstreakerColor, iBestKillstreak, szBestKillstreakerMap);
	CPrintToChat(iClient, "%t\n%t", "Rat TopSSGer", szBestSSGer, szBestSSGerColor, iMostMeatshots, iMeatshotRateHigh, iMeatshotRateLow, "Rat TopDamager", szBestDamager, szBestDamagerColor, iMostDamage);
	if(GetConVarBool(g_cvarHugsEnabled) && GetConVarBool(g_cvarHugsTopEnabled)) {
		CPrintToChat(iClient, "%t", "Rat TopHugger", szBestHugger, szBestHuggerColor, iMostHugs);
	}
}

public Action OnClientSayCommand(int iClient, const char[] szCommand, const char[] szArg) {
	char szArgs[3][64];
	ExplodeString(szArg, " ", szArgs, 3, 64, true);
	if(StrEqual(szArg, "!stats", false)) {
		PrintPlayerStats(iClient, iClient);
		return Plugin_Stop;
	}
	if(StrEqual(szArg, "!top", false)) {
		PrintTopPlayers(iClient);
		return Plugin_Stop;
	}
	if(StrEqual(szArgs[0], "!stats", false)) {
		int aiTargets[2];
		char szTarget[128];
		bool bIsMLPhrase;
		int iTargetsFound = ProcessTargetString(szArgs[1], 1, aiTargets, 2, 0, szTarget, 128, bIsMLPhrase);
		if(iTargetsFound > 0) {
			PrintPlayerStats(iClient, aiTargets[0]);
			return Plugin_Stop;
		} else {
			if(GetConVarBool(g_cvarOfflinePlayerStats)) {
				char szAuth[32];
				strcopy(szAuth, 32, szArgs[1]);
				ReplaceString(szAuth, 32, "'", "");
				ReplaceString(szAuth, 32, ")", "");
				ReplaceString(szAuth, 32, "\"", "");
				PrintPlayerStats(iClient, -1, szAuth);
				return Plugin_Handled;
			}
			PrintPlayerStats(iClient, iClient);
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

Action Command_ResetStats(int iClient, int iArgs) {
	if(iArgs < 1 || iArgs > 1) {
		ReplyToCommand(iClient, "Usage: sm_playerstats_reset <player name>");
	}
	
	char szTargetName[128];
	GetCmdArg(1, szTargetName, 128)
	int aiTargets[2];
	char szTarget[128];
	bool bIsMLPhrase;
	int iTargetsFound = ProcessTargetString(szTargetName, 1, aiTargets, 2, 0, szTarget, 128, bIsMLPhrase);
	
	if(iTargetsFound > 0) {
		char szClientName[128];
		GetClientName(aiTargets[0], szClientName, 128);
		char szAuth[32];
		GetClientAuthId(aiTargets[0], AuthId_Steam2, szAuth, 32);
		if(!g_abInitializedClients[aiTargets[0]]) {
			ReplyToCommand(iClient, "[PlayerStats] %t", "Rat UninitializedPlayer", szClientName);
			return Plugin_Handled;
		}
		char szQuery[256];
		Format(szQuery, 256, "DELETE FROM player_stats WHERE steam_auth = '%s';", szAuth);
		SQL_FastQuery(g_hSQL, szQuery);
		g_abInitializedClients[aiTargets[0]] = InitPlayerData(aiTargets[0], szAuth);
		CPrintToChat(aiTargets[0], "%t %t", "Rat CommandPrefix", "Rat StatsResetByAdmin");
		ReplyToCommand(iClient, "[PlayerStats] Successfully reset %s's stats", szClientName);
		return Plugin_Handled;
	} else {
		ReplyToCommand(iClient, "No target found (you can't use SteamID2 for this one)");
		return Plugin_Handled;
	}
}

Action Command_EraseStats(int iClient, int iArgs) {
	if(iArgs < 1 || iArgs > 1) {
		ReplyToCommand(iClient, "Usage: sm_playerstats_erase <player name>");
	}
	
	char szTargetName[128];
	GetCmdArg(1, szTargetName, 128)
	int aiTargets[2];
	char szTarget[128];
	bool bIsMLPhrase;
	int iTargetsFound = ProcessTargetString(szTargetName, 1, aiTargets, 2, 0, szTarget, 128, bIsMLPhrase);
	
	if(iTargetsFound > 0) {
		char szClientName[128];
		GetClientName(aiTargets[0], szClientName, 128);
		char szAuth[32];
		GetClientAuthId(aiTargets[0], AuthId_Steam2, szAuth, 32);
		if(!g_abInitializedClients[aiTargets[0]]) {
			ReplyToCommand(iClient, "[PlayerStats] %t", "Rat UninitializedPlayer", szClientName);
			return Plugin_Handled;
		}
		char szQuery[256];
		Format(szQuery, 256, "DELETE FROM player_stats WHERE steam_auth = '%s';", szAuth);
		SQL_FastQuery(g_hSQL, szQuery);
		KickClient(aiTargets[0], "Your stats have been erased by an admin");
		ReplyToCommand(iClient, "[PlayerStats] Successfully erased %s's stats", szClientName);
		return Plugin_Handled;
	} else {
		ReplyToCommand(iClient, "No target found (you can't use SteamID2 for this one)");
		return Plugin_Handled;
	}
}

Action Command_ViewStats(int iClient, int iArgs) {
	if(iArgs < 2)
		PrintPlayerStats(iClient, iClient);
	else {
		char szTargetName[128];
		GetCmdArg(1, szTargetName, 128)
		int aiTargets[2];
		char szTarget[128];
		bool bIsMLPhrase;
		int iTargetsFound = ProcessTargetString(szTargetName, 1, aiTargets, 2, 0, szTarget, 128, bIsMLPhrase);
		
		if(iTargetsFound > 0) {
			PrintPlayerStats(iClient, aiTargets[0]);
			return Plugin_Handled;
		} else {
			if(GetConVarBool(g_cvarOfflinePlayerStats)) {
				char szAuth[32];
				GetCmdArg(1, szAuth, 32);
				if(strlen(szAuth) < 7) {
					ReplyToCommand(iClient, "[PlayerStats] If you meant to use a SteamID2, you need to use quotes (e.g sm_playerstats_stats \"STEAM_0:1:522065531\")")
					return Plugin_Handled;
				}
				ReplaceString(szAuth, 32, "'", "");
				ReplaceString(szAuth, 32, ")", "");
				ReplaceString(szAuth, 32, "\"", "");
				PrintPlayerStats(iClient, -1, szAuth);
				return Plugin_Handled;
			}
			ReplyToCommand(iClient, "[PlayerStats] No target found");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Handled;
}

Action Command_ViewOfflineStats(int iClient, int iArgs) {
	if(iArgs == 5) {
		ReplyToCommand(iClient, "Usage: sm_playerstats_offlinestats \"<SteamID2>\" (Maybe you forgot to encase the steamid2 in double quotes?)");
		return Plugin_Handled;
	}
	if(iArgs != 1) {
		ReplyToCommand(iClient, "Usage: sm_playerstats_offlinestats \"<SteamID2>\" (e.g sm_playerstats_offlinestats \"STEAM_0:1:522065531\")");
		return Plugin_Handled;
	}
	char szAuth[32];
	// i hope this works
	ReplaceString(szAuth, 32, "'", "''", false);
	ReplaceString(szAuth, 32, " ", "", false);
	GetCmdArg(1, szAuth, 32);
	PrintPlayerStats(iClient, -1, szAuth);
	return Plugin_Handled;
}

Action Command_ViewTop(int iClient, int iArgs) {
	PrintTopPlayers(iClient);
	return Plugin_Handled;
}