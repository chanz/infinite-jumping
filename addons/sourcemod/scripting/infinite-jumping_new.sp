/*****************************************************************

    Infinite-Jumping (Auto Jumps, Air Jumps & Speed Management)
	Copyright (C) 2011 BCServ (plugins@bcserv.eu)

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
	
	
	NOTE:	You'll only find help in the following thread,
			http://forums.alliedmods.net/showthread.php?p=1239361
			OR
			http://sourcemodplugins.org/
	
*****************************************************************/

/*****************************************************************


C O M P I L E   O P T I O N S


*****************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1

/*****************************************************************


P L U G I N   I N C L U D E S


*****************************************************************/
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <smlib>
#include <smlib/pluginmanager>


/*****************************************************************


P L U G I N   I N F O


*****************************************************************/
#define PLUGIN_NAME				"Infinite Jumping"
#define PLUGIN_TAG				"sm"
#define PLUGIN_PRINT_PREFIX		"[SM] "
#define PLUGIN_AUTHOR			"Chanz"
#define PLUGIN_DESCRIPTION		"<desc>"
#define PLUGIN_VERSION 			"1.0.0"
#define PLUGIN_URL				"http://forums.alliedmods.net/showthread.php?p=1239361"

public Plugin:myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

/*****************************************************************


		P L U G I N   D E F I N E S


*****************************************************************/


/*****************************************************************


		G L O B A L   V A R S


*****************************************************************/
//Use a good notation, constants for arrays, initialize everything that has nothing to do with clients!
//If you use something which requires client index init it within the function Client_InitVars (look below)
//Example: Bad: "decl servertime" Good: "new g_iServerTime = 0"
//Example client settings: Bad: "decl saveclientname[33][32] Good: "new g_szClientName[MAXPLAYERS+1][MAX_NAME_LENGTH];" -> later in Client_InitVars: GetClientName(client,g_szClientName,sizeof(g_szClientName));

//ConVar Handles:
/*new Handle:g_cvarGroundJump_Switch				= INVALID_HANDLE;
new Handle:g_cvarGroundJump_Flag 				= INVALID_HANDLE;
new Handle:g_cvarGroundJump_Boost_Method		= INVALID_HANDLE;
new Handle:g_cvarGroundJump_Boost_Operator		= INVALID_HANDLE;
new Handle:g_cvarGroundJump_Boost_Value			= INVALID_HANDLE;

new Handle:g_cvarAutoGroundJump_Switch			= INVALID_HANDLE;
new Handle:g_cvarAutoGroundJump_Flag 			= INVALID_HANDLE;
new Handle:g_cvarAutoGroundJump_Boost_Method	= INVALID_HANDLE;
new Handle:g_cvarAutoGroundJump_Boost_Operator	= INVALID_HANDLE;
new Handle:g_cvarAutoGroundJump_Boost_Value		= INVALID_HANDLE;

new Handle:g_cvarAirJump_Switch					= INVALID_HANDLE;
new Handle:g_cvarAirJump_Flag 					= INVALID_HANDLE;
new Handle:g_cvarAirJump_MaxJumps				= INVALID_HANDLE;
new Handle:g_cvarAirJump_Boost_Method			= INVALID_HANDLE;
new Handle:g_cvarAirJump_Boost_Operator			= INVALID_HANDLE;
new Handle:g_cvarAirJump_Boost_Value			= INVALID_HANDLE;

new Handle:g_cvarAutoAirJump_Switch				= INVALID_HANDLE;
new Handle:g_cvarAutoAirJump_Flag				= INVALID_HANDLE;
new Handle:g_cvarAutoAirJump_Boost				= INVALID_HANDLE;

new Handle:g_cvarSlide_Switch					= INVALID_HANDLE;
new Handle:g_cvarSlide_Flag 					= INVALID_HANDLE;

new Handle:g_cvarDamageSlowDown_Switch			= INVALID_HANDLE;
new Handle:g_cvarDamageSlowDown_Flag 			= INVALID_HANDLE;

new Handle:g_cvarBoost_Switch					= INVALID_HANDLE;
new Handle:g_cvarBoost_Flag	 					= INVALID_HANDLE;
new Handle:g_cvarBoost_Method					= INVALID_HANDLE;

//ConVars runtime saver:
new g_iPlugin_GroundJump_Switch = 0;
new AdminFlag:g_afPlugin_GroundJump_Flag = 0;
new Float:g_flPlugin_GroundJump_Boost = 0.0;

new g_iPlugin_AutoGroundJump_Switch = 0;
new AdminFlag:g_afPlugin_AutoGroundJump_Flag = 0;
new Float:g_flPlugin_AutoGroundJump_Boost = 0.0;

new g_iPlugin_AirJump_Switch = 0;
new AdminFlag:g_afPlugin_AirJump_Flag = 0;
new Float:g_flPlugin_AirJump_Boost = 0.0;
new g_iPlugin_AirJump_Max = 0;

new g_iPlugin_AutoAirJump_Switch = 0;
new AdminFlag:g_afPlugin_AutoAirJump_Flag = 0;
new Float:g_flPlugin_AutoAirJump_Boost = 0.0;

new g_iPlugin_Slide_Switch = 0;
new AdminFlag:g_afPlugin_Slide_Flag = 0;

new g_iPlugin_DamageSlowDown_Switch = 0;
new AdminFlag:g_afPlugin_DamageSlowDown_Flag = 0;

new g_iPlugin_ForwardBoost_Switch = 0;
new AdminFlag:g_afPlugin_ForwardBoost_Flag = 0;

new g_iPlugin_Slide_Switch = 0;
new AdminFlag:g_afPlugin_Slide_Flag = 0;

new g_iPlugin_DamageSlowDown_Switch = 0;
new AdminFlag:g_afPlugin_DamageSlowDown_Flag = 0;

new g_iPlugin_ForwardBoost_Switch = 0;
new AdminFlag:g_afPlugin_ForwardBoost_Flag = 0;

new g_iPlugin_Slide_Switch = 0;
new AdminFlag:g_afPlugin_Slide_Flag = 0;*/

