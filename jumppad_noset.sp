#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>

ConVar g_cvarJumppadNoSet = null;
ConVar g_cvarJumppadForceMult = null;
ConVar g_cvarJumppadForceMultWidth = null;
ConVar g_cvarJumppadForceMultHeight = null;

public Plugin myinfo = {
	name = "Jumppad Mod",
	author = "ratest",
	description = "Modifies jumppads without the need to recompile maps",
	version = "1.4",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	g_cvarJumppadNoSet = CreateConVar("of_jumppad_only_add", "1", "Modifies all of the jumppads to add to the player's velocity instead of resetting it", 0, true, 0.0, true, 1.0);
	g_cvarJumppadForceMult = CreateConVar("of_jumppad_force_multiplier", "1", "", 0, true, -10.0, true, 10.0);
	g_cvarJumppadForceMultWidth = CreateConVar("of_jumppad_force_multiplier_width", "1", "", 0, true, -10.0, true, 10.0);
	g_cvarJumppadForceMultHeight = CreateConVar("of_jumppad_force_multiplier_height", "1", "", 0, true, -10.0, true, 10.0);
	
	HookEvent("teamplay_round_start", Event_RoundStart);
}

void ModJumppads(bool bOnlyAdd, float flForce, float flForceWidth, float flForceHeight) {
	for(int iEnt = 0; iEnt < GetMaxEntities(); ++iEnt) {
		if(!IsValidEdict(iEnt))
			continue;
		if(!IsValidEntity(iEnt))
			continue;
			
		char szClassname[128];
		GetEntityClassname(iEnt, szClassname, 128);
		if(StrEqual("ofd_trigger_jump", szClassname, false)) {
			if(bOnlyAdd)
				SetEntProp(iEnt, Prop_Send, "m_bNoCompensation", true, 1);
			
			float vecJPPos[3];
			float vecTargetPos[3];
			float vecDiff[3];
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vecJPPos);
			GetEntPropVector(iEnt, Prop_Send, "m_vecTarget", vecTargetPos);
			SubtractVectors(vecTargetPos, vecJPPos, vecDiff);
			vecDiff[0] *= flForceWidth;
			vecDiff[1] *= flForceWidth;
			vecDiff[2] *= flForceHeight;
			ScaleVector(vecDiff, flForce);
			AddVectors(vecJPPos, vecDiff, vecTargetPos);
			SetEntPropVector(iEnt, Prop_Send, "m_vecTarget", vecTargetPos);
		}
	}
}

/*public void OnMapStart() {
	ModJumppads(GetConVarBool(g_cvarJumppadNoSet), GetConVarFloat(g_cvarJumppadForceMult));
}*/

void Event_RoundStart(Event event, char[] szEventName, bool bDontBroadcast) {
	ModJumppads(GetConVarBool(g_cvarJumppadNoSet), GetConVarFloat(g_cvarJumppadForceMult), GetConVarFloat(g_cvarJumppadForceMultWidth), GetConVarFloat(g_cvarJumppadForceMultHeight));
}