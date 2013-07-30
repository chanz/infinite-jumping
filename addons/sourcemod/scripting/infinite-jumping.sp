/***************************************************************************************

	Copyright (C) 2012 BCServ (plugins@bcserv.eu)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
***************************************************************************************/

/***************************************************************************************


	C O M P I L E   O P T I O N S


***************************************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1

/***************************************************************************************


	P L U G I N   I N C L U D E S


***************************************************************************************/
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <smlib/pluginmanager>
//#include <baseplayerkeys>
#include <config>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#include <clientprefs>

/*****************************************************************


P L U G I N   I N F O


*****************************************************************/
public Plugin:myinfo = {
	name 						= "Infinite Jumping",
	author 						= "Chanz",
	description 				= "Lets user auto jump and/or double jump in mid air, when holding down space.",
	version 					= "3.15",
	url 						= "http://forums.alliedmods.net/showthread.php?p=1239361"
}

/*****************************************************************


P L U G I N   D E F I N E S


*****************************************************************/
#define TIMER_THINK 10.0

/***************************************************************************************


	G L O B A L   V A R S


***************************************************************************************/
// Server Variables


// Plugin Internal Variables
new Handle:g_hCookie_BanTime 					= INVALID_HANDLE;
new Handle:g_hCookie_Switch 					= INVALID_HANDLE;

// Console Variables
new Handle:g_cvarEnable 						= INVALID_HANDLE;
new Handle:g_cvarAutoJump						= INVALID_HANDLE;
new Handle:g_cvarLandingSlowDown				= INVALID_HANDLE;
new Handle:g_cvarBlockDamageSlowDown			= INVALID_HANDLE;
new Handle:g_cvarBoostJump						= INVALID_HANDLE;

// Console Variables: Runtime Optimizers
new g_iPlugin_Enable 							= 1;
new g_iPlugin_AutoJump							= 0;
new Float:g_flPlugin_LandingSlowDown			= 0.0;
new g_iPlugin_BlockDamageSlowDown				= 0;
new Float:g_vecPlugin_BoostJump[3]				= {0.0, 0.0, 0.0};

// Timers


// Library Load Checks
new bool:g_bClientPrefs_Loaded = false;

// Game Variables


// Map Variables


// Client Variables
new g_iCooMem_BanTime[MAXPLAYERS+1];
new bool:g_bCooMem_Switch[MAXPLAYERS+1];
new bool:g_bIsBanned[MAXPLAYERS+1];

// M i s c
new g_Offset_m_flStamina = -1;
new g_Offset_m_flVelocityModifier = -1;


/*****************************************************************


F O R W A R D   P U B L I C S


*****************************************************************/
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max){
	return APLRes_Success;
}

public OnPluginStart()
{
	// Initialization for SMLib
	PluginManager_Initialize("infinite-jumping", "[SM] ", true);
	
	// Translations
	// LoadTranslations("common.phrases");
	
	
	// Command Hooks (AddCommandListener) (If the command already exists, like the command kill, then hook it!)
	
	
	// Register New Commands (PluginManager_RegConsoleCmd) (If the command doesn't exist, hook it here)
	PluginManager_RegConsoleCmd("sm_autojump", Command_AutoJump, "On/Off Infinite (Auto) Jumping");
	
	// Register Admin Commands (PluginManager_RegAdminCmd)
	PluginManager_RegAdminCmd("sm_ban_autojump",Command_Ban,ADMFLAG_BAN,"Bans a player for a certain time from Infinite Jumping");
	
	// Cvars: Create a global handle variable.
	g_cvarEnable = PluginManager_CreateConVar("enable", "1", "Enables or disables this plugin");
	
	
	// Hook ConVar Change
	HookConVarChange(g_cvarEnable, ConVarChange_Enable);
	
	// Event Hooks
	HookEventEx("player_hurt", Event_Player_Hurt);
	
	// Library
	
	
	/* Features
	if(CanTestFeatures()){
		
	}
	*/
	
	// Create ADT Arrays
	
	
	// Timers
	CreateTimer(TIMER_THINK,Timer_Think,INVALID_HANDLE,TIMER_REPEAT);
	
	
	g_bClientPrefs_Loaded = (GetExtensionFileStatus("clientprefs.ext") == 1);
	if (g_bClientPrefs_Loaded) {
		
		// prepare title for clientPref menu
		decl String:menutitle[64];
		Format(menutitle, sizeof(menutitle), "%s", Plugin_Name);
		SetCookieMenuItem(PrefMenu, 0, menutitle);
		
		//Cookies
		g_hCookie_BanTime = RegClientCookie("infjumping_bantime","How long a client is banned from Infinite Jumping",CookieAccess_Protected);
		g_hCookie_Switch = RegClientCookie("infjumping_switch","Disables/Enables Infinite Jumping",CookieAccess_Public);
		
		
		for (new client=1; client <= MaxClients; client++) {
			
			if (!IsClientInGame(client)) {
				continue;
			}
			
			if (!AreClientCookiesCached(client)) {
				continue;
			}
			
			ClientIngameAndCookiesCached(client);
		}
	}
}

