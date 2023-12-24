#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>
#include <morecolors>

ConVar g_cvarMapFragLimitEnabled = null;
ConVar g_cvarMapFragLimitFilePath = null;
ConVar g_cvarMapFragLimitAnnounce = null;
ConVar g_cvarMapFragLimitAnnounceTime = null;

bool g_bFirstEnable = true;

char g_szMapName[64][128];
int g_iMapFrags[64];
int g_iMapFragsCount = 0;

public Plugin myinfo = {
	name = "Map Dependent Frag Limit",
	author = "ratest",
	description = "Lets you assign a frag limit to a map",
	version = "1.1",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("ratsplugins.phrases.txt");
	
	g_cvarMapFragLimitEnabled = CreateConVar("of_mapfraglimit_enabled", "0", "Enable map dependent frag limit");
	g_cvarMapFragLimitAnnounce = CreateConVar("of_mapfraglimit_announce", "1", "Announce the frag limit for the map in chat");
	g_cvarMapFragLimitAnnounceTime = CreateConVar("of_mapfraglimit_announce_delay", "30", "How many seconds to wait before announcing the change");
	g_cvarMapFragLimitFilePath = CreateConVar("of_mapfraglimit_file", "cfg/sourcemod/mapfraglimit-maps.cfg", "The 2nd config file path");
	
	RegAdminCmd("of_mapfraglimit_reload", Command_MapFragLimitReload, ADMFLAG_KICK, "Reload the 2nd config for this plugin");
	
	// server tags
	g_cvarMapFragLimitEnabled.AddChangeHook(Event_ChangeMapFragLimitEnabled);

	AutoExecConfig(true, "mapfraglimit");
	LoadMapFrags();
}

Action Command_MapFragLimitReload(int iClient, int iArgs) {
	LoadMapFrags();
	return Plugin_Continue;
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
	ChangeMapFragLimit();
}

void ChangeMapFragLimit() {
	char szMapName[128];
	GetCurrentMap(szMapName, 128);
	
	ConVar cvarFragLimit = FindConVar("mp_fraglimit");
	
	for(int i = 0; i < g_iMapFragsCount; ++i) {
		if(StrEqual(szMapName, g_szMapName[i])) {
			SetConVarInt(cvarFragLimit, g_iMapFrags[i], true, false);
			CreateTimer(GetConVarFloat(g_cvarMapFragLimitAnnounceTime), FragLimitDelayedAnnounce, i);
			break;
		}
	}
}

public Action FragLimitDelayedAnnounce(Handle hTimer, int iMapIndex) {
	if(!GetConVarBool(g_cvarMapFragLimitAnnounce)) {
		return Plugin_Handled;
	}
	
	CPrintToChatAll("%t %t", "Rat CommandPrefix", "Rat FragLimitAnnounce", g_szMapName[iMapIndex], g_iMapFrags[iMapIndex]);
	
	return Plugin_Handled;
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