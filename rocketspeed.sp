#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>

ConVar g_cvarRocketSpeed = null;

public Plugin myinfo = {
	name = "Modifiable Rocket Speed",
	author = "ratest",
	description = "Modify the rocket projectile speed",
	version = "1.1",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("common.phrases.txt");
	
	g_cvarRocketSpeed = CreateConVar("of_rocketspeed", "1", "Rocket projectile speed multiplier");
	
	// server tags
	g_cvarRocketSpeed.AddChangeHook(Event_ChangePluginEnabled);

	AutoExecConfig(true, "rocketspeed");
}

public void OnEntityCreated(int iEntity, const char[] strClassname) {
	if(StrEqual(strClassname, "tf_projectile_rocket")) {
		SDKHook(iEntity, SDKHook_SpawnPost, Projectile_RocketSpawnPost);
	}
}

public void Projectile_RocketSpawnPost(int iRocket) {
	float rSpeed = GetConVarFloat(g_cvarRocketSpeed);
	if(rSpeed == 1.0) {
		return;
	}
	if(IsValidEntity(iRocket))
	{
		int iClient = GetEntPropEnt(iRocket, Prop_Data, "m_hOwnerEntity");
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		if(iWeapon && IsValidEdict(iWeapon))
		{
			CreateTimer(0.0, ModSpeed, iRocket); 
		}
	}
}

public Action ModSpeed(Handle timer, int iRocket) {
	if(IsValidEntity(iRocket))
	{
		float vecVel[3];
		GetEntPropVector(iRocket, Prop_Data, "m_vecVelocity", vecVel);
		
		ScaleVector(vecVel, GetConVarFloat(g_cvarRocketSpeed));
				
		TeleportEntity(iRocket, NULL_VECTOR, NULL_VECTOR, vecVel);
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
	if(GetConVarFloat(cvar) == 1.0) {
		AddServerTagRat("rocketspeed");
	} else {
		RemoveServerTagRat("rocketspeed");
	}
}