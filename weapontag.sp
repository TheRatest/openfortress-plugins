#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>
#include <morecolors>

ConVar g_cvarWeaponTagEnabled = null;
ConVar g_cvarWeaponTagFragsToUntag = null;
ConVar g_cvarWeaponTagCanTagWhileTagged = null;
ConVar g_cvarWeaponTagDebug = null;
ConVar g_cvarWeaponTagStrip = null;
ConVar g_cvarWeaponTagRefreshWeapon = null;
ConVar g_cvarWeaponTagDistort = null;
ConVar g_cvarWeaponTagServerTag = null;
ConVar g_cvarWeaponTagTintWeapon = null;
//ConVar g_cvarWeaponTagUntagMode = null;

bool taggedPlayers[MAXPLAYERS];
int taggedFragsPlayers[MAXPLAYERS];
char taggedPlayersWeapons[MAXPLAYERS][64];

public Plugin myinfo = {
	name = "Weapon Tag",
	author = "ratest",
	description = "Fun (hopefully) gamemode that forces people to use the weapon you kill them with.",
	version = "1.5",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("ratsplugins.phrases.txt");
	
	g_cvarWeaponTagEnabled = CreateConVar("of_weapontag_enabled", "0", "Enable the gamemode that forces people to use the weapon you kill them with");
	g_cvarWeaponTagFragsToUntag = CreateConVar("of_weapontag_frags", "1", "Amount of frags required to untag someone after they've been tagged");
	g_cvarWeaponTagCanTagWhileTagged = CreateConVar("of_weapontag_can_tag_while_tagged", "0", "Whether can tagged players tag other players");
	g_cvarWeaponTagDebug = CreateConVar("of_weapontag_debug", "0", "An extra option to clutter up the server console");
	g_cvarWeaponTagStrip = CreateConVar("of_weapontag_stripweapons", "1", "Remove other weapons on spawn if tagged");
	g_cvarWeaponTagRefreshWeapon = CreateConVar("of_weapontag_refresh_weapon", "1", "If someone that's already tagged dies again, their forced weapon gets updated to the one they were killed with");
	g_cvarWeaponTagDistort = CreateConVar("of_weapontag_distort", "1", "Change a tagged player's render fx to look a bit like a hologram");
	g_cvarWeaponTagTintWeapon = CreateConVar("of_weapontag_tint_weapon", "1", "Change the tagged player's weapon color to red");
	g_cvarWeaponTagServerTag = CreateConVar("of_weapontag_servertag", "1", "Apply a 'weapontag' tag to the server?");
	
	// for server tags
	g_cvarWeaponTagEnabled.AddChangeHook(Event_ChangeWeaponTagEnabled);
	g_cvarWeaponTagEnabled.AddChangeHook(Event_ChangeServerTagsEnabled);
	
	// Currently not used anywhere, maybe i'll implement it at some point
	// g_cvarWeaponTagUntagMode = CreateConVar("of_weapontag_untag_mode", "1", "How to untag someone\n	1 - Allow all other weapons\n	2 - Give them a new random weapon and force them to use that weapon only");

	AutoExecConfig(true, "weapontag");
	HookEvent("player_death", Event_PlayerDeath);
	
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	for(int i = 1; i <= MaxClients; ++i) {
		taggedPlayers[i] = false;
		taggedFragsPlayers[i] = 0;
		taggedPlayersWeapons[i] = "";
		if(IsClientInGame(i)) {
			SDKHook(i, SDKHook_WeaponSwitch, Event_WeaponSwitch);
			if(bDebug) {
				PrintToServer("Hooked client %i's weapon switch", i);
			}
		}
	}
}

public void OnClientPutInServer(int iClient) {
	SDKHook(iClient, SDKHook_WeaponSwitch, Event_WeaponSwitch);
	
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	if(bDebug) {
		PrintToServer("Hooked client %i's weapon switch", iClient);
	}
}

