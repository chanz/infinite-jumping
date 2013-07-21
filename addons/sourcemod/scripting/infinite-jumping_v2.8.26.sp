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
* For more information see: http://forums.alliedmods.net/showthread.php?p=1239361 OR http://www.mannisfunhouse.eu/
*/

/*****************************************************************


C O M P I L E   O P T I O N S


*****************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1

/*****************************************************************


P L U G I N   I N F O


*****************************************************************/
#define PLUGIN_NAME				"Infinite Jumping"
#define PLUGIN_TAG				"sm"
#define PLUGIN_AUTHOR			"Chanz"
#define PLUGIN_DESCRIPTION		"Lets user auto jump when holding down space. This plugin includes the DoubleJump plugin too."
#define PLUGIN_VERSION 			"2.8.26"
#define PLUGIN_URL				"http://forums.alliedmods.net/showthread.php?p=1239361 OR http://www.mannisfunhouse.eu/"


public Plugin:myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

/*****************************************************************


P L U G I N   I N C L U D E S


*****************************************************************/
#include <sourcemod>
#include <sdktools>
#undef REQUIRE_EXTENSIONS
#include <sdkhooks>
#include <smlib>
#include <smlib/pluginmanager>

/*****************************************************************


P L U G I N   D E F I N E S


*****************************************************************/


/*****************************************************************


G L O B A L   V A R S


*****************************************************************/
//Extension Loadstate
new bool:g_bExt_SDKHook = false;

//ConVar Handles:
new Handle:g_cvarFlag_Infinite 					= INVALID_HANDLE;
new Handle:g_cvarFlag_Double 					= INVALID_HANDLE;
new Handle:g_cvarFlag_PerfectDouble 			= INVALID_HANDLE;
new Handle:g_cvarBoost_Initial 					= INVALID_HANDLE;
new Handle:g_cvarBoost_Double 					= INVALID_HANDLE;
new Handle:g_cvarMax_DoubleJumps 				= INVALID_HANDLE;
new Handle:g_cvarOr_Stamina						= INVALID_HANDLE;
new Handle:g_cvarOr_SlowDownOnHurt 				= INVALID_HANDLE;
new Handle:g_cvarBoost_Forward					= INVALID_HANDLE;
new Handle:g_cvarBoost_Forward_WSAD				= INVALID_HANDLE;	

//ConVars runtime saver:
new String:g_szPlugin_Flag_Infinite[11] 		= "";
new String:g_szPlugin_Flag_Double[11] 			= "";
new String:g_szPlugin_Flag_PerfectDouble[11] 	= "";
new Float:g_flPlugin_Boost_Initial 				= 0.0;
new Float:g_flPlugin_Boost_Double 				= 0.0;
new g_iPlugin_Max_DoubleJumps 					= 0;
new Float:g_flPlugin_Or_Stamina 				= 0.0;
new Float:g_flPlugin_Or_SlowDownOnHurt			= 1.0;
new Float:g_flPlugin_Boost_Forward				= 0.0;
new g_iPlugin_Boost_Forward_WSAD				= 1;


//For Clients:
new bool:g_bAllow_InfiniteJump[MAXPLAYERS+1];
new bool:g_bAllow_DoubleJump[MAXPLAYERS+1];
new bool:g_bAllow_PerfectDoubleJump[MAXPLAYERS+1];

new g_iDoubleJumps[MAXPLAYERS+1];
new g_fLastButtons[MAXPLAYERS+1];

//Offsets
new g_Offset_m_flStamina = -1;
new g_Offset_m_flVelocityModifier = -1;

/*****************************************************************


F O R W A R D   P U B L I C S


*****************************************************************/
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max){
	
	MarkNativeAsOptional("SDKHook");
	return APLRes_Success;
}

