#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>

ConVar g_cvarJumppadNoSet = null;

public Plugin myinfo = {
	name = "Don't make the jumppads slow me down!",
	author = "ratest",
	description = "Modifies all of the jumppads to add to the player's velocity instead of resetting it",
	version = "1.2",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("ratsplugins.phrases.txt");
	
	g_cvarJumppadNoSet = CreateConVar("of_jumppad_only_add", "1", "Modifies all of the jumppads to add to the player's velocity instead of resetting it");
	
	HookEvent("teamplay_round_start", Event_RoundStart);
}

public void OnMapStart() {
	if(!GetConVarBool(g_cvarJumppadNoSet))
		return;
		
	for(int iEnt = 0; iEnt < GetMaxEntities(); ++iEnt) {
		if(!IsValidEdict(iEnt))
			continue;
		if(!IsValidEntity(iEnt))
			continue;
			
		char szClassname[128];
		GetEntityClassname(iEnt, szClassname, 128);
		if(StrEqual("ofd_trigger_jump", szClassname, false)) {
			SetEntProp(iEnt, Prop_Send, "m_bNoCompensation", 1, 1);
		}
	}
}

void Event_RoundStart(Event event, char[] szEventName, bool bDontBroadcast) {
	if(!GetConVarBool(g_cvarJumppadNoSet))
		return;

	for(int iEnt = 0; iEnt < GetMaxEntities(); ++iEnt) {
		if(!IsValidEdict(iEnt))
			continue;
		if(!IsValidEntity(iEnt))
			continue;
			
		char szClassname[128];
		GetEntityClassname(iEnt, szClassname, 128);
		if(StrEqual("ofd_trigger_jump", szClassname, false)) {
			SetEntProp(iEnt, Prop_Send, "m_bNoCompensation", 1, 1);
		}
	}
}