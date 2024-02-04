#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>
#include <morecolors>

ConVar g_cvarPluginEnabled = null;
ConVar g_cvarAnnounceKillstreakProgressAmount = null;
ConVar g_cvarAnnounceKillstreakProgress = null;
ConVar g_cvarAnnounceKillstreakInterrupt = null;
ConVar g_cvarAnnounceKillstreakRoundEnd = null;
ConVar g_cvarAnnounceKillstreaksConsole = null;
ConVar g_cvarAnnounceKillstreaksServer = null;

int g_iKillstreaks[MAXPLAYERS];

int g_iHighestKillstreak = 0;
int g_iHighestKillstreakClient = 0;
char g_szHighestKillstreakerName[128] = "";

public Plugin myinfo = {
	name = "Killstreaks",
	author = "ratest",
	description = "Keep track of players' killstreak and announce the highest killstreaker each round",
	version = "1.33",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("ratsplugins.phrases.txt");
	
	g_cvarPluginEnabled = CreateConVar("of_killstreaks_enabled", "1", "Enable this plugin");
	g_cvarAnnounceKillstreakProgressAmount = CreateConVar("of_killstreaks_announce_progress_amount", "5", "The amount of frags required to announce a killstreak");
	g_cvarAnnounceKillstreakProgress = CreateConVar("of_killstreaks_announce_progress", "1", "Announce killstreaks each N kills");
	g_cvarAnnounceKillstreakInterrupt = CreateConVar("of_killstreaks_announce_interrupt", "1", "Announce killstreaks getting interrupted (when someone with a killstreak dies)");
	g_cvarAnnounceKillstreakRoundEnd = CreateConVar("of_killstreaks_announce_end", "1", "Announce the highest killstreak when the round ends");
	g_cvarAnnounceKillstreaksConsole = CreateConVar("of_killstreaks_announce_console", "1", "Announce killstreaks to the server console");
	g_cvarAnnounceKillstreaksServer = CreateConVar("of_killstreaks_server", "0", "Count the server's kills");
	RegAdminCmd("of_killstreaks_reset", Command_ResetKillstreaks, ADMFLAG_CHANGEMAP, "Set everyone's killstreak back to 0");
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	
	// for server tags and resetting killstreaks
	g_cvarPluginEnabled.AddChangeHook(Event_PluginStateChanged);
	
	AutoExecConfig(true, "killstreaks");
	
	if(GetConVarBool(g_cvarPluginEnabled)) {
		AddServerTagRat("killstreaks");
	}
}

Action Command_ResetKillstreaks(int iClient, int iArgs) {
	for(int i = 0; i < MaxClients; ++i) {
		g_iKillstreaks[i] = 0;
	}
	
	g_iHighestKillstreak = 0;
	g_iHighestKillstreakClient = 0;
	g_szHighestKillstreakerName = "";
	
	return Plugin_Handled;
}

public void OnMapStart() {
	for(int i = 0; i < MaxClients; ++i) {
		g_iKillstreaks[i] = 0;
	}
	
	g_iHighestKillstreak = 0;
	g_iHighestKillstreakClient = 0;
	g_szHighestKillstreakerName = "";
}

public void OnClientDisconnect_Post(int iClient) {
	g_iKillstreaks[iClient] = 0;
}

public void OnClientConnected(int iClient) {
	g_iKillstreaks[iClient] = 0;
}

void Event_PlayerDeath(Event event, const char[] szEventName, bool bDontBroadcast) {
	if(!GetConVarBool(g_cvarPluginEnabled))
		return;
	
	int iVictimId = GetEventInt(event, "userid");
	int iAttackerId = GetEventInt(event, "attacker");
	
	int iVictim = GetClientOfUserId(iVictimId);
	int iClient = GetClientOfUserId(iAttackerId);
	
	if(g_iKillstreaks[iVictim] >= GetConVarInt(g_cvarAnnounceKillstreakProgressAmount) && GetConVarBool(g_cvarAnnounceKillstreakInterrupt) && iClient != 0) {
		char szClientName[128];
		char szClientNameEx[128];
		GetClientName(iClient, szClientName, 128);
		GetClientName(iVictim, szClientNameEx, 128);
		CPrintToChatAllEx(iClient, "%t %t", "Rat CommandPrefix", "Rat KillstreakInterrupt", szClientName, szClientNameEx, g_iKillstreaks[iVictim]);
	}
	
	g_iKillstreaks[iVictim] = 0;
	
	if(!GetConVarBool(g_cvarAnnounceKillstreaksServer) && iClient == 0)
		return;
	
	++g_iKillstreaks[iClient];
	
	if(g_iKillstreaks[iClient] % GetConVarInt(g_cvarAnnounceKillstreakProgressAmount) == 0) {
		if(GetConVarBool(g_cvarAnnounceKillstreakProgress)) {
			char szClientName[128];
			GetClientName(iClient, szClientName, 128);
			CPrintToChatAllEx(iClient, "%t %t", "Rat CommandPrefix", "Rat Killstreak", szClientName, g_iKillstreaks[iClient]);
			
			if(GetConVarBool(g_cvarAnnounceKillstreaksConsole)) {
				char szServerText[512];
				Format(szServerText, 512, "%t %t", "Rat CommandPrefix", "Rat Killstreak", szClientName, g_iKillstreaks[iClient]);
				PrintToServer(szServerText);
			}
		}
	}
	
	if(iClient == 0)
		return;
	
	if(g_iKillstreaks[iClient] > g_iHighestKillstreak) {
		g_iHighestKillstreak = g_iKillstreaks[iClient];
		g_iHighestKillstreakClient = iClient;
		GetClientName(iClient, g_szHighestKillstreakerName, 128);
	}
}