/*****************************************************************


		F O R W A R D   P U B L I C S


*****************************************************************/
public OnPluginStart() {
	
	//Init for smlib
	SMLib_OnPluginStart(PLUGIN_NAME,PLUGIN_TAG,PLUGIN_VERSION,PLUGIN_AUTHOR,PLUGIN_DESCRIPTION,PLUGIN_URL);
	
	//Translations (you should use it always when printing something to clients)
	//Always with plugin. as prefix, the short name and .phrases as postfix.
	decl String:translationsName[PLATFORM_MAX_PATH];
	Format(translationsName,sizeof(translationsName),"plugin.%s.phrases",g_sPlugin_Short_Name);
	File_LoadTranslations(translationsName);
	
	//Command Hooks (AddCommandListener) (If the command already exists, like the command kill, then hook it!)
	
	
	//Register New Commands (RegConsoleCmd) (If the command doesn't exist, hook it here)
	
	
	//Register Admin Commands (RegAdminCmd)
	
	
	//Cvars: Create a global handle variable.
	//Example: g_cvarEnable = CreateConVarEx("enable","1","example ConVar");
	
	
	//Set your ConVar runtime optimizers here
	//Example: g_iPlugin_Enable = GetConVarInt(g_cvarEnable);
	
	//Hook ConVar Change
	
	
	//Event Hooks
	
	
	//Auto Config (you should always use it)
	//Always with "plugin." prefix and the short name
	decl String:configName[MAX_PLUGIN_SHORTNAME_LENGTH+8];
	Format(configName,sizeof(configName),"plugin.%s",g_sPlugin_Short_Name);
	AutoExecConfig(true,configName);
	
	
	PrintToServer("\n\n#############\n\n(0 < 1 && (123 >= 122 || 11 == 11)) || 5 == 5\n");
	
	PrintToServer("String_Condition: %d",String_Condition("(0 < 1 && (123 >= 122 || 11 == 11)) || 5 == 5"));
	
	PrintToServer("if: %d",((0 < 1 && (123 >= 122 || 11 == 11)) || 5 == 5));
}