public void OF_OnPlayerSpawned(int iClient) {
	bool bWeaponTagEnabled = GetConVarBool(g_cvarWeaponTagEnabled);
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	bool bStrip = GetConVarBool(g_cvarWeaponTagStrip);
	bool bDistortPlayer = GetConVarBool(g_cvarWeaponTagDistort);
	bool bTintWeapon = GetConVarBool(g_cvarWeaponTagTintWeapon);
	
	if(!bWeaponTagEnabled) {
		return;
	}
	
	if(taggedPlayers[iClient]) {
		if(bStrip) {
			TF2_RemoveAllWeapons(iClient);
		}
		
		int iEntity = GivePlayerItem(iClient, taggedPlayersWeapons[iClient]);
		if(iEntity == -1 || iClient == -1) {
			if(bDebug) {
				PrintToServer("Failed to give client %i a %s", iClient, taggedPlayersWeapons[iClient]);
			}
			return;
		}
		AcceptEntityInput(iEntity, "use", iClient, iClient);
		
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEntity);
		
		if(bDistortPlayer) {
			if(bDebug) {
				PrintToServer("Creating color timers for client %i", iClient);	
			}
			SetEntityRenderFx(iClient, RENDERFX_DISTORT);
		}
		
		if(bTintWeapon) {
			CreateTimer(0.5, ColorWeaponDelayed, iClient);
		}
		
		if(bDebug) {
			PrintToServer("Giving client %i a %s", iClient, taggedPlayersWeapons[iClient]);
		}
	}
}

Action ColorWeaponDelayed(Handle hTimer, int iClient) {
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	
	int iWeapon = -1;
	char strClassname[128];
	for(int i = 0; i < 2048; ++i) {
		if(!IsValidEdict(i) || !IsValidEntity(i)) {
			continue;
		}
		if(!HasEntProp(i, Prop_Send, "m_hOwnerEntity")) {
			continue;
		}
		GetEdictClassname(i, strClassname, 128);
		if(GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == iClient && StrEqual(strClassname, taggedPlayersWeapons[iClient], false)) {
			iWeapon = i;
			break;
		}
	}
	
	if(iWeapon == -1) {
		if(bDebug) {
			PrintToServer("Couldn't find client %i's weapon", iClient);
		}
		return Plugin_Continue;
	}
	
	SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iWeapon, 255, 63, 63, 255);
	
	if(bDebug) {
		PrintToServer("Colored client %i's weapon", iClient);
	}
	
	return Plugin_Continue;
}