void Event_RoundStart(Event event, const char[] szEventName, bool bDontBroadcast) {
	for(int i = 0; i < MaxClients; ++i) {
		g_iKillstreaks[i] = 0;
	}
	
	g_iHighestKillstreak = 0;
	g_iHighestKillstreakClient = 0;
	g_szHighestKillstreakerName = "";
}

void Event_RoundEnd(Event event, const char[] szEventName, bool bDontBroadcast) {
	if(!GetConVarBool(g_cvarPluginEnabled))
		return;
	
	if(!GetConVarBool(g_cvarAnnounceKillstreakRoundEnd))
		return;
		
	if(g_iHighestKillstreakClient == 0)
		return;
	
	if(GetConVarBool(g_cvarAnnounceKillstreakRoundEnd)) {
		CPrintToChatAllEx(g_iHighestKillstreakClient, "%t %t", "Rat CommandPrefix", "Rat KillstreakRoundEnd", g_szHighestKillstreakerName, g_iHighestKillstreak);
		
		if(GetConVarBool(g_cvarAnnounceKillstreaksConsole)) {
			char szText[256];
			Format(szText, 256, "%t %t", "Rat CommandPrefix", "Rat KillstreakRoundEnd", g_szHighestKillstreakerName, g_iHighestKillstreak);
			CRemoveTags(szText, 256);
			PrintToServer(szText);
		}
	}
}

void AddServerTagRat(char[] strTag) {
	ConVar cvarTags = FindConVar("sv_tags");
	char strServTags[128];
	GetConVarString(cvarTags, strServTags, 128);
	
	int iServTagsLen = strlen(strServTags);
	int iTagLen = strlen(strTag);
	
	bool bFoundTag = StrContains(strServTags, strTag, false) != -1;
	if(bFoundTag) {
		return;
	}
	
	// not enough space in sv_tags for the tag
	// +1 because of the comma needed for tag seperation
	if(iServTagsLen + iTagLen+1 > 127) {
		return;
	}
	
	strServTags[iServTagsLen] = ',';
	strcopy(strServTags[iServTagsLen + 1], 64, strTag);
	
	int iFlags = GetConVarFlags(cvarTags)
	SetConVarFlags(cvarTags, iFlags & ~FCVAR_NOTIFY);
	SetConVarString(cvarTags, strServTags, false, false);
	SetConVarFlags(cvarTags, iFlags);
}

stock void RemoveServerTagRat(char[] strTag) {
	ConVar cvarTags = FindConVar("sv_tags");
	char strServTags[128];
	GetConVarString(cvarTags, strServTags, 128);
	
	int iFoundTagAt = StrContains(strServTags, strTag, false);
	if(iFoundTagAt == -1) {
		return;
	}
	
	ReplaceString(strServTags, 128, strTag, "", false);
	ReplaceString(strServTags, 128, ",,", ",", false);
	
	int iFlags = GetConVarFlags(cvarTags)
	SetConVarFlags(cvarTags, iFlags & ~FCVAR_NOTIFY);
	SetConVarString(cvarTags, strServTags, false, false);
	SetConVarFlags(cvarTags, iFlags);
}

void Event_PluginStateChanged(ConVar cvar, char[] szPrev, char[] szNew) {
	if(StrEqual(szPrev, szNew))
		return;
		
	if(GetConVarBool(cvar)) {
		AddServerTagRat("killstreaks");
	} else {
		RemoveServerTagRat("killstreaks");
	}
}