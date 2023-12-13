#include <sourcemod>
#include <sdktools>
#include <openfortress>

bool bExistingEntities[2048];

public Plugin:myinfo = {
    name = "Entity Classname Logger",
    description = "Prints out a list of all current entities",
    author = "ratest",
    version = "1.0",
    url = "https://github.com/TheRatest/openfortress-plugins"
};

public OnPluginStart() 
{
    RegServerCmd("sm_printentities", Command_LogEntities, "Print out all entity classnames to the server console");
}

Action Command_LogEntities(int iArgs) 
{
	bool bPreviouslyMissing[2048];
	int iCount = 0;
   	for(int iEntity = 0; iEntity < 2048; ++iEntity) {
    	if(IsValidEdict(iEntity) && IsValidEntity(iEntity)) {
    		bPreviouslyMissing[iEntity] = !bExistingEntities[iEntity];
    		bExistingEntities[iEntity] = true;
    		++iCount;
    		char strClassname[128];
    		GetEntityClassname(iEntity, strClassname, 128);
    		PrintToServer("%i: %s", iEntity, strClassname);
    	} else {
    		bExistingEntities[iEntity] = false;
    	}
    }
    
    PrintToServer("Total valid entities: %i", iCount);
    
    PrintToServer("Previously missing entitites:");
    // for previously missing ents
    for(int iEntity = 0; iEntity < 2048; ++iEntity) {
    	if(bPreviouslyMissing[iEntity]) {
			char strClassname[128];
			GetEntityClassname(iEntity, strClassname, 128);
			PrintToServer("%i: %s", iEntity, strClassname);
    	}
    }
	return Plugin_Handled;
}