/*
* Infinite-Jumping (Bunny Hop, Double Jump & Initial Jump)
* 
* Description:
* Lets user auto jump when holding down space. This plugin includes the DoubleJump plugin too. This plugin should work for all games.
* 
* Installation:
* Place infinite-jumping.smx into your '<moddir>/addons/sourcemod/plugins/' folder.
* Place plugin.infinite-jumping.cfg into your '<moddir>/cfg/sourcemod/' folder.
* 
*  
* Console Variables:
* // The amount of vertical boost to apply to double jumps.
* // -
* // Default: "290.0"
* sm_inf-jumping_boost_double "290.0"
* 
* // The amount of vertical boost at the first jump (initial jump), if 0 then the mod jump power/boost is used instead. Examples: CSS 290.0; HL2DM 190.0
* // -
* // Default: "0.0"
* sm_inf-jumping_boost_initial "0.0"
* 
* // Enables or Disables Infinite-Jumping
* // -
* // Default: "1"
* // Minimum: "0.000000"
* // Maximum: "1.000000"
* sm_inf-jumping_enabled "1"
* 
* // Needed admin level to be able to jump again in mid air. Leave this empty to allow it for all players, set it to 0 to disable this feature at all or use the SourceMod admin flags a,b,c etc.
* // -
* // Default: ""
* sm_inf-jumping_flags_double "0"
* 
* // Needed admin level to be able to jump automaticly again when on ground. Leave this empty to allow it for all players, set it to 0 to disable this feature at all or use the SourceMod admin flags a,b,c etc.
* // -
* // Default: ""
* sm_inf-jumping_flags_infinite ""
* 
* // Needed admin level to be able to perfect jump again in mid air. Leave this empty to allow it for all players, set it to 0 to disable this feature at all or use the SourceMod admin flags a,b,c etc.
* // -
* // Default: "0"
* sm_inf-jumping_flags_perfectdouble "0"
* 
* // The maximum number of re-jumps allowed while already jumping.
* // -
* // Default: "1"
* // Minimum: "0.000000"
* sm_inf-jumping_max_doublejumps "1"
* 
* // This is mainly for debug purposes. If 1 and a cvar is changed you can see what functions you are still able to use. If its 2 then you see also the jump boost of each jump.
* // -
* // Default: "0"
* // Minimum: "0.000000"
* sm_inf-jumping_notify "0"
* 
* 
* Changelog:
* v2.6.22
* Fixed sm_inf-jumping_flags_infinite not fully working.
* 
* v2.6.20
* Small fix that has to do with jump pads and fast elevators etc.
* Added, that if sm_inf-jumping_boost_initial is 0.0, then the mod intern jump power/boost is used.
* Set the standard value of sm_inf-jumping_boost_initial to 0.0.
* 
* v2.6.17
* Merged infinite-jumping with double jump plugin from paegus.
* Rewrite of some functions.
* Added some cvars see config file.
* 
* v1.2.3
* Added sm_infinite-jumping_flags.
* 
* v1.1.3
* Fixed in water and ladder bugs.
* 
* v1.0.0
* Public release
* 
* Thank you Berni, Manni, Mannis FUN House Community and SourceMod/AlliedModders-Team
* Thank you Fredd for the BunnyHop plugin & idea. Visit http://forums.alliedmods.net/showthread.php?t=67988
* Thank you NcB_Sav for the DoubleJump idea. Visit  http://forums.alliedmods.net/showthread.php?t=99228
* Thank you paegus for the DooubleJump plugin. Visit  http://forums.alliedmods.net/showthread.php?t=99874
*/

/*****************************************************************


I N C L U D E S,   O P T I O N S   A N D   V E R S I O N   N U M B E R 


*****************************************************************/
#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION "2.6.22"
#define PLUGIN_NAME "Infinite-Jumping"