public OnPluginStart() {
	
	//Init for smlib
	SMLib_OnPluginStart(PLUGIN_NAME,PLUGIN_TAG,PLUGIN_VERSION,PLUGIN_AUTHOR,PLUGIN_DESCRIPTION,PLUGIN_URL);
	
	//ConVars
	g_cvarFlag_Infinite				= CreateConVarEx("flags_infinite", 			"", 		"Automatic rejump: \"\" = everyone can; \"0\" = noone can; \"<adminflag>\" = admin with this flag can (a,b,c,d,...) see: addons/sourcemod/configs/admin_levels.cfg for more info.",FCVAR_PLUGIN);
	g_cvarFlag_Double				= CreateConVarEx("flags_double", 			"0", 		"Rejump in mid air: \"\" = everyone can; \"0\" = noone can; \"<adminflag>\" = admin with this flag can (a,b,c,d,...) see: addons/sourcemod/configs/admin_levels.cfg for more info.",FCVAR_PLUGIN);
	g_cvarFlag_PerfectDouble		= CreateConVarEx("flags_perfectdouble", 	"0", 		"Jump automatic in mid air when jump is pressed: \"\" = everyone can; \"0\" = noone can; \"<adminflag>\" = admin with this flag can (a,b,c,d,...) see: addons/sourcemod/configs/admin_levels.cfg for more info.",FCVAR_PLUGIN);
	g_cvarBoost_Initial 			= CreateConVarEx("boost_initial", 			"0.0",		"If you wish to jump higher or lower, then change this value. 0.0 = normal jump height.",FCVAR_PLUGIN);
	g_cvarBoost_Double 				= CreateConVarEx("boost_double", 			"290.0",	"The amount of vertical boost in units per second to apply when mid air double jumping.",FCVAR_PLUGIN);
	g_cvarMax_DoubleJumps 			= CreateConVarEx("max_doublejumps", 		"1",		"The maximum number of re-jumps allowed while in mid air.",FCVAR_PLUGIN,true,0.0);
	g_cvarOr_Stamina				= CreateConVarEx("override_stamina", 		"0.0", 		"This will be the new stamina value when you land: 0.0 = full stamina/no speed is lost; -1.0 = let the engine handle how much speed you loose; (1315.0 = this is the default value in css, but use -1.0 instead if you wish to disable)",FCVAR_PLUGIN,true,0.0);
	g_cvarOr_SlowDownOnHurt			= CreateConVarEx("override_slowdownonhurt",	"1.0",		"This will override the speed ratio when hurt: 1.0 = no speed is lost; 0.5 = 50% slower; 0.0 = stops; 2.0 = 100% faster; -1.0 = let the engine/game handle how much speed you loose.",FCVAR_PLUGIN);
	g_cvarBoost_Forward				= CreateConVarEx("boost_forward",			"0.0",		"Amount of boost in units per second to push the client forward when jumping. Be careful this value adds ontop of the velocity at each jump.",FCVAR_PLUGIN);
	g_cvarBoost_Forward_WSAD		= CreateConVarEx("boost_forward_wsad",		"1",		"If this is 0 boost_forward will just apply when jumping, if this is 1 then you'll need to jump and press W,S,A,D (movement keys) for each direction (adds basicly more control).",FCVAR_PLUGIN,true,0.0,true,1.0);
	
	//ConVar runtime saver
	GetConVarString					(g_cvarFlag_Infinite,g_szPlugin_Flag_Infinite,sizeof(g_szPlugin_Flag_Infinite));
	GetConVarString					(g_cvarFlag_Double,g_szPlugin_Flag_Double,sizeof(g_szPlugin_Flag_Double));
	GetConVarString					(g_cvarFlag_PerfectDouble,g_szPlugin_Flag_PerfectDouble,sizeof(g_szPlugin_Flag_PerfectDouble));
	g_flPlugin_Boost_Initial		= GetConVarFloat(g_cvarBoost_Initial);
	g_flPlugin_Boost_Double			= GetConVarFloat(g_cvarBoost_Double);
	g_iPlugin_Max_DoubleJumps		= GetConVarInt(g_cvarMax_DoubleJumps);
	g_flPlugin_Or_Stamina			= GetConVarFloat(g_cvarOr_Stamina);
	g_flPlugin_Or_SlowDownOnHurt	= GetConVarFloat(g_cvarOr_SlowDownOnHurt);
	g_flPlugin_Boost_Forward		= GetConVarFloat(g_cvarBoost_Forward);
	g_iPlugin_Boost_Forward_WSAD	= GetConVarInt(g_cvarBoost_Forward_WSAD);
	
	//ConVar Hooks
	HookConVarChange(g_cvarFlag_Infinite,ConVarChange_Flag_Infinite);
	HookConVarChange(g_cvarFlag_Double,ConVarChange_Flag_Double);
	HookConVarChange(g_cvarFlag_PerfectDouble,ConVarChange_Flag_PerfectDouble);
	HookConVarChange(g_cvarBoost_Initial,ConVarChange_Boost_Initial);
	HookConVarChange(g_cvarBoost_Double,ConVarChange_Boost_Double);
	HookConVarChange(g_cvarMax_DoubleJumps,ConVarChange_Max_DoubleJumps);
	HookConVarChange(g_cvarOr_Stamina,ConVarChange_Or_Stamina);
	HookConVarChange(g_cvarOr_SlowDownOnHurt,ConVarChange_Or_SlowDownOnHurt);
	HookConVarChange(g_cvarBoost_Forward,ConVarChange_Boost_Forward);
	HookConVarChange(g_cvarBoost_Forward_WSAD,ConVarChange_Boost_Forward_WSAD);
	
	//Event Hooks
	new bool:hook_PlayerHurt = HookEventEx("player_hurt", Event_Player_Hurt);
	
	if(GetFeatureStatus(FeatureType_Native, "SDKHook") == FeatureStatus_Available){
		
		g_bExt_SDKHook = true;
	}
	
	Server_PrintDebug("hook_PlayerHurt: %d",hook_PlayerHurt);
	
	//Auto Config
	AutoExecConfig(true,"plugin.infinite-jumping");
}