Action Event_WeaponSwitch(int iClient, int iWeapon) {
	if(!taggedPlayers[iClient] || iWeapon < 0) {
		return Plugin_Continue;
	}
	
	char strWeaponClassname[64];
	GetEdictClassname(iWeapon, strWeaponClassname, 64);
	
	if(!StrEqual(strWeaponClassname, taggedPlayersWeapons[iClient], false)) {
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

// Unfinished picking up weapons from the floor
/*public Action Event_StartTouch(int iEntity, int iOther) {
	char strWeaponClassname[64];
	GetEdictClassname(iOther, strWeaponClassname, 64);
	
	if(!StrContains(strWeaponClassname, "weapon_", false)) {
		return Plugin_Continue;
	}
	
	
	
	return Plugin_Continue;
}*/

void Event_PlayerDeath(Event event, const char[] evName, bool dontBroadcast) {
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	
	int iVictimId = GetEventInt(event, "userid");
	int iAttackerId = GetEventInt(event, "attacker");
	
	if(iVictimId == iAttackerId) {
		if(bDebug) {
			PrintToServer("Victim is attacker, returning");
		}
		return;
	}
	
	if(bDebug) {
		PrintToServer("Victim id: %i\nAttacker id: %i", iVictimId, iAttackerId);
	}
	
	if(iVictimId == 0) {
		if(bDebug) {
			PrintToServer("Invalid victim id, returning");
		}
		return;
	}
	
	if(iAttackerId == 0) {
		if(bDebug) {
			PrintToServer("Invalid attacker id, returning");
		}
		return;
	}
	
	int iVictim = GetClientOfUserId(iVictimId);
	int iAttacker = GetClientOfUserId(iAttackerId);
	
	if(iVictim == 0) {
		if(bDebug) {
			PrintToServer("Invalid victim, returning");
		}
		return;
	}
	
	bool bWeaponTagEnabled = GetConVarBool(g_cvarWeaponTagEnabled);
	bool bWeaponTagCanTagWhileTagged = GetConVarBool(g_cvarWeaponTagCanTagWhileTagged);
	bool bRefreshWeapon = GetConVarBool(g_cvarWeaponTagRefreshWeapon);
	
	if(!bWeaponTagEnabled) {
		if(bDebug) {
			PrintToServer("Weapon tag not enabled, resetting stats");
		}
		UntagPlayer(iVictim);
		UntagPlayer(iAttacker);
		return;
	}
	
	if(!taggedPlayers[iVictim]) {
		if(!taggedPlayers[iAttacker] || (taggedPlayers[iAttacker] && bWeaponTagCanTagWhileTagged)) {
			TagPlayer(iVictim, iAttacker)
			
			if(bDebug) {
				PrintToServer("Tagged client %i", iVictim);
			}
		}
	} else {
		if(bRefreshWeapon) {
			RefreshWeapon(iVictim, iAttacker);
			if(bDebug) {
				PrintToServer("Refreshing %i's weapon", iVictim);
			}
		}
	}
	
	if(taggedPlayers[iAttacker]) {
		taggedFragsPlayers[iAttacker]++;
		if(taggedFragsPlayers[iAttacker] >= GetConVarInt(g_cvarWeaponTagFragsToUntag)) {
			UntagPlayer(iAttacker);
			if(bDebug) {
				PrintToServer("Untagged client %i", iAttacker);
			}
		}
	}
}

void TagPlayer(int iClient, int iAttacker) {
	taggedPlayers[iClient] = true;
	taggedFragsPlayers[iClient] = GetConVarInt(g_cvarWeaponTagFragsToUntag);
	RefreshWeapon(iClient, iAttacker);
}

void RefreshWeapon(int iClient, int iAttacker) {
	if(iAttacker != 0) {
		GetClientWeapon(iAttacker, taggedPlayersWeapons[iClient], 64);
	} else {
		taggedPlayersWeapons[iClient] = "tf_weapon_rocketlauncher_dm";
	}
}

void UntagPlayer(int iClient) {
	char strForcedWeaponClassname[128];
	taggedFragsPlayers[iClient] = 0;
	taggedPlayers[iClient] = false;
	strcopy(strForcedWeaponClassname, 128, taggedPlayersWeapons[iClient]);
	taggedPlayersWeapons[iClient] = "";

	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	bool bDistortPlayer = GetConVarBool(g_cvarWeaponTagDistort);
	
	if (bDistortPlayer) {
		SetEntityRenderFx(iClient, RENDERFX_NONE);
	}
	
	int iWeapon = -1;
	for(int i = 0; i < 2048; ++i) {
		if(!IsValidEdict(i) || !IsValidEntity(i)) {
			continue;
		}
		if(!HasEntProp(i, Prop_Send, "m_hOwnerEntity")) {
			continue;
		}
		char strClassname[128];
		GetEdictClassname(i, strClassname, 128);
		if(GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity") == iClient && StrEqual(strClassname, strForcedWeaponClassname, false)) {
			SetEntityRenderMode(i, RENDER_TRANSCOLOR);
			SetEntityRenderColor(i, 255, 255, 255, 255);
			iWeapon = i;
			break;
		}
	}
	
	if(iWeapon == -1) {
		if(bDebug) {
			PrintToServer("Couldn't find client %i's weapon to uncolor it", iClient);
		}
		return;
	}
}

void AddServerTagRat(char[] strTag) {
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	if(bDebug) {
		PrintToServer("Changing server tags...");
	}
	ConVar cvarTags = FindConVar("sv_tags");
	char strServTags[128];
	GetConVarString(cvarTags, strServTags, 128);
	
	if(bDebug) {
		PrintToServer("Prev: %s", strServTags);
	}
	
	int iServTagsLen = strlen(strServTags);
	int iTagLen = strlen(strTag);
	
	bool bFoundTag = StrContains(strServTags, strTag, false) != -1;
	if(bFoundTag) {
		if(bDebug) {
			PrintToServer("Already found the server tag while adding it");
		}
		return;
	}
	
	// not enough space in sv_tags for the tag
	// +1 because of the comma needed for tag seperation
	if(iServTagsLen + iTagLen+1 > 127) {
		if(bDebug) {
			PrintToServer("Tag too long");
		}
		return;
	}
	
	strServTags[iServTagsLen] = ',';
	strcopy(strServTags[iServTagsLen + 1], 64, strTag);
	
	if(bDebug) {
		PrintToServer("New: %s", strServTags);
	}
	
	int iFlags = GetConVarFlags(cvarTags)
	SetConVarFlags(cvarTags, iFlags & ~FCVAR_NOTIFY);
	SetConVarString(cvarTags, strServTags, false, false);
	SetConVarFlags(cvarTags, iFlags);
}

void RemoveServerTagRat(char[] strTag) {
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	if(bDebug) {
		PrintToServer("Changing server tags...");
	}
	ConVar cvarTags = FindConVar("sv_tags");
	char strServTags[128];
	GetConVarString(cvarTags, strServTags, 128);
	
	if(bDebug) {
		PrintToServer("Prev: %s", strServTags);
	}
	
	//int iServTagsLen = strlen(strServTags);
	//int iTagLen = strlen(strTag);
	
	bool bFoundTag = StrContains(strServTags, strTag, false) != -1;
	if(!bFoundTag) {
		if(bDebug) {
			PrintToServer("Haven't found the server tag to remove");
		}
		return;
	}
	
	ReplaceString(strServTags, 128, strTag, "", false);
	ReplaceString(strServTags, 128, ",,", ",", false);
	
	int iFlags = GetConVarFlags(cvarTags)
	SetConVarFlags(cvarTags, iFlags & ~FCVAR_NOTIFY);
	SetConVarString(cvarTags, strServTags, false, false);
	SetConVarFlags(cvarTags, iFlags);
}

void Event_ChangeWeaponTagEnabled(ConVar cvar, char[] strPrev, char[] strNew) {
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	bool bTagsEnabled = GetConVarBool(g_cvarWeaponTagServerTag);
	if(StrEqual(strPrev, strNew)) {
		return;
	}
	if(bDebug) {
		PrintToServer("Changed weapontag state");
	}
	if(bTagsEnabled) {
		if(GetConVarBool(cvar)) {
			AddServerTagRat("weapontag");
			CPrintToChatAll("%t %t", "Rat CommandPrefix", "Rat WeaponTagEnabled");
		} else {
			RemoveServerTagRat("weapontag");
			CPrintToChatAll("%t %t", "Rat CommandPrefix", "Rat WeaponTagDisabled");
		}
	}
}

void Event_ChangeServerTagsEnabled(ConVar cvar, char[] strPrev, char[] strNew) {
	bool bDebug = GetConVarBool(g_cvarWeaponTagDebug);
	bool bTagsEnabled = GetConVarBool(g_cvarWeaponTagServerTag);
	bool bWeptagEnabled = GetConVarBool(g_cvarWeaponTagEnabled);
	if(StrEqual(strPrev, strNew)) {
		return;
	}
	if(bDebug) {
		PrintToServer("Changing server tags state");
	}
	if(bTagsEnabled) {
		if(bWeptagEnabled) {
			AddServerTagRat("weapontag");
		}
	} else {
		RemoveServerTagRat("weapontag");
	}
}