/*****************************************************************


 Extracted functions of smlib:


*****************************************************************/
/*
* This function returns true if the client is at a ladder..
*
* @param client			Client index.
* @return				Returns true if the client is on a ladder other wise false.
*/
stock bool:Client_OnLadder(client){
	
	if (GetEntityMoveType(client) == MOVETYPE_LADDER){
		
		return true;
	}
	else{
		
		return false;
	}
}

#define WATER_LEVEL_NOT_IN_WATER 	0
#define WATER_LEVEL_FEET_IN_WATER 	1
#define WATER_LEVEL_WAIST_IN_WATER	2
#define WATER_LEVEL_HEAD_IN_WATER	3

stock Client_GetWaterLevel(client){
	
	return GetEntProp(client, Prop_Send, "m_nWaterLevel");
}

/**
* Gets the velocity of a entity.
*
* @param entity		Entity index.
* @param vel			An 3 dim array that holds the velocity.
* @noreturn
*/
stock Entity_GetVelocity(entity,Float:vel[3]){
	
	GetEntPropVector(entity, Prop_Data, "m_vecVelocity", vel);
}

/*****************************************************************


 D E F I N E S


*****************************************************************/

#define FLAG_LENGTH 11

/*****************************************************************


 G L O B A L   V A R I A B L E S


*****************************************************************/
//ConVar Handles:
new Handle:g_cvar_Version 				= INVALID_HANDLE;
new Handle:g_cvar_Enabled 				= INVALID_HANDLE;
new Handle:g_cvar_Flag_Infinite 		= INVALID_HANDLE;
new Handle:g_cvar_Flag_Double 			= INVALID_HANDLE;
new Handle:g_cvar_Flag_PerfectDouble 	= INVALID_HANDLE;
new Handle:g_cvar_Boost_Initial 		= INVALID_HANDLE;
new Handle:g_cvar_Boost_Double 			= INVALID_HANDLE;
new Handle:g_cvar_Max_DoubleJumps 		= INVALID_HANDLE;
new Handle:g_cvar_Notify				= INVALID_HANDLE;

//ConVars runtime saver:
new g_iPluginEnabled;
new String:g_szFlag_Infinite[FLAG_LENGTH];
new String:g_szFlag_Double[FLAG_LENGTH];
new String:g_szFlag_PerfectDouble[FLAG_LENGTH];
new Float:g_flBoost_Initial;
new Float:g_flBoost_Double;
new g_iMax_DoubleJumps;
new g_iNotify;

//For Clients:
new bool:g_bAllow_InfiniteJump[MAXPLAYERS+1];
new bool:g_bAllow_DoubleJump[MAXPLAYERS+1];
new bool:g_bAllow_PerfectDoubleJump[MAXPLAYERS+1];

new g_iDoubleJumps[MAXPLAYERS+1];

//new g_fLastFlags[MAXPLAYERS+1];
new g_fLastButtons[MAXPLAYERS+1];
/*****************************************************************


 P L U G I N   I N F O


*****************************************************************/

public Plugin:myinfo = 
{
	name = "Infinite-Jumping (Bunny Hop, Double Jump & Initial Jump)",
	author = "Chanz",
	description = "Lets user auto jump when holding down space. This plugin includes the DoubleJump plugin too.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1239361 OR http://www.mannisfunhouse.eu/ FOR orginal double jump plugin: http://forums.alliedmods.net/showthread.php?t=99874"
}

/*****************************************************************


 F O R W A R D S


*****************************************************************/

