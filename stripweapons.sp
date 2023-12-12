#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>

ConVar g_cvarStripWeapons = null;
ConVar g_cvarStripPistol = null;

public Plugin myinfo = {
	name = "Strip Weapons",
	author = "ratest",
	description = "Removes all weapons from a player when they spawn",
	version = "1.2",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("common.phrases.txt");
	
	g_cvarStripWeapons = CreateConVar("of_stripweapons", "0", "Remove all weapons from a player when they spawn");
	g_cvarStripPistol = CreateConVar("of_strippistol", "0", "Remove the pistol from a player when they spawn");
	
	// server tags
	g_cvarStripWeapons.AddChangeHook(Event_ChangePluginEnabled);

	AutoExecConfig(true, "stripweapons");
}

public void OF_OnPlayerSpawned(int iClient) {
	CreateTimer(0.0, StripWeapons, iClient); 
}

public Action StripWeapons(Handle timer, int iClient) {
	if(GetConVarBool(g_cvarStripPistol)) {
		TF2_RemoveWeaponSlot(iClient, 1);
		// no a-posing plz
		ClientCommand(iClient, "slot1");
	}
	if(GetConVarBool(g_cvarStripWeapons)) {
		TF2_RemoveAllWeapons(iClient);
	}
	
	return Plugin_Continue;
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
	
	SetConVarString(cvarTags, strServTags, false, false);
}

void RemoveServerTagRat(char[] strTag) {
	ConVar cvarTags = FindConVar("sv_tags");
	char strServTags[128];
	GetConVarString(cvarTags, strServTags, 128);
	
	int iServTagsLen = strlen(strServTags);
	int iTagLen = strlen(strTag);
	
	bool bFoundTag = StrContains(strServTags, strTag, false) != -1;
	if(!bFoundTag) {
		return;
	}
	
	strServTags[iServTagsLen - iTagLen] = '\0';
	
	SetConVarString(cvarTags, strServTags, false, false);
}

public void Event_ChangePluginEnabled(ConVar cvar, char[] strPrev, char[] strNew) {
	if(GetConVarBool(cvar)) {
		AddServerTagRat("stripweapons");
	} else {
		RemoveServerTagRat("stripweapons");
	}
}