public OnMapStart() {
	
	// hax against valvefail (thx psychonic for fix)
	if(GuessSDKVersion() == SOURCE_SDK_EPISODE2VALVE){
		SetConVarString(g_cvarVersion, PLUGIN_VERSION);
	}
}

public OnClientConnected(client){
	
	Client_Init(client);
}

public OnClientPostAdminCheck(client){
	
	Client_Init(client);
}

public OnConfigsExecuted(){
	
	ClientAll_Init();
	
	if(!g_bExt_SDKHook && g_iPlugin_Enable == 2){
		
		decl String:enableName[64];
		GetConVarName(g_cvarEnable,enableName,sizeof(enableName));
		
		LogError("%s = 2 has no effect since SDKHooks isn't loaded. Please check SDKHooks with 'sm exts list'",enableName);
	}
}

public OnPreThink(client){
	
	/*new iButtons = GetClientButtons(client);
	if(iButtons & IN_JUMP)
	{
		iButtons &= ~IN_JUMP;
		SetEntProp(client, Prop_Data, "m_nButtons", iButtons);
	}*/

	
	if(g_iPlugin_Enable != 2){
		ClientAll_PrintDebug("[%s] Enable is not 2",PLUGIN_NAME);
		return;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client)){
		ClientAll_PrintDebug("[%s] client: %d is not ingame, alive or a bot",PLUGIN_NAME,client);
		return;
	}
	
	new buttons = Client_GetButtons(client);
	
	//Client_PrintDebug(client,"#1 prethink buttons: %d",buttons);
	
	Client_HandleJumping(client,buttons);
	
	//Client_PrintDebug(client,"#2 prethink buttons: %d",buttons);
	
	Client_SetButtons(client,buttons);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon){
	
	if(g_iPlugin_Enable != 1){
		//PrintToChatAll("[%s] Plugin Disabled",PLUGIN_NAME);
		return Plugin_Continue;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client)){
		//PrintToChatAll("[%s] client: %d is not ingame, alive or a bot",PLUGIN_NAME);
		return Plugin_Continue;
	}
	
	return Client_HandleJumping(client,buttons);
}

/****************************************************************


C A L L B A C K   F U N C T I O N S


****************************************************************/
/*public SMLib_ConVarChange(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	if(cvar == g_cvarEnable && !g_bExt_SDKHook && StringToInt(newVal) == 2){
		
		decl String:enableName[64];
		GetConVarName(g_cvarEnable,enableName,sizeof(enableName));
		
		LogError("%s = 2 has no effect since SDKHooks isn't loaded. Please check SDKHooks with 'sm exts list'",enableName);
	}
}*/

public ConVarChange_Flag_Infinite(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	strcopy(g_szPlugin_Flag_Infinite,sizeof(g_szPlugin_Flag_Infinite),newVal);
	ClientAll_CheckJumpFlags();
}

public ConVarChange_Flag_Double(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	strcopy(g_szPlugin_Flag_Double,sizeof(g_szPlugin_Flag_Double),newVal);
	ClientAll_CheckJumpFlags();
}

