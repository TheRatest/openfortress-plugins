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
	version = "1.1",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("common.phrases.txt");
	
	g_cvarStripWeapons = CreateConVar("of_stripweapons", "0", "Remove all weapons from a player when they spawn");
	g_cvarStripPistol = CreateConVar("of_strippistol", "0", "Remove the pistol from a player when they spawn");

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