public OnMapStart() {
	
	// hax against valvefail (thx psychonic for fix)
	if(GuessSDKVersion() == SOURCE_SDK_EPISODE2VALVE){
		SetConVarString(g_cvarVersion, PLUGIN_VERSION);
	}
}

public OnConfigsExecuted(){
	
	//Mind: this is only here for late load, since on map change or server start, there isn't any client.
	//Remove it if you don't need it.
	Client_InitializeAll();
}

public OnClientConnected(client){
	
	Client_Initialize(client);
}

public OnClientPostAdminCheck(client){
	
	Client_Initialize(client);
}

/****************************************************************


		C A L L B A C K   F U N C T I O N S


****************************************************************/


/*****************************************************************


		P L U G I N   F U N C T I O N S


*****************************************************************/
enum LogicResult {
	
	LogicResult_Error = -1,
	LogicResult_False = false,
	LogicResult_True = true
};


//	"(56 < 1 && (123 >= 122 || 11 == 11)) || 5 == 5"

stock bool:String_Condition(const String:condition[], start=0){
	
	//get next "&&" or "||"
	new String:logic[256];
	new logicPos = 0;
	
	for(new i=start;condition[i] != '\0';i++){
		
		logic[logicPos] = condition[i];
		logicPos++;
		
		if(condition[i] == '('){
			
			return String_Condition(condition,i+1);
		}
		else if(condition[i] == ')'){
			
			return true;
		}
		
		if(condition[i-1] == '&' && condition[i] == '&'){
			
			if(String_SingleLogic(logic) != LogicResult_True){
				return false;
			}
			
			return String_Condition(condition,i+1);
		}
		else if (condition[i-1] == '|' && condition[i] == '|') {
			
			if(String_SingleLogic(logic) == LogicResult_True){
				return true;
			}
			
			return String_Condition(condition,i+1);
		}
	}
	
	return false;
}

stock LogicResult:String_SingleLogic(const String:logic[]){
	
	new String:numberOne[11];
	new String:numberTwo[11];
	new String:operatorChars[2];
	new numberOnePos = 0;
	new numberTwoPos = 0;
	new operatorCharsPos = 0;
	new bool:firstNumber = true;
	new bool:hitNumber = false;
	
	for(new i=0;logic[i] != '\0';i++){
		
		if(IsCharNumeric(logic[i])){
			
			hitNumber = true;
			
			if(firstNumber){
				
				numberOne[numberOnePos] = logic[i];
				numberOnePos++;
			}
			else {
				
				numberTwo[numberTwoPos] = logic[i];
				numberTwoPos++;
			}
		}
		else if(hitNumber && !IsCharSpace(logic[i])) {
			
			operatorChars[operatorCharsPos] = logic[i];
			operatorCharsPos++;
			
			firstNumber = false;
		}
	}
	
	new valueOne = StringToInt(numberOne);
	new valueTwo = StringToInt(numberTwo);
	
	switch(operatorChars[0]){
		
		case '<':{
			
			if(operatorChars[1] == '='){
				
				return LogicResult:(valueOne <= valueTwo);
			}
			
			return LogicResult:(valueOne < valueTwo);
		}
		case '>':{
			
			if(operatorChars[1] == '='){
				
				return LogicResult:(valueOne >= valueTwo);
			}
			
			return LogicResult:(valueOne > valueTwo);
		}
		case '!':{
			
			if(operatorChars[1] == '='){
				
				return LogicResult:(valueOne != valueTwo);
			}
			
			return LogicResult_Error;
		}
		case '=':{
			
			if(operatorChars[1] == '='){
				
				return LogicResult:(valueOne == valueTwo);
			}
			
			return LogicResult_Error;
		}
		default:return LogicResult_Error;
	}
	return LogicResult_Error;
}


stock Client_InitializeAll(){
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		Client_Initialize(client);
	}
}

stock Client_Initialize(client){
	
	//Variables
	Client_InitializeVariables(client);
	
	
	//Functions
	
	
	//Functions where the player needs to be in game
	if(!IsClientInGame(client)){
		return;
	}
}

stock Client_InitializeVariables(client){
	
	//Plugin Client Vars
	
}