public OnMapStart()
{
	// hax against valvefail (thx psychonic for fix)
	if (GuessSDKVersion() == SOURCE_SDK_EPISODE2VALVE) {
		SetConVarString(Plugin_VersionCvar, Plugin_Version);
	}
}

public OnConfigsExecuted()
{
	// Set your ConVar runtime optimizers here
	g_iPlugin_Enable 				= GetConVarInt(g_cvarEnable);
	
	// Mind: this is only here for late load, since on map change or server start, there isn't any client.
	// Remove it if you don't need it.
	Client_InitializeAll();
}

public OnClientPutInServer(client)
{
	Client_Initialize(client);
}

public OnClientPostAdminCheck(client)
{
	Client_Initialize(client);
}

public OnClientCookiesCached(client){
	
	if (IsClientInGame(client)) {
		ClientIngameAndCookiesCached(client);
	}
}

/***************************************************************************************


	M E N U   F U N C T I O N S


***************************************************************************************/
public PrefMenu(client, CookieMenuAction:action, any:info, String:buffer[], maxlen){
	
	if (action == CookieMenuAction_SelectOption) {
		DisplaySettingsMenu(client);
	}
}
DisplaySettingsMenu(client){
	
	decl String:MenuItem[128];
	new Handle:prefmenu = CreateMenu(PrefMenuHandler);
	
	Format(MenuItem, sizeof(MenuItem), "%s", Plugin_Name);
	SetMenuTitle(prefmenu, MenuItem);
	
	new String:checked[] = String:0x9A88E2;
	
	Format(MenuItem, sizeof(MenuItem), "%t [%s]", "Enabled", g_bCooMem_Switch[client] ? checked : "   ");
	AddMenuItem(prefmenu, "1", MenuItem);
	
	Format(MenuItem, sizeof(MenuItem), "%t [%s]", "Disabled", g_bCooMem_Switch[client] ? "   " : checked);
	AddMenuItem(prefmenu, "0", MenuItem);
	
	DisplayMenu(prefmenu, client, MENU_TIME_FOREVER);
}

public PrefMenuHandler(Handle:prefmenu, MenuAction:action, client, item){
	
	if (action == MenuAction_Select) {
		decl String:preference[8];
		
		GetMenuItem(prefmenu, item, preference, sizeof(preference));
		
		g_bCooMem_Switch[client] = bool:StringToInt(preference);
		
		if (g_bCooMem_Switch[client]) {
			SetClientCookie(client, g_hCookie_Switch, "on");
			Client_PrintToChat(client,false,"{B}%s %t",Plugin_Tag,"You Enabled",Plugin_Name);
		}
		else {
			SetClientCookie(client, g_hCookie_Switch, "off");
			Client_PrintToChat(client,false,"{R}%s %t",Plugin_Tag,"You Disabled",Plugin_Name);
		}
		
		DisplaySettingsMenu(client);
	}
	else if (action == MenuAction_End) {
		CloseHandle(prefmenu);
	}
}

/**************************************************************************************


	C A L L B A C K   F U N C T I O N S


**************************************************************************************/
public Action:Timer_Think(Handle:timer){
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!Client_IsValid(client,true)){
			continue;
		}
		
		if(!Client_IsBanned(client) && g_bIsBanned[client]){
			g_bIsBanned[client] = false;
			Client_PrintToChat(client,false,"{B}%s %t",Plugin_Tag,"You have been unbanned",Plugin_Name);
		}
	}
	return Plugin_Continue;
}

/**************************************************************************************

	C O N  V A R  C H A N G E

**************************************************************************************/
/* Example Callback Con Var Change*/
public ConVarChange_Enable(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_iPlugin_Enable = StringToInt(newVal);
}