public ConVarChange_Flag_PerfectDouble(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	strcopy(g_szPlugin_Flag_PerfectDouble,sizeof(g_szPlugin_Flag_PerfectDouble),newVal);
	ClientAll_CheckJumpFlags();
}

public ConVarChange_Boost_Initial(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_flPlugin_Boost_Initial = StringToFloat(newVal);
}

public ConVarChange_Boost_Double(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_flPlugin_Boost_Double = StringToFloat(newVal);
}

public ConVarChange_Max_DoubleJumps(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPlugin_Max_DoubleJumps = StringToInt(newVal);
}

public ConVarChange_Or_Stamina(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_flPlugin_Or_Stamina = StringToFloat(newVal);
}

public ConVarChange_Or_SlowDownOnHurt(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_flPlugin_Or_SlowDownOnHurt = StringToFloat(newVal);
}

public ConVarChange_Boost_Forward(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_flPlugin_Boost_Forward = StringToFloat(newVal);
}

public ConVarChange_Boost_Forward_WSAD(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPlugin_Boost_Forward_WSAD = StringToInt(newVal);
}



public Action:Event_Player_Hurt(Handle:event, const String:name[], bool:dontBroadcast){
	
	if(g_iPlugin_Enable == 0){
		return Plugin_Continue;
	}
	
	if(g_flPlugin_Or_SlowDownOnHurt == -1.0){
		return Plugin_Continue;
	}
	
	if(g_Offset_m_flVelocityModifier < 1){
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsFakeClient(client)){
		return Plugin_Continue;
	}
	
	Client_PrintDebug(client,"setting your: m_flVelocityModifier (off: %d) to: %f",g_Offset_m_flVelocityModifier,g_flPlugin_Or_SlowDownOnHurt);
	
	SetEntDataFloat(client, g_Offset_m_flVelocityModifier, g_flPlugin_Or_SlowDownOnHurt, true);
	
	return Plugin_Continue;
}

/*****************************************************************


P L U G I N   F U N C T I O N S


*****************************************************************/
//Thank you DarthNinja & javalia for this.
stock Client_Push(client,Float:direction[3],Float:power,ignoreZ=false,bool:overrideVel=false){
	
	decl Float:clientEyeAngle[3], Float:forwardVector[3], Float:newVel[3];
	
	GetClientEyeAngles(client, clientEyeAngle);
	
	if(ignoreZ){
		clientEyeAngle[0] = 0.0;
	}
	
	clientEyeAngle[0] += direction[0];
	clientEyeAngle[1] += direction[1];
	clientEyeAngle[2] += direction[2];
	
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, power);
	
	if(!overrideVel){
		Entity_GetAbsVelocity(client,newVel);
	}
	
	newVel[0] += forwardVector[0];
	newVel[1] += forwardVector[1];
	
	if(!ignoreZ){
		newVel[2] += forwardVector[2];
	}
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, newVel);
}

Client_ForceJump(client,Float:power){
	
	decl Float:clientVel[3];
	Entity_GetAbsVelocity(client,clientVel);
	clientVel[2] += power;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientVel);
}

ReJump(client) {
	
	if((1 <= g_iDoubleJumps[client] <= g_iPlugin_Max_DoubleJumps)){
		
		g_iDoubleJumps[client]++;
		
		Client_ForceJump(client,g_flPlugin_Boost_Double);
	}
}


