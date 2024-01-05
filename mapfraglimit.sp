#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>
#include <morecolors>

ConVar g_cvarMapFragLimitEnabled = null;
ConVar g_cvarMapFragLimitFilePath = null;
ConVar g_cvarMapFragLimitAnnounce = null;

bool g_bFirstEnable = true;

char g_szMapName[64][128];
int g_iMapFrags[64];
int g_iMapFragsCount = 0;
int g_iDynamicFragsUpdate = 0;
int g_iCurrentMapIndex = -1;

public Plugin myinfo = {
	name = "Map Dependent Frag Limit",
	author = "ratest",
	description = "Lets you assign a frag limit to a map",
	version = "1.3",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("ratsplugins.phrases.txt");
	
	g_cvarMapFragLimitEnabled = CreateConVar("of_mapfraglimit_enabled", "0", "Enable map dependent frag limit");
	g_cvarMapFragLimitAnnounce = CreateConVar("of_mapfraglimit_announce", "1", "Announce the frag limit for the map in chat");
	g_cvarMapFragLimitFilePath = CreateConVar("of_mapfraglimit_file", "cfg/sourcemod/mapfraglimit-maps.cfg", "The 2nd config file path");
	
	RegAdminCmd("of_mapfraglimit_reload", Command_MapFragLimitReload, ADMFLAG_KICK, "Reload the 2nd config for this plugin");
	
	// server tags
	g_cvarMapFragLimitEnabled.AddChangeHook(Event_ChangeMapFragLimitEnabled);
	
	HookEvent("teamplay_round_start", Event_RoundStart);

	AutoExecConfig(true, "mapfraglimit");
	LoadMapFrags();
}

Action Command_MapFragLimitReload(int iClient, int iArgs) {
	LoadMapFrags();
	ReplyToCommand(iClient, "[MapFragLimit] 2nd config file reloaded!");
	return Plugin_Handled;
}

void LoadMapFrags() {
	g_iMapFragsCount = 0;
	char szFilePath[256];
	char szFullFilePath[512];
	GetConVarString(g_cvarMapFragLimitFilePath, szFilePath, 512);
	BuildPath(Path_SM, szFullFilePath, 512, "../../%s", szFilePath);
	File fConfig2 = OpenFile(szFullFilePath, "r");
	if(fConfig2 == INVALID_HANDLE) {
		File fTemp = OpenFile(szFullFilePath, "w");
		fTemp.Close();
		fConfig2 = OpenFile(szFullFilePath, "r");
	}
	if(fConfig2 == INVALID_HANDLE) {
		ThrowError("Couldn't open 2nd config for mapfraglimit! Path: %s", szFullFilePath);
	}
	
	char szLineBuffer[140];
	while(fConfig2.ReadLine(szLineBuffer, 256)) {
		char szBuffers[2][128];
		ExplodeString(szLineBuffer, " ", szBuffers, 2, 128, false);
		char szMapName[128];
		char szMapFrags[12];

		strcopy(szMapName, 128, szBuffers[0]);
		strcopy(szMapFrags, 12, szBuffers[1]);
		
		int iMapFrags = StringToInt(szMapFrags);
		
		strcopy(g_szMapName[g_iMapFragsCount], 128, szMapName);
		g_iMapFrags[g_iMapFragsCount] = iMapFrags;
		++g_iMapFragsCount;
	}
	
	fConfig2.Close();
}

public void OnMapStart() {
	g_iDynamicFragsUpdate = 0;
	g_iCurrentMapIndex = -1;
	if(GetConVarBool(g_cvarMapFragLimitEnabled)) {
		ChangeMapFragLimit();
	}
}

void ChangeMapFragLimit() {	
	char szMapName[128];
	GetCurrentMap(szMapName, 128);
	
	ConVar cvarFragLimit = FindConVar("mp_fraglimit");
	ConVar cvarDynamicFragsBase = FindConVar("sm_dynamicfrags_basefrags");
	
	for(int i = 0; i < g_iMapFragsCount; ++i) {
		if(StrEqual(szMapName, g_szMapName[i])) {
			g_iDynamicFragsUpdate = g_iMapFrags[i];
			if(cvarDynamicFragsBase != INVALID_HANDLE) {
				SetConVarInt(cvarDynamicFragsBase, g_iMapFrags[i], true, false);
			}
			
			g_iCurrentMapIndex = i;
			SetConVarInt(cvarFragLimit, g_iMapFrags[i], true, false);
			break;
		}
	}
}

public void OnAllPluginsLoaded() {
	if(g_iDynamicFragsUpdate != 0) {
		ConVar cvarDynamicFragsBase = FindConVar("sm_dynamicfrags_basefrags");
		
		if(cvarDynamicFragsBase != INVALID_HANDLE) {
			SetConVarInt(cvarDynamicFragsBase, g_iDynamicFragsUpdate, true, false);
		}
	}
}

public void Event_RoundStart(Event event, char[] szEventName, bool bDontBroadcast) {
	if(GameRules_GetProp("m_bInWaitingForPlayers"))
		return;
	
	if(g_iCurrentMapIndex == -1)
		return;
	
	if(!GetConVarBool(g_cvarMapFragLimitAnnounce)) {
		return;
	}
	
	if(FindConVar("sm_dynamicfrags_multiplier") != INVALID_HANDLE) {
		CPrintToChatAll("%t %t", "Rat CommandPrefix", "Rat FragLimitAnnounce DynamicFrags", g_szMapName[g_iCurrentMapIndex], g_iMapFrags[g_iCurrentMapIndex], GetConVarInt(FindConVar("sm_dynamicfrags_multiplier")));
	} else {
		CPrintToChatAll("%t %t", "Rat CommandPrefix", "Rat FragLimitAnnounce", g_szMapName[g_iCurrentMapIndex], g_iMapFrags[g_iCurrentMapIndex]);
	}
	PrintToServer("Frag limit for %s: %i", g_szMapName[g_iCurrentMapIndex], g_iMapFrags[g_iCurrentMapIndex]);
	
	return;
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

void RemoveServerTagRat(char[] strTag) {
	ConVar cvarTags = FindConVar("sv_tags");
	char strServTags[128];
	GetConVarString(cvarTags, strServTags, 128);
	
	bool bFoundTag = StrContains(strServTags, strTag, false) != -1;
	if(!bFoundTag) {
		return;
	}
	
	ReplaceString(strServTags, 128, strTag, "", false);
	ReplaceString(strServTags, 128, ",,", ",", false);
	
	int iFlags = GetConVarFlags(cvarTags)
	SetConVarFlags(cvarTags, iFlags & ~FCVAR_NOTIFY);
	SetConVarString(cvarTags, strServTags, false, false);
	SetConVarFlags(cvarTags, iFlags);
}

public void Event_ChangeMapFragLimitEnabled(ConVar cvar, char[] strPrev, char[] strNew) {
	if(GetConVarBool(cvar)) {
		AddServerTagRat("mapfraglimit");
		// so that it doesnt trigger twice when the plugin first loads
		if(g_bFirstEnable) {
			g_bFirstEnable = false;
		} else {
			ChangeMapFragLimit();
		}
	} else {
		RemoveServerTagRat("mapfraglimit");
	}
}