/**************************************************************************************

	C O M M A N D S

**************************************************************************************/
/* Example Command Callback
public Action:Command_(client, args)
{
	
	return Plugin_Handled;
}
*/
public Action:Command_AutoJump(client, args){
	
	if (g_bCooMem_Switch[client]) {
		g_bCooMem_Switch[client] = false;
		Client_PrintToChat(client, false, "{R}%s %t",Plugin_Tag,"You Disabled",Plugin_Name);
		
		if (g_bClientPrefs_Loaded) {
			SetClientCookie(client, g_hCookie_Switch, "off");
		}
	}
	else {
		g_bCooMem_Switch[client] = true;
		Client_PrintToChat(client, false, "{B}%s %t",Plugin_Tag,"You Enabled",Plugin_Name);
		
		if (g_bClientPrefs_Loaded) {
			SetClientCookie(client, g_hCookie_Switch, "on");
		}
	}
	return Plugin_Handled;
}
public Action:Command_Ban(client,args){
	
	if(args < 1){
		decl String:command[32];
		GetCmdArg(0,command,sizeof(command));
		Client_Reply(client,"%s %t",Plugin_Tag,"Usage: Ban",command);
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH];
	GetCmdArg(1,target,sizeof(target));
	decl String:arg2[11];
	GetCmdArg(2,arg2,sizeof(arg2));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS+1];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
	target,
	client,
	target_list,
	sizeof(target_list),
	COMMAND_FILTER_NO_BOTS,
	target_name,
	sizeof(target_name),
	tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	new bantime = StringToInt(arg2);
	
	if(bantime != 0){
		
		Client_PrintToConsole(client,"\n%s Banned %d players from %s for %d minutes:",Plugin_Tag,target_count,Plugin_Name,bantime);
	}
	else {
		
		Client_PrintToConsole(client,"\n%s Unbanned %d players from %s:",Plugin_Tag,target_count,Plugin_Name);
	}
	
	new i=0;
	new String:targetName[MAX_NAME_LENGTH];
	for (i=0;i<target_count;++i) {
		
		GetClientName(target_list[i],targetName,sizeof(targetName));
		Client_PrintToConsole(client,"\n%s",targetName);
		if(bantime != 0){
			
			Client_Ban(target_list[i],client,bantime);
		}
		else {
			
			Client_UnBan(target_list[i],client);
		}
	}
	
	Client_PrintToConsole(client,"\n-----------------------\n");
	
	if(bantime != 0){
		
		Client_PrintToChat(client,false,"{R}%s %t",Plugin_Tag,"See console output");
	}
	
	return Plugin_Handled;
}
/**************************************************************************************

	E V E N T S

**************************************************************************************/
/* Example Callback Event
public Action:Event_Example(Handle:event, const String:name[], bool:dontBroadcast)
{

}
*/
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
	
	if(!g_bAllow_AntiSlowDowns[client] || IsFakeClient(client)){
		return Plugin_Continue;
	}
	
	Client_PrintDebug(client,"setting your: m_flVelocityModifier (off: %d) to: %f",g_Offset_m_flVelocityModifier,g_flPlugin_Or_SlowDownOnHurt);
	
	SetEntDataFloat(client, g_Offset_m_flVelocityModifier, g_flPlugin_Or_SlowDownOnHurt, true);
	
	return Plugin_Continue;
}

/***************************************************************************************


	P L U G I N   F U N C T I O N S


***************************************************************************************/
ClientIngameAndCookiesCached(client){
	
	new String:buffer[255];
	GetClientCookie(client,g_hCookie_BanTime,buffer,sizeof(buffer));
	g_iCooMem_BanTime[client] = StringToInt(buffer);
	g_bIsBanned[client] = Client_IsBanned(client);
	
	GetClientCookie(client,g_hCookie_Switch,buffer,sizeof(buffer));
	g_bCooMem_Switch[client] = (!StrEqual(buffer,"off",false));
}


BanClient(client,banner,bantime){
	
	new String:bannerName[MAX_NAME_LENGTH];
	GetClientName(banner,bannerName,sizeof(bannerName));
	
	new String:szTime[11];
	g_iCooMem_BanTime[client] = GetTime()+bantime*60;
	IntToString(bantime,szTime,sizeof(szTime));
	
	if(g_bClientPrefs_Loaded){
		SetClientCookie(client,g_hCookie_BanTime,szTime);
	}
	g_bIsBanned[client] = true;
	
	Client_PrintToChat(client,false,"{R}%s %t",Plugin_Tag,"You have been banned by",Plugin_Name,bannerName,bantime);
}
UnBanClient(client,banner){
	
	new String:bannerName[MAX_NAME_LENGTH];
	GetClientName(banner,bannerName,sizeof(bannerName));
	
	g_iCooMem_BanTime[client] = 0;
	
	if(g_bClientPrefs_Loaded){
		SetClientCookie(client,g_hCookie_BanTime,"0");
	}
	g_bIsBanned[client] = false;
	
	Client_PrintToChat(client,false,"{R}%s %t",Plugin_Tag,"You have been unbanned by",Plugin_Name,bannerName);
}
bool:Client_IsBanned(client){
	
	return (g_iCooMem_BanTime[client] > GetTime());
}