stock Action:Client_HandleJumping(client, &buttons){
	
	if(Client_GetWaterLevel(client) > Water_Level:WATER_LEVEL_FEET_IN_WATER){
		//PrintToChatAll("[%s] Water level: %d",PLUGIN_NAME,Client_GetWaterLevel(client));
		return Plugin_Continue;
	}
	
	if(Client_IsOnLadder(client)){
		//PrintToChatAll("[%s] is on ladder",PLUGIN_NAME);
		return Plugin_Continue;
	}
	
	new flags = GetEntityFlags(client);
	//new Float:m_flStamina = GetEntDataFloat(client,g_Offset_m_flStamina);
	
	//Client_PrintDebug(client,"your m_flStamina value: %f",m_flStamina);
	
	//PrintToChat(client,"buttons: %d",buttons);
	
	if(buttons & IN_JUMP){
		
		if(flags & FL_ONGROUND){
			
			g_iDoubleJumps[client] = 1;
			
			if((g_bAllow_InfiniteJump[client]) && (g_flPlugin_Boost_Initial != 0.0)){
				
				Client_ForceJump(client,g_flPlugin_Boost_Initial);
			}
			
			//boost client
			if(g_flPlugin_Boost_Forward != 0.0){
				
				if(g_iPlugin_Boost_Forward_WSAD == 0){
					
					Client_Push(client,Float:{0.0,0.0,0.0},g_flPlugin_Boost_Forward,true);
				}
				else {
					
					if(buttons & IN_FORWARD){
						Client_Push(client,Float:{0.0,0.0,0.0},g_flPlugin_Boost_Forward,true);
					}
					
					if(buttons & IN_BACK){
						Client_Push(client,Float:{0.0,180.0,0.0},g_flPlugin_Boost_Forward,true);
					}
					
					if(buttons & IN_MOVELEFT){
						Client_Push(client,Float:{0.0,90.0,0.0},g_flPlugin_Boost_Forward,true);
					}
					
					if(buttons & IN_MOVERIGHT){
						Client_Push(client,Float:{0.0,-90.0,0.0},g_flPlugin_Boost_Forward,true);
					}
				}
			}
			
			g_fLastButtons[client] = buttons;
		}
		else {
			
			if(g_Offset_m_flStamina != -1 && g_flPlugin_Or_Stamina != -1.0){
				//you dont loose speed in css when you hit the ground with this:
				SetEntDataFloat(client, g_Offset_m_flStamina, g_flPlugin_Or_Stamina, true);
			}
			
			if(g_bAllow_DoubleJump[client]){
				
				if(g_bAllow_PerfectDoubleJump[client]){
					
					decl Float:clientVel[3];
					Entity_GetAbsVelocity(client,clientVel);
					
					if(clientVel[2] < 0.0){
						
						ReJump(client);
					}
				}
				else if(!(g_fLastButtons[client] & IN_JUMP)){
					
					ReJump(client);
				}
			}
			
			g_fLastButtons[client] = buttons;
			
			//set this here to protect g_fLastButtons from this change:
			if(g_bAllow_InfiniteJump[client]){
				
				buttons &= ~IN_JUMP;
			}
		}
	}
	else {
		
		//Disabled because scroll wheel users are at a big disadvantage
		/*if(g_Offset_m_flStamina != -1 && g_flPlugin_Or_Stamina != -1.0 && g_fLastButtons[client] & IN_JUMP){
			
			Client_PrintDebug(client,"setting your stamina to 1315.0");
			//SetEntDataFloat(client, g_Offset_m_flStamina, 1315.0, true);
		}*/
		
		//need to be set when IN_JUMP is not pressed
		g_fLastButtons[client] = buttons;
	}
	
	return Plugin_Continue;
}



//This function will be called within SMLib_OnPluginStart.
stock ClientAll_Init(){
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		Client_Init(client);
	}
}

stock Client_Init(client){
	
	//Variables
	Client_InitVars(client);
	
	//Functions
	Client_CheckJumpFlags(client);
	Client_GetOffsetsFrom(client);
	
	if(IsClientInGame(client) && g_bExt_SDKHook){
		SDKHook(client, SDKHook_PreThink, OnPreThink);
	}
}

stock Client_InitVars(client){
	
	//Plugin Client Vars
	g_bAllow_InfiniteJump[client] = false;
	g_bAllow_DoubleJump[client] = false;
	g_bAllow_PerfectDoubleJump[client] = false;
}

stock Client_GetOffsetsFrom(client){
	
	if(g_Offset_m_flStamina != -1 && g_Offset_m_flVelocityModifier != -1){
		return;
	}
	
	if(!IsValidEntity(client)){
		return;
	}
	
	decl String:netclass[64];
	
	GetEntityNetClass(client,netclass,sizeof(netclass));
	
	g_Offset_m_flStamina = FindSendPropInfo(netclass,"m_flStamina");
	g_Offset_m_flVelocityModifier = FindSendPropInfo(netclass,"m_flVelocityModifier");
	
	Server_PrintDebug("Offsets from client %d: m_flStamina: %d; m_flVelocityModifier: %d",client,g_Offset_m_flStamina,g_Offset_m_flVelocityModifier);
}

stock ClientAll_CheckJumpFlags(){
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		Client_CheckJumpFlags(client);
	}
}


