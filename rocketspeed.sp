#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <openfortress>

ConVar g_cvarRocketSpeed = null;

public Plugin myinfo = {
	name = "Modifiable Rocket Speed",
	author = "ratest",
	description = "Modify the rocket projectile speed",
	version = "1.0",
	url = "https://github.com/TheRatest/openfortress-plugins"
};

public void OnPluginStart() {
	LoadTranslations("common.phrases.txt");
	
	g_cvarRocketSpeed = CreateConVar("of_rocketspeed", "1", "Rocket projectile speed multiplier");

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