Client_DoubleJump(client) {
	
	if((1 <= g_iDoubleJumps[client] <= g_iPlugin_Max_DoubleJumps)){
		
		g_iDoubleJumps[client]++;
		
		Client_Push(client,Float:{-90.0,0.0,0.0},g_flPlugin_Boost_Double,VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_Velocity});
	}
}

/***************************************************************************************

	S T O C K

***************************************************************************************/
enum VelocityOverride {
	
	VelocityOvr_None = 0,
	VelocityOvr_Velocity,
	VelocityOvr_OnlyWhenNegative,
	VelocityOvr_InvertReuseVelocity
};
//Thank you DarthNinja & javalia for this.
stock Client_Push(client, Float:directedForce[3], VelocityOverride:override[3]=VelocityOvr_None)
{
	new Float:newVel[3];
	Entity_GetAbsVelocity(client,newVel);
	
	for (new i=0;i<3;i++) {
		
		switch (override[i]) {
			
			case VelocityOvr_Velocity:{
				
				newVel[i] = 0.0;
			}
			case VelocityOvr_OnlyWhenNegative:{	
				
				if (newVel[i] < 0.0) {
					newVel[i] = 0.0;
				}
			}
			case VelocityOvr_InvertReuseVelocity:{		
				
				if (newVel[i] < 0.0) {
					newVel[i] *= -1.0;
				}
			}
		}
		
		newVel[i] += directedForce[i];
	}
	
	Entity_SetAbsVelocity(client,newVel);
}

public Action:Pressing_Jump(client, ButtonEvent:event, Float:time, tick){
	
	if(g_iPlugin_Enable != 1){
		return Plugin_Continue;
	}
	
	if(!IsPlayerAlive(client)){
		return Plugin_Continue;
	}
	
	if(g_bIsBanned[client]){
		return Plugin_Continue;
	}
	
	if(!g_bCooMem_Switch[client]){
		return Plugin_Continue;
	}
	
	if(Client_GetWaterLevel(client) > Water_Level:WATER_LEVEL_FEET_IN_WATER){
		return Plugin_Continue;
	}
	
	if(Client_IsOnLadder(client)){
		return Plugin_Continue;
	}
	
	if(GetEntityFlags(client) & FL_ONGROUND){
		
		if (GetVectorLength(g_vecPlugin_BoostJump) > 0.0) {
			
			Client_Push(client,g_vecPlugin_BoostJump);
		}
	}
	else {
		
		if (g_Offset_m_flStamina != -1 && g_flPlugin_LandingSlowDown != -1.0) {
			// After you jump the stamina is lowered so when you land, you'll get slower for a short time (to prevent bunny hopping).
			// This removes it or reduces its effect by the desired value (0.0 means you won't loose any speed after landing).
			SetEntDataFloat(client, g_Offset_m_flStamina, g_flPlugin_LandingSlowDown, true);
		}
	}
	
	if(tick % 2){
		return Plugin_Continue;
	}
	return Plugin_Handled;
}


stock Client_InitializeAll()
{
	LOOP_CLIENTS (client, CLIENTFILTER_ALL) {
		
		Client_Initialize(client);
	}
}

stock Client_Initialize(client)
{
	// Variables
	Client_InitializeVariables(client);
	
	
	// Functions
	
	
	/* Functions where the player needs to be in game */
	if (!IsClientInGame(client)) {
		return;
	}
	
	if (IsFakeClient(client)) {
		return;
	}
	
	Client_GetOffsetsFrom(client);
	BasePlayerKeys_HookClientButton(client, IN_JUMP, HookButtonEvent_Pressing, Pressing_Jump);
	
	if (AreClientCookiesCached(client)) {
		ClientIngameAndCookiesCached(client);
	}
}

stock Client_InitializeVariables(client)
{
	// Client Variables
	g_bAllow_InfiniteJump[client] 		= false;
	g_bAllow_DoubleJump[client] 		= false;
	g_bAllow_PerfectDoubleJump[client] 	= false;
	g_bAllow_AntiSlowDowns[client] 		= false;
	g_bAllow_ForwardBoost[client] 		= false;
}

stock Client_GetOffsetsFrom(client)
{
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