stock Client_CheckJumpFlags(client){
	
	new AdminId:adminid = GetUserAdmin(client);
	new AdminFlag:flag;
	
	//g_bAllow_InfiniteJump:
	if(StrEqual(g_szPlugin_Flag_Infinite,"0",false)){
		
		Client_PrintDebug(client,"You are NOT allowed to infinite jump now! (%s)",g_szPlugin_Flag_Infinite);
		g_bAllow_InfiniteJump[client] = false;
	}
	else if(FindFlagByChar(g_szPlugin_Flag_Infinite[0],flag)){
		
		if(adminid == INVALID_ADMIN_ID){
			
			Client_PrintDebug(client,"You are NOT allowed to infinite jump now! (%s)",g_szPlugin_Flag_Infinite);
			g_bAllow_InfiniteJump[client] = false;
		}
		else if(GetAdminFlag(adminid,flag)){
			
			Client_PrintDebug(client,"You are allowed to infinite jump now! (%s)",g_szPlugin_Flag_Infinite);
			g_bAllow_InfiniteJump[client] = true;
		}
		else {
			
			Client_PrintDebug(client,"You are NOT allowed to infinite jump now! (%s)",g_szPlugin_Flag_Infinite);
			g_bAllow_InfiniteJump[client] = false;
		}
	}
	else {
		
		Client_PrintDebug(client,"You are allowed to infinite jump now! (%s)",g_szPlugin_Flag_Infinite);
		g_bAllow_InfiniteJump[client] = true;
	}
	
	//g_bAllow_DoubleJump:
	if(StrEqual(g_szPlugin_Flag_Double,"0",false)){
		
		Client_PrintDebug(client,"You are NOT allowed to double jump now! (%s)",g_szPlugin_Flag_Double);
		g_bAllow_DoubleJump[client] = false;
	}
	else if(FindFlagByChar(g_szPlugin_Flag_Double[0],flag)){
		
		if(adminid == INVALID_ADMIN_ID){
			
			Client_PrintDebug(client,"You are NOT allowed to double jump now! (%s)",g_szPlugin_Flag_Double);
			g_bAllow_DoubleJump[client] = false;
		}
		else if(GetAdminFlag(adminid,flag)){
			
			Client_PrintDebug(client,"You are allowed to double jump now! (%s)",g_szPlugin_Flag_Double);
			g_bAllow_DoubleJump[client] = true;
		}
		else {
			
			Client_PrintDebug(client,"You are NOT allowed to double jump now! (%s)",g_szPlugin_Flag_Double);
			g_bAllow_DoubleJump[client] = false;
		}
	}
	else {
		
		Client_PrintDebug(client,"You are allowed to double jump now! (%s)",g_szPlugin_Flag_Double);
		g_bAllow_DoubleJump[client] = true;
	}
	
	//g_bAllow_PerfectDoubleJump:
	if(StrEqual(g_szPlugin_Flag_PerfectDouble,"0",false)){
		
		Client_PrintDebug(client,"You are NOT allowed to perfectdouble jump now! (%s)",g_szPlugin_Flag_PerfectDouble);
		g_bAllow_PerfectDoubleJump[client] = false;
	}
	else if(FindFlagByChar(g_szPlugin_Flag_PerfectDouble[0],flag)){
		
		if(adminid == INVALID_ADMIN_ID){
			
			Client_PrintDebug(client,"You are NOT allowed to perfectdouble jump now! (%s)",g_szPlugin_Flag_PerfectDouble);
			g_bAllow_PerfectDoubleJump[client] = false;
		}
		else if(GetAdminFlag(adminid,flag)){
			
			Client_PrintDebug(client,"You are allowed to perfectdouble jump now! (%s)",g_szPlugin_Flag_PerfectDouble);
			g_bAllow_PerfectDoubleJump[client] = true;
		}
		else {
			
			Client_PrintDebug(client,"You are NOT allowed to perfectdouble jump now! (%s)",g_szPlugin_Flag_PerfectDouble);
			g_bAllow_PerfectDoubleJump[client] = false;
		}
	}
	else {
		
		Client_PrintDebug(client,"You are allowed to perfectdouble jump now! (%s)",g_szPlugin_Flag_PerfectDouble);
		g_bAllow_PerfectDoubleJump[client] = true;
	}
}