public OnPluginStart(){
	
	//Don't change version cvar!
	g_cvar_Version = CreateConVar("sm_infinite-jumping_version", PLUGIN_VERSION, "Infinite-Jumping (Bunny Hop, Double Jump & Initial Jump) Version", FCVAR_PLUGIN|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	SetConVarString(g_cvar_Version,PLUGIN_VERSION);
	
	g_cvar_Enabled				= CreateConVar("sm_inf-jumping_enabled", "1", "Enables or Disables Infinite-Jumping",FCVAR_PLUGIN|FCVAR_NOTIFY,true,0.0,true,1.0);
	g_cvar_Flag_Infinite		= CreateConVar("sm_inf-jumping_flags_infinite", "", "Needed admin level to be able to jump automaticly again when on ground. Leave this empty to allow it for all players, set it to \"0\" to disable this feature at all or use the SourceMod admin flags a,b,c etc.",FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_cvar_Flag_Double			= CreateConVar("sm_inf-jumping_flags_double", "", "Needed admin level to be able to jump again in mid air. Leave this empty to allow it for all players, set it to \"0\" to disable this feature at all or use the SourceMod admin flags a,b,c etc.",FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_cvar_Flag_PerfectDouble	= CreateConVar("sm_inf-jumping_flags_perfectdouble", "0", "Needed admin level to be able to perfect jump again in mid air. Leave this empty to allow it for all players, set it to \"0\" to disable this feature at all or use the SourceMod admin flags a,b,c etc.",FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_cvar_Boost_Initial 		= CreateConVar("sm_inf-jumping_boost_initial", "0.0","The amount of vertical boost at the first jump (initial jump), if 0 then the mod jump power/boost is used instead. Examples: CSS 290.0; HL2DM 190.0",FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_cvar_Boost_Double 		= CreateConVar("sm_inf-jumping_boost_double", "290.0","The amount of vertical boost to apply to double jumps.",FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_cvar_Max_DoubleJumps 		= CreateConVar("sm_inf-jumping_max_doublejumps", "1","The maximum number of re-jumps allowed while already jumping.",FCVAR_PLUGIN|FCVAR_NOTIFY,true,0.0);
	g_cvar_Notify 				= CreateConVar("sm_inf-jumping_notify", "0","This is mainly for debug purposes. If 1 and a cvar is changed you can see what functions you are still able to use. If its 2 then you see also the jump boost of each jump.",FCVAR_PLUGIN|FCVAR_NOTIFY,true,0.0,true,2.0);
	
	g_iPluginEnabled			= GetConVarInt(g_cvar_Enabled);
	GetConVarString				(g_cvar_Flag_Infinite,g_szFlag_Infinite,sizeof(g_szFlag_Infinite));
	GetConVarString				(g_cvar_Flag_Double,g_szFlag_Double,sizeof(g_szFlag_Double));
	GetConVarString				(g_cvar_Flag_PerfectDouble,g_szFlag_PerfectDouble,sizeof(g_szFlag_PerfectDouble));
	g_flBoost_Initial			= GetConVarFloat(g_cvar_Boost_Initial);
	g_flBoost_Double			= GetConVarFloat(g_cvar_Boost_Double);
	g_iMax_DoubleJumps			= GetConVarInt(g_cvar_Max_DoubleJumps);
	g_iNotify					= GetConVarInt(g_cvar_Notify);
	
	HookConVarChange(g_cvar_Enabled,			ConVarChange_Enable);
	HookConVarChange(g_cvar_Flag_Infinite,		ConVarChange_Flag_Infinite);
	HookConVarChange(g_cvar_Flag_Double,		ConVarChange_Flag_Double);
	HookConVarChange(g_cvar_Flag_PerfectDouble,	ConVarChange_Flag_PerfectDouble);
	HookConVarChange(g_cvar_Boost_Initial,		ConVarChange_Boost_Initial);
	HookConVarChange(g_cvar_Boost_Double,		ConVarChange_Boost_Double);
	HookConVarChange(g_cvar_Max_DoubleJumps,	ConVarChange_Max_DoubleJumps);
	HookConVarChange(g_cvar_Notify,				ConVarChange_Notify);
	
	AutoExecConfig(true,"plugin.infinite-jumping");
}

public OnConfigsExecuted(){
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		CheckJumpFlags(client);
	}
}

public OnClientConnected(client){
	
	g_bAllow_InfiniteJump[client] = false;
	g_bAllow_DoubleJump[client] = false;
	g_bAllow_PerfectDoubleJump[client] = false;
}

public OnClientPostAdminCheck(client){
	
	CheckJumpFlags(client);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon){
	
	if(g_iPluginEnabled == 0){
		//PrintToChat(client,"debug #-3");
		return Plugin_Continue;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client)){
		//PrintToChat(client,"debug #-2");
		return Plugin_Continue;
	}
	
	if(Client_GetWaterLevel(client) > WATER_LEVEL_FEET_IN_WATER){
		//PrintToChat(client,"debug #-1");
		return Plugin_Continue;
	}
	
	if(Client_OnLadder(client)){
		//PrintToChat(client,"debug #0");
		return Plugin_Continue;
	}
	
	new flags = GetEntityFlags(client);
	
	if(buttons & IN_JUMP){
		
		if(flags & FL_ONGROUND){
			
			OriginalJump(client);
		}
		else {
			
			if((g_flBoost_Initial == 0.0) && (g_bAllow_InfiniteJump[client])){
				
				buttons &= ~IN_JUMP;
			}
			
			decl Float:clientVel[3];
			Entity_GetVelocity(client,clientVel);
			
			if(g_iNotify >= 2){
				
				PrintToChat(client,"[%s] Your jump boost is: %f u/s upwards",PLUGIN_NAME,clientVel[2]);
			}
			
			if(g_bAllow_PerfectDoubleJump[client]){
				
				if(clientVel[2] < 0.0){
					
					ReJump(client);
				}
			}
			else if(!(g_fLastButtons[client] & IN_JUMP)){
				
				ReJump(client);
			}
		}
	}
	
	g_fLastButtons[client]	= buttons;
	
	return Plugin_Continue;
}

/*****************************************************************


 C O N V A R C H A N G E S


*****************************************************************/
	
public ConVarChange_Enable(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPluginEnabled = StringToInt(newVal);
}

public ConVarChange_Flag_Infinite(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	strcopy(g_szFlag_Infinite,sizeof(g_szFlag_Infinite),newVal);
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		CheckJumpFlags(client);
	}
}

public ConVarChange_Flag_Double(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	strcopy(g_szFlag_Double,sizeof(g_szFlag_Double),newVal);
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		CheckJumpFlags(client);
	}
}

public ConVarChange_Flag_PerfectDouble(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	strcopy(g_szFlag_PerfectDouble,sizeof(g_szFlag_PerfectDouble),newVal);
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		CheckJumpFlags(client);
	}
}

public ConVarChange_Boost_Initial(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_flBoost_Initial = StringToFloat(newVal);
}

public ConVarChange_Boost_Double(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_flBoost_Double = StringToFloat(newVal);
}

public ConVarChange_Max_DoubleJumps(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_iMax_DoubleJumps = StringToInt(newVal);
}

public ConVarChange_Notify(Handle:convar, const String:oldVal[], const String:newVal[]) {
	g_iNotify = StringToInt(newVal);
}

/*****************************************************************


 S T O C K S


*****************************************************************/

stock CheckJumpFlags(client){
	
	new AdminId:adminid = GetUserAdmin(client);
	new AdminFlag:flag;
	
	//g_bAllow_InfiniteJump:
	if(StrEqual(g_szFlag_Infinite,"0",false)){
		
		PrintToChatNotify(client,"You are NOT allowed to infinite jump now! (%s)",g_szFlag_Infinite);
		g_bAllow_InfiniteJump[client] = false;
	}
	else if(FindFlagByChar(g_szFlag_Infinite[0],flag)){
		
		if(adminid == INVALID_ADMIN_ID){
			
			PrintToChatNotify(client,"You are NOT allowed to infinite jump now! (%s)",g_szFlag_Infinite);
			g_bAllow_InfiniteJump[client] = false;
		}
		else if(GetAdminFlag(adminid,flag)){
			
			PrintToChatNotify(client,"You are allowed to infinite jump now! (%s)",g_szFlag_Infinite);
			g_bAllow_InfiniteJump[client] = true;
		}
		else {
			
			PrintToChatNotify(client,"You are NOT allowed to infinite jump now! (%s)",g_szFlag_Infinite);
			g_bAllow_InfiniteJump[client] = false;
		}
	}
	else {
		
		PrintToChatNotify(client,"You are allowed to infinite jump now! (%s)",g_szFlag_Infinite);
		g_bAllow_InfiniteJump[client] = true;
	}
	
	//g_bAllow_DoubleJump:
	if(StrEqual(g_szFlag_Double,"0",false)){
		
		PrintToChatNotify(client,"You are NOT allowed to double jump now! (%s)",g_szFlag_Double);
		g_bAllow_DoubleJump[client] = false;
	}
	else if(FindFlagByChar(g_szFlag_Double[0],flag)){
		
		if(adminid == INVALID_ADMIN_ID){
			
			PrintToChatNotify(client,"You are NOT allowed to double jump now! (%s)",g_szFlag_Double);
			g_bAllow_DoubleJump[client] = false;
		}
		else if(GetAdminFlag(adminid,flag)){
			
			PrintToChatNotify(client,"You are allowed to double jump now! (%s)",g_szFlag_Double);
			g_bAllow_DoubleJump[client] = true;
		}
		else {
			
			PrintToChatNotify(client,"You are NOT allowed to double jump now! (%s)",g_szFlag_Double);
			g_bAllow_DoubleJump[client] = false;
		}
	}
	else {
		
		PrintToChatNotify(client,"You are allowed to double jump now! (%s)",g_szFlag_Double);
		g_bAllow_DoubleJump[client] = true;
	}
	
	//g_bAllow_PerfectDoubleJump:
	if(StrEqual(g_szFlag_PerfectDouble,"0",false)){
		
		PrintToChatNotify(client,"You are NOT allowed to perfectdouble jump now! (%s)",g_szFlag_PerfectDouble);
		g_bAllow_PerfectDoubleJump[client] = false;
	}
	else if(FindFlagByChar(g_szFlag_PerfectDouble[0],flag)){
		
		if(adminid == INVALID_ADMIN_ID){
			
			PrintToChatNotify(client,"You are NOT allowed to perfectdouble jump now! (%s)",g_szFlag_PerfectDouble);
			g_bAllow_PerfectDoubleJump[client] = false;
		}
		else if(GetAdminFlag(adminid,flag)){
			
			PrintToChatNotify(client,"You are allowed to perfectdouble jump now! (%s)",g_szFlag_PerfectDouble);
			g_bAllow_PerfectDoubleJump[client] = true;
		}
		else {
			
			PrintToChatNotify(client,"You are NOT allowed to perfectdouble jump now! (%s)",g_szFlag_PerfectDouble);
			g_bAllow_PerfectDoubleJump[client] = false;
		}
	}
	else {
		
		PrintToChatNotify(client,"You are allowed to perfectdouble jump now! (%s)",g_szFlag_PerfectDouble);
		g_bAllow_PerfectDoubleJump[client] = true;
	}
}

stock PrintToChatNotify(client,const String:format[],any:...){
	
	decl String:vformat[1024];
	VFormat(vformat, sizeof(vformat), format, 3);
	
	if(g_iNotify >= 1){
		
		PrintToChat(client,vformat);
	}
}

stock OriginalJump(client) {
	
	if(g_bAllow_InfiniteJump[client]){
		
		if(g_flBoost_Initial != 0.0){
			
			decl Float:clientVel[3];
			Entity_GetVelocity(client,clientVel);
			clientVel[2] += g_flBoost_Initial;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientVel);
		}
	}
	
	g_iDoubleJumps[client] = 1;
}

stock ReJump(client) {
	
	if((g_bAllow_DoubleJump[client]) && (1 <= g_iDoubleJumps[client] <= g_iMax_DoubleJumps)){
		
		g_iDoubleJumps[client]++;
		
		decl Float:clientVel[3];
		Entity_GetVelocity(client,clientVel);
		
		clientVel[2] = g_flBoost_Double;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientVel);
	}
}





