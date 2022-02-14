/**********************************************************************************************************************/
//Headers

/*
Headers
Plugin Information
Global Functions
Commands
Event Callbacks
Undead Forwards
SDKHook Callbacks
Timer Callbacks
Frame Callbacks
Menu Callbacks
Stock Functions
Natives

tf2-undead-core
tf2-undead-hud
tf2-undead-machines
tf2-undead-planks
*/

//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_VERSION "1.0.0"

#define GAME_TF2

#define MAX_WAVES 256
#define MAX_ZOMBIE_SPAWNS 256

#define SOUND_LOBBY_LOOP "ui/quest_haunted_scroll_halloween.mp3"
#define SOUND_PREFERRED_CONFIG_SET "ui/vote_yes.wav"

//Sourcemod Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <clientprefs>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Required Externals
#include <tf2attributes>
#include <tf2items_giveweapon>

//Our Includes
#include <tf2-undead/tf2-undead-core>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-machines>
#include <tf2-undead/tf2-undead-planks>
#include <tf2-undead/tf2-undead-powerups>
#include <tf2-undead/tf2-undead-specials>
#include <tf2-undead/tf2-undead-statistics>
#include <tf2-undead/tf2-undead-talents>
#include <tf2-undead/tf2-undead-zombies>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_GlobalMessageTimer;
ConVar convar_WavesConfig;
ConVar convar_Points_Per_Hit;
ConVar convar_Points_Per_Kill;
ConVar convar_Enable_Gnomes;
ConVar convar_Banned_Classes;
ConVar convar_Banned_Teams;
ConVar convar_Player_Team;
ConVar convar_Lobby_Time;
ConVar convar_Wave_Default_Config;
ConVar convar_Wave_Backup_Config;
ConVar convar_Zombie_Outlines;
ConVar convar_Survivor_Health;
ConVar convar_Survivor_Speed;
ConVar convar_StartingPoints;
ConVar convar_ReviveMarkers;
ConVar convar_EnableBuildings;
ConVar convar_DefaultStartZombiesPerWave;
ConVar convar_CreepyLobbyNoises;
ConVar convar_StripWeapons;

//Forwards
Handle g_forwardStartGame;
Handle g_forwardStartGame_Post;
Handle g_forwardWaveStart;
Handle g_forwardWaveStart_Post;
Handle g_forwardWaveEnd;
Handle g_forwardWaveEnd_Post;
Handle g_forwardEndGame;
Handle g_forwardEndGame_Post;

//Cookies
Handle g_hCookie_ShowGlobalMessage;
Handle g_hCookie_PreferredConfig;

//Globals
char sCurrentMap[MAX_MAP_NAME_LENGTH];
bool bLate;

//Global Variables
int iCurrentPoints[MAXPLAYERS + 1];
bool g_bPlaying[MAXPLAYERS + 1];
Handle hHealthRefillTimer[MAXPLAYERS + 1];
int iReviveMarker[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
//int g_iFrozenBy[MAX_ENTITY_LIMIT + 1] = {INVALID_ENT_REFERENCE, ...};
char sPreferredConfig[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
bool bShowGlobalMessage[MAXPLAYERS + 1] = {true, ...};

Handle hAllowedClasses;
Handle hGlobalMessageTimer;
//Handle g_hHud_Timer;

//Lobby
char sGameConfig[256];
float fLobbyTime;
Handle hLobbyTimer;
bool bPauseLobby;

//Config data for the game.
bool bIsEndless;

//Config data for the zombies.
int iZombieSpawnWaveClamp[MAX_ZOMBIE_SPAWNS];
float fZombieSpawns[MAX_ZOMBIE_SPAWNS][3];
int iZombieSpawns;

//Config data for the waves.
bool bWaves_HasContents[MAX_WAVES];
float fWaves_Wave_Time[MAX_WAVES];
float fWaves_Next_Wave_Time[MAX_WAVES];
bool bWaves_KillZombies_BetweenWaves[MAX_WAVES];
bool bWaves_KillSpecials_BetweenWaves[MAX_WAVES];
char sWaves_ActivateRelay[MAX_WAVES][256];
int iWaves_Starting_Wave_Spawns[MAX_WAVES];
float fWaves_Zombie_Spawns_Timer[MAX_WAVES];
int iWaves_Zombie_Spawns_Increment[MAX_WAVES];
bool bWaves_Zombie_Outlines[MAX_WAVES];
bool bWaves_Zombie_Gnomes[MAX_WAVES];
float fWaves_Zombie_BaseSpeed[MAX_WAVES];
int iWaves_Zombie_BaseHealth[MAX_WAVES];
Handle hWaves_Specials[MAX_WAVES];
int iWaves_Planks_Health[MAX_WAVES];
int iWaves_Planks_Cost[MAX_WAVES];
int iWaves_Planks_Max_Per_Round[MAX_WAVES];
float fWaves_Planks_Rebuild_Cooldown[MAX_WAVES];
float fWaves_Planks_Respawn[MAX_WAVES];
int iWavesAmount;

Handle g_hSpecialsList;

//Live Wave Information
bool bWavePaused;
int iLastUsableWave;
float fWaveTime;
float fWaveEndTime;

//Live Wave Handles
Handle hSpawnZombiesTimer;
Handle hWaveTimer;
Handle hNextWaveTimer;

//Wave information for zombies.
bool bZombieOutlines;
bool bZombieGnomes;
float fZombieSpeed;
int iZombieHealth;

/**********************************************************************************************************************/
//Plugin Information

public Plugin myinfo =
{
	name = "TF2 Undead - Core",
	author = "Keith Warren (Drixevel)",
	description = "COD-Zombies-Like TF2 gamemode.",
	version = PLUGIN_VERSION,
	url = "http://www.drixevel.com/"
};

/**********************************************************************************************************************/
//Global Functions

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-core");

	CreateNative("TF2Undead_IsInLobby", Native_IsInLobby);
	CreateNative("TF2Undead_IsWavePaused", Native_IsWavePaused);
	CreateNative("TF2Undead_GetClientPoints", Native_GetClientPoints);
	CreateNative("TF2Undead_UpdateClientPoints", Native_UpdateClientPoints);
	CreateNative("TF2Undead_AddClientPoints", Native_AddClientPoints);
	CreateNative("TF2Undead_SubtractClientPoints", Native_SubtractClientPoints);
	CreateNative("TF2Undead_MultiplyClientPoints", Native_MultiplyClientPoints);
	CreateNative("TF2Undead_DivideClientPoints", Native_DivideClientPoints);
	CreateNative("TF2Undead_SetClientPoints", Native_SetClientPoints);

	g_forwardStartGame = CreateGlobalForward("TF2Undead_OnStartGame", ET_Event, Param_String);
	g_forwardStartGame_Post = CreateGlobalForward("TF2Undead_OnStartGame_Post", ET_Ignore, Param_String);
	g_forwardWaveStart = CreateGlobalForward("TF2Undead_OnWaveStart", ET_Event, Param_Cell);
	g_forwardWaveStart_Post = CreateGlobalForward("TF2Undead_OnWaveStart_Post", ET_Ignore, Param_Cell);
	g_forwardWaveEnd = CreateGlobalForward("TF2Undead_OnWaveEnd", ET_Event, Param_Cell, Param_Cell);
	g_forwardWaveEnd_Post = CreateGlobalForward("TF2Undead_OnWaveEnd_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_forwardEndGame = CreateGlobalForward("TF2Undead_OnEndGame", ET_Event, Param_Cell);
	g_forwardEndGame_Post = CreateGlobalForward("TF2Undead_OnEndGame_Post", ET_Ignore, Param_Cell);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_status", "1");
	convar_GlobalMessageTimer = CreateConVar("sm_undead_global_message_timer", "180");
	convar_WavesConfig = CreateConVar("sm_undead_config_waves", "configs/undead/game_configs/");
	convar_Points_Per_Hit = CreateConVar("sm_undead_points_per_hit", "10");
	convar_Points_Per_Kill = CreateConVar("sm_undead_points_per_kill", "100");
	convar_Enable_Gnomes = CreateConVar("sm_undead_enable_gnomes", "0");
	convar_Banned_Classes = CreateConVar("sm_undead_status_banned_classes", "1");
	convar_Banned_Teams = CreateConVar("sm_undead_status_banned_teams", "1");
	convar_Player_Team = CreateConVar("sm_undead_survivor_team", "blue");
	convar_Lobby_Time = CreateConVar("sm_undead_lobby_timer", "60.0");
	convar_Wave_Default_Config = CreateConVar("sm_undead_default_wave_config", "player_preferred");
	convar_Wave_Backup_Config = CreateConVar("sm_undead_backup_wave_config", "wave_medium");
	convar_Zombie_Outlines = CreateConVar("sm_undead_status_zombie_outlines", "1");
	convar_Survivor_Health = CreateConVar("sm_undead_default_survivor_health", "200");
	convar_Survivor_Speed = CreateConVar("sm_undead_default_survivor_speed", "1.23");
	convar_StartingPoints = CreateConVar("sm_undead_starting_points", "500");
	convar_ReviveMarkers = CreateConVar("sm_undead_revive_markers", "1");
	convar_EnableBuildings = CreateConVar("sm_undead_enable_buildings", "0");
	convar_DefaultStartZombiesPerWave = CreateConVar("sm_undead_default_zombies_per_wave", "3");
	convar_CreepyLobbyNoises = CreateConVar("sm_undead_creepy_lobby_noises", "1");
	convar_StripWeapons = CreateConVar("sm_undead_creepy_strip_weapons", "1");

	HookConVarChange(convar_Lobby_Time, OnConVarUpdate_Lobby_Time);
	HookConVarChange(convar_GlobalMessageTimer, OnConVarUpdate_GlobalMessageTimer);
	HookConVarChange(convar_EnableBuildings, OnConVarUpdate_EnableBuildings);

	g_hCookie_ShowGlobalMessage = RegClientCookie("Undead_show_global_message", "Show the global message to the client.", CookieAccess_Private);
	g_hCookie_PreferredConfig = RegClientCookie("Undead_Preferred_Config", "Preferred configuration file for the client.", CookieAccess_Private);

	hAllowedClasses = CreateArray();
	PushArrayCell(hAllowedClasses, TFClass_Scout);
	//PushArrayCell(hAllowedClasses, TFClass_Soldier);
	//PushArrayCell(hAllowedClasses, TFClass_Pyro);
	//PushArrayCell(hAllowedClasses, TFClass_DemoMan);
	PushArrayCell(hAllowedClasses, TFClass_Heavy);
	PushArrayCell(hAllowedClasses, TFClass_Engineer);
	//PushArrayCell(hAllowedClasses, TFClass_Medic);
	PushArrayCell(hAllowedClasses, TFClass_Sniper);
	//PushArrayCell(hAllowedClasses, TFClass_Spy);

	RegAdminCmd("sm_startlobby", Command_StartLobby, ADMFLAG_ROOT, "Start the lobby.");
	RegAdminCmd("sm_startgame", Command_StartGame, ADMFLAG_ROOT, "Start the game.");
	RegAdminCmd("sm_togglewave", Command_ToggleWave, ADMFLAG_ROOT, "Pauses the lobby which pauses the timer and freezes the zombies.");
	RegAdminCmd("sm_togglegame", Command_ToggleWave, ADMFLAG_ROOT, "Pauses the lobby which pauses the timer and freezes the zombies.");
	RegAdminCmd("sm_pausewave", Command_PauseWave, ADMFLAG_ROOT, "Pauses the lobby which pauses the timer and freezes the zombies.");
	RegAdminCmd("sm_pausegame", Command_PauseWave, ADMFLAG_ROOT, "Pauses the lobby which pauses the timer and freezes the zombies.");
	RegAdminCmd("sm_resumewave", Command_ResumeWave, ADMFLAG_ROOT, "Unpauses the lobby which unpauses the timer and unfreezes the zombies.");
	RegAdminCmd("sm_resumegame", Command_ResumeWave, ADMFLAG_ROOT, "Unpauses the lobby which unpauses the timer and unfreezes the zombies.");
	RegAdminCmd("sm_unpausewave", Command_ResumeWave, ADMFLAG_ROOT, "Unpauses the lobby which unpauses the timer and unfreezes the zombies.");
	RegAdminCmd("sm_unpausegame", Command_ResumeWave, ADMFLAG_ROOT, "Unpauses the lobby which unpauses the timer and unfreezes the zombies.");
	RegAdminCmd("sm_endwave", Command_EndWave, ADMFLAG_ROOT, "End the current wave.");
	RegAdminCmd("sm_endgame", Command_EndGame, ADMFLAG_ROOT, "End the current game.");
	RegAdminCmd("sm_updatepoints", Command_UpdatePoints, ADMFLAG_ROOT, "Update points to players.");
	RegAdminCmd("sm_togglelobby", Command_ToggleLobby, ADMFLAG_ROOT, "Toggle the lobby timer.");
	RegAdminCmd("sm_pauselobby", Command_PauseLobby, ADMFLAG_ROOT, "Pause the lobby timer.");
	RegAdminCmd("sm_resumelobby", Command_ResumeLobby, ADMFLAG_ROOT, "Resume the lobby timer.");
	RegAdminCmd("sm_openrelays", Command_OpenRelays, ADMFLAG_ROOT, "Open all the relays on the map.");

	RegConsoleCmd("sm_lobby", Command_LobbyMenu, "Open the lobby menu.");
	RegConsoleCmd("sm_lobbymenu", Command_LobbyMenu, "Open the lobby menu.");
	RegConsoleCmd("sm_toggleglobalmessage", Command_ToggleGlobalMessage, "Toggle the global message.");

	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("teamplay_round_win", OnRoundWin);
	HookEvent("player_spawn", OnPlayerSpawnPost);
	HookEvent("player_changeclass", OnPlayerChangeClass);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("player_death", OnPlayerDeath);

	AddCommandListener(Listener_JoinTeam, "jointeam");
	AddCommandListener(Listener_OnBuildObject, "build");

	g_hSpecialsList = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));

	//g_hHud_Timer = CreateHudSynchronizer();
}

public void OnPluginEnd()
{
	//ClearTimerHud();
}

public void OnConVarUpdate_Lobby_Time(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue))
	{
		return;
	}

	float fNewTime = StringToFloat(newValue);

	if (fLobbyTime > fNewTime)
	{
		fLobbyTime = fNewTime;
	}
}

public void OnConVarUpdate_GlobalMessageTimer(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue))
	{
		return;
	}

	float fNewTime = StringToFloat(newValue);
	KillTimerSafe(hGlobalMessageTimer);

	if (fNewTime > 0.0)
	{
		hGlobalMessageTimer = CreateTimer(fNewTime, Timer_DisplayAdvert, _, TIMER_REPEAT);
	}
}

public void OnConVarUpdate_EnableBuildings(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue))
	{
		return;
	}

	switch (view_as<bool>(StringToInt(newValue)))
	{
	case true:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetPlayerClass(i) == TFClass_Engineer)
				{
					TF2Items_GiveWeapon(i, 25);
					TF2Items_GiveWeapon(i, 26);
					TF2Items_GiveWeapon(i, 28);
				}
			}
		}
	case false:
		{
			int entity = INVALID_ENT_INDEX;
			while ((entity = FindEntityByClassname(entity, "obj_*")) != INVALID_ENT_INDEX)
			{
				AcceptEntityInput(entity, "Kill");
			}
		}
	}
}

public void OnMapStart()
{
	GetMapName(sCurrentMap, sizeof(sCurrentMap));

	PrecacheModel("models/humans/group01/female_01.mdl", true);
	PrecacheModel("models/props_moonbase/moon_cube_crystal00.mdl");

	PrecacheSound(SOUND_LOBBY_LOOP);
	PrecacheSound(SOUND_PREFERRED_CONFIG_SET);

	PrecacheSound("tf2undead/noises/undead_zombie_death_explode.wav");
}

public void OnMapEnd()
{
	hLobbyTimer = null;
	bPauseLobby = false;

	hSpawnZombiesTimer = null;
	hWaveTimer = null;
	hNextWaveTimer = null;
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);

	//Global Message
	float time = GetConVarFloat(convar_GlobalMessageTimer);

	if (time > 0.0 && hGlobalMessageTimer == null)
	{
		hGlobalMessageTimer = CreateTimer(time, Timer_DisplayAdvert, _, TIMER_REPEAT);
	}

	//Late
	if (bLate)
	{
		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_INDEX)
		{
			char sClassname[128];
			GetEntityClassname(entity, sClassname, sizeof(sClassname));
			OnEntityCreated(entity, sClassname);
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}

			if (AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}

		bLate = false;
	}

	SetConVarInt(FindConVar("mp_respawnwavetime"), 99999);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_spellspawnzombie"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnZombieSpellSpawn);
	}
}

public Action Listener_JoinTeam(int client, const char[] command, int args)
{
	char sTeam[12];
	GetConVarString(convar_Player_Team, sTeam, sizeof(sTeam));

	char sEnemy[12];
	GetEnemyTeamInfo(sTeam, sEnemy, sizeof(sEnemy));

	char sArg1[12];
	GetCmdArg(1, sArg1, sizeof(sArg1));

	if (GetConVarBool(convar_Banned_Teams) && StrEqual(sArg1, sEnemy))
	{
		CPrintToChat(client, "%s You {red}CANNOT {gray}join team {white}%s{gray}, switching to {white}%s {gray}team.", sGlobalTag, sEnemy, sTeam);
		FakeClientCommand(client, "jointeam %s", sTeam);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Listener_OnBuildObject(int client, const char[] command, int args)
{
	return GetConVarBool(convar_EnableBuildings) ? Plugin_Continue : Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	if (buttons & IN_ATTACK2)
	{
		float fCoordinates[3];
		GetClientAbsOrigin(client, fCoordinates);

		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "entity_revive_marker")) != INVALID_ENT_INDEX)
		{
			float fOrigin[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);

			if (GetVectorDistance(fCoordinates, fOrigin) <= 50.0)
			{
				TF2_AddMarkerHealth(client, entity, TF2Undead_Machines_HasPerk(client, "quickrevive") ? 2 : 1);
			}
		}
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_GetMaxHealth, Hook_GetMaxHealth);
	g_bPlaying[client] = false;
}

public void OnClientCookiesCached(int client)
{
	char sValue[12];
	GetClientCookie(client, g_hCookie_ShowGlobalMessage, sValue, sizeof(sValue));
	bShowGlobalMessage[client] = (sValue[0] != '\0' && StringToInt(sValue));

	GetClientCookie(client, g_hCookie_PreferredConfig, sPreferredConfig[client], sizeof(sPreferredConfig[]));
}

public void OnClientDisconnect(int client)
{
	iCurrentPoints[client] = GetConVarInt(convar_StartingPoints);
	KillTimerSafe(hHealthRefillTimer[client]);
	bShowGlobalMessage[client] = true;
	sPreferredConfig[client][0] = '\0';

	if (iReviveMarker[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(iReviveMarker[client]);

		if (IsValidEntity(entity))
		{
			AcceptEntityInput(entity, "Kill");
		}

		iReviveMarker[client] = INVALID_ENT_REFERENCE;
	}

	if (g_bPlaying[client])
	{
		g_bPlaying[client] = false;
		RequestFrame(Frame_CheckRound);
	}
}

public bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	return (entity == 0 && entityhit != entity);
}

/*public void OnGameFrame()
{
	float vecOrigin[3];

	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != INVALID_ENT_INDEX)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrContains(sName, "unlock_model_") != -1 && GetEntProp(entity, Prop_Data, "m_CollisionGroup") != 0)
		{
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecOrigin);
			ScanForZombies(entity, vecOrigin);
		}
	}

	entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		if (g_iFrozenBy[entity] != INVALID_ENT_REFERENCE)
		{
			int blocker = EntRefToEntIndex(g_iFrozenBy[entity]);

			if (!IsValidEntity(blocker || GetEntProp(blocker, Prop_Data, "m_CollisionGroup") == 0))
			{
				TF2Undead_Zombies_FreezeZombie(entity, false);
			}

			g_iFrozenBy[entity] = INVALID_ENT_REFERENCE;
		}
	}
}

void ScanForZombies(int blocker, float block_origin[3])
{
	float vecZombieOrigin[3];

	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		if (TF2Undead_Zombies_IsZombieFrozen(entity))
		{
			continue;
		}

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecZombieOrigin);

		if (GetVectorDistance(block_origin, vecZombieOrigin) <= 50.0)
		{
			TF2Undead_Zombies_FreezeZombie(entity, true);
			g_iFrozenBy[entity] = EntIndexToEntRef(blocker);
		}
	}
}*/

/**********************************************************************************************************************/
//Commands

public Action Command_StartLobby(int client, int args)
{
	StartLobby();
	return Plugin_Handled;
}

public Action Command_StartGame(int client, int args)
{
	if (fLobbyTime > 10.0)
	{
		fLobbyTime = 10.0;
		CPrintToChatAll("%s {white}%N {gray}is force starting the match.", sGlobalTag, client);

		bPauseLobby = false;
	}

	return Plugin_Handled;
}

public Action Command_ToggleWave(int client, int args)
{
	bWavePaused = !bWavePaused;
	PauseAllZombies(bWavePaused);

	CReplyToCommand(client, "%s You have {white}%s {gray}the wave.", sGlobalTag, bWavePaused ? "paused" : "unpaused");
	CPrintToChatAll("%s The wave is now {white}%s{gray}.", sGlobalTag, bWavePaused ? "paused" : "unpaused");
	return Plugin_Handled;
}

public Action Command_PauseWave(int client, int args)
{
	bWavePaused = true;
	PauseAllZombies(bWavePaused);

	CReplyToCommand(client, "%s You have {white}paused {gray}the wave.", sGlobalTag);
	CPrintToChatAll("%s The wave is now {white}%s{gray}.", sGlobalTag, bWavePaused ? "paused" : "unpaused");
	return Plugin_Handled;
}

public Action Command_ResumeWave(int client, int args)
{
	bWavePaused = false;
	PauseAllZombies(bWavePaused);

	CReplyToCommand(client, "%s You have {white}unpaused {gray}the wave.", sGlobalTag);
	CPrintToChatAll("%s The wave is now {white}%s{gray}.", sGlobalTag, bWavePaused ? "paused" : "unpaused");
	return Plugin_Handled;
}

public Action Command_EndWave(int client, int args)
{
	fWaveTime = 0.0;
	CPrintToChatAll("%s {white}%N {gray}has ended the current wave.", sGlobalTag, client);
	return Plugin_Handled;
}

public Action Command_EndGame(int client, int args)
{
	if (hLobbyTimer != null)
	{
		CReplyToCommand(client, "%s You cannot end the game during the lobby.", sGlobalTag);
		return Plugin_Handled;
	}

	TF2_ForceRoundWin(TFTeam_Unassigned);
	CPrintToChatAll("%s {white}%N {gray}has ended the game.", sGlobalTag, client);

	return Plugin_Handled;
}

public Action Command_UpdatePoints(int client, int args)
{
	if (!GetConVarBool(convar_Status) || hLobbyTimer != null)
	{
		return Plugin_Handled;
	}

	if (args < 3)
	{
		char sCommand[32];
		GetCmdArg(0, sCommand, sizeof(sCommand));

		CReplyToCommand(client, "%s [TF2Z] Usage: %s <pattern> <action> <value>\nActions: 'add', 'subtract', 'multiply', 'divide', 'set'\nExample: %s @me add 5", sGlobalTag, sCommand, sCommand);
		return Plugin_Handled;
	}

	char sPattern[64];
	GetCmdArg(1, sPattern, sizeof(sPattern));

	char sAction[12];
	GetCmdArg(2, sAction, sizeof(sAction));

	char sValue[12];
	GetCmdArg(3, sValue, sizeof(sValue));
	int iValue = StringToInt(sValue);

	char sTargetName[MAX_TARGET_LENGTH];
	int iTargetList[MAXPLAYERS];
	bool tn_is_ml;

	int iTargetCount = ProcessTargetString(sPattern, client, iTargetList, sizeof(iTargetList), COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), tn_is_ml);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	ePointsModifier modifier = GetModifier(sAction);

	for (int i = 0; i < iTargetCount; i++)
	{
		UpdateClientPoints(client, iTargetList[i], modifier, iValue, true);
	}

	CReplyToCommand(client, "%s {white}%i {gray}points have been updated for {white}%i {gray}players.", sGlobalTag, iValue, iTargetCount);
	//CShowActivity2(client, sGlobalTag, "{gray}Updated points to {white}%i {gray}for {white}%i {gray}players.", iValue, iTargetCount);

	return Plugin_Handled;
}

public Action Command_OpenRelays(int client, int args)
{
	for (int i = 1; i <= iWavesAmount; i++)
	{
		if (strlen(sWaves_ActivateRelay[i]) > 0)
		{
			TriggerRelay(sWaves_ActivateRelay[i]);
		}
	}

	CPrintToChat(client, "%s All relays have been opened.", sGlobalTag);
	return Plugin_Handled;
}

public Action Command_ToggleLobby(int client, int args)
{
	bPauseLobby = !bPauseLobby;
	CPrintToChatAll("%s {white}%N {gray}has {white}%s {gray}the lobby.", sGlobalTag, client, bPauseLobby ? "paused" : "unpaused");
	return Plugin_Handled;
}

public Action Command_PauseLobby(int client, int args)
{
	if (bPauseLobby)
	{
		CReplyToCommand(client, "%s Lobby is already paused.", sGlobalTag);
		return Plugin_Handled;
	}

	bPauseLobby = true;
	CPrintToChatAll("%s {white}%N {gray}has {white}paused {gray}the lobby.", sGlobalTag, client);

	return Plugin_Handled;
}

public Action Command_ResumeLobby(int client, int args)
{
	if (!bPauseLobby)
	{
		CReplyToCommand(client, "%s Lobby is already unpaused.", sGlobalTag);
		return Plugin_Handled;
	}

	bPauseLobby = false;
	CPrintToChatAll("%s {white}%N {gray}has {white}unpaused {gray}the lobby.", sGlobalTag, client);
	return Plugin_Handled;
}

public Action Command_LobbyMenu(int client, int args)
{
	OpenLobbyMenu(client);
	return Plugin_Handled;
}

public Action Command_ToggleGlobalMessage(int client, int args)
{
	bShowGlobalMessage[client] = !bShowGlobalMessage[client];

	char sValue[12];
	IntToString(bShowGlobalMessage[client], sValue, sizeof(sValue));
	SetClientCookie(client, g_hCookie_ShowGlobalMessage, sValue);

	CPrintToChat(client, "%s You have {white}%s{gray} the global message.", sGlobalTag, bShowGlobalMessage[client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

/**********************************************************************************************************************/
//Event Callbacks

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	StartLobby();
}

public void OnRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	int winning_team = GetEventInt(event, "team");

	char sTeam[12];
	GetConVarString(convar_Player_Team, sTeam, sizeof(sTeam));
	int team = view_as<int>(GetTeamID(sTeam));

	Call_StartForward(g_forwardEndGame);
	Call_PushCell(view_as<bool>(team == winning_team));
	Call_Finish();

	KillTimerSafe(hSpawnZombiesTimer);
	KillTimerSafe(hWaveTimer);
	KillTimerSafe(hNextWaveTimer);

	TF2Undead_Zombies_KillAllZombies();

	bWavePaused = false;
	PauseAllZombies(bWavePaused);

	//ClearTimerHud();

	for (int i = 1; i <= MaxClients; i++)
	{
		g_bPlaying[i] = false;
	}

	if (g_forwardEndGame_Post != null)
	{
		Call_StartForward(g_forwardEndGame_Post);
		Call_PushCell(view_as<bool>(team == winning_team));
		Call_Finish();
	}
}

public void OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	KillTimerSafe(hHealthRefillTimer[client]);
	hHealthRefillTimer[client] = CreateTimer(5.0, Timer_RefillHealth, userid);
}

public void OnPlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	if (GetConVarBool(convar_Banned_Teams))
	{
		char sTeam[12];
		GetConVarString(convar_Player_Team, sTeam, sizeof(sTeam));
		TFTeam team = GetTeamID(sTeam);

		if (TF2_GetClientTeam(client) != team)
		{
			ChangeClientTeam_Alive(client, view_as<int>(team));
		}
	}

	if (hLobbyTimer != null)
	{
		/*if (!IsFakeClient(client))
		{
			ClearSyncHud(client, g_hHud_Timer);
		}*/

		OpenLobbyMenu(client);
		return;
	}

	TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(convar_Survivor_Speed));
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client == 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	if (GetConVarBool(convar_ReviveMarkers) && hLobbyTimer == null)
	{
		int entity = CreateEntityByName("entity_revive_marker");

		if (IsValidEntity(entity))
		{
			float vecCoordinates[3];
			GetClientAbsOrigin(client, vecCoordinates);

			DispatchKeyValueVector(entity, "origin", vecCoordinates);

			SetEntPropEnt(entity, Prop_Send, "m_hOwner", client);
			SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
			SetEntProp(entity, Prop_Send, "m_usSolidFlags", 8);
			SetEntProp(entity, Prop_Send, "m_fEffects", 16);
			SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
			SetEntProp(entity, Prop_Send, "m_bSimulatedEveryTick", 1);
			SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin") + 4, entity);
			SetEntProp(entity, Prop_Send, "m_nBody", view_as<int>(TF2_GetPlayerClass(client)) - 1);
			SetEntProp(entity, Prop_Send, "m_nSequence", 1);
			SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);
			SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", GetClientTeam(client));

			DispatchSpawn(entity);

			iReviveMarker[client] = EntIndexToEntRef(entity);
		}
	}
	else if (hLobbyTimer != null)
	{
		CreateTimer(2.0, Timer_RespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	RequestFrame(Frame_CheckRound);
}

public Action OnPlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int iClass = GetEventInt(event, "class");
	TFClassType iCurrent = TF2_GetPlayerClass(client);

	if (GetConVarBool(convar_Banned_Classes) && FindValueInArray(hAllowedClasses, iClass) == INVALID_ARRAY_INDEX)
	{
		CPrintToChat(client, "%s You are {red}NOT {gray}allowed to go this class.", sGlobalTag);

		if (iCurrent == TFClass_Unknown)
		{
			iCurrent = GetArrayCell(hAllowedClasses, GetRandomInt(0, GetArraySize(hAllowedClasses) - 1));
		}

		TF2_SetPlayerClass(client, iCurrent);
	}

	return Plugin_Continue;
}

/**********************************************************************************************************************/
//SDKHook Callbacks

public Action Hook_GetMaxHealth(int client, int &MaxHealth)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		MaxHealth = TF2Undead_Machines_HasPerk(client, "juggernog") ? 300 : GetConVarInt(convar_Survivor_Health);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Hook_GameStart_OnStartTouch(int entity, int other)
{
	if (other > 0 && other <= MaxClients && IsPlayerAlive(other))
	{
		ResetPlayer(other, true);
		g_bPlaying[other] = true;
	}
}

/**********************************************************************************************************************/
//Undead Forwards

public void TF2Undead_OnMachinePerkRemoved_Post(int client, const char[] machine)
{
	if (StrEqual(machine, "staminup"))
	{
		TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(convar_Survivor_Speed));
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
	}
}

public Action TF2Undead_OnZombieTakeDamage(int zombie, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker < 1 || attacker > MaxClients)
	{
		return Plugin_Continue;
	}

	if (bWavePaused)
	{
		damage = 0.0;
		return Plugin_Changed;
	}

	if (hLobbyTimer == null)
	{
		Handle hPack = CreateDataPack();
		WritePackCell(hPack, zombie);
		WritePackCell(hPack, attacker);

		RequestFrame(Frame_DelayDamage, hPack);
	}

	if (TF2Undead_Powerups_IsInstantKill())
	{
		AcceptEntityInput(zombie, "Kill");
	}

	if (TF2Undead_Machines_HasPerk(attacker, "deadshot"))
	{
		float vecBase[3];
		GetEntPropVector(zombie, Prop_Send, "m_vecOrigin", vecBase);

		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
		{
			float vecNew[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecNew);

			if (GetVectorDistance(vecBase, vecNew) < 10.0)
			{
				SDKHooks_TakeDamage(entity, attacker, attacker, damage, damagetype, weapon, damageForce, damagePosition);
			}
		}
	}

	return Plugin_Continue;
}

public Action TF2Undead_OnZombieSpawn(int zombie)
{
	if (GetEntPropFloat(zombie, Prop_Data, "m_flModelScale") < 1.0)
	{
		if (!GetConVarBool(convar_Enable_Gnomes) || !bZombieGnomes)
		{
			AcceptEntityInput(zombie, "Kill");
		}
	}
}

public void TF2Undead_OnZombieSpawn_Post(int zombie, int skeleton)
{
	if (GetConVarBool(convar_Zombie_Outlines))
	{
		SetEntProp(skeleton, Prop_Send, "m_bGlowEnabled", bZombieOutlines);
	}
}

/**********************************************************************************************************************/
//Timer Callbacks

public Action Timer_RefillHealth(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		hHealthRefillTimer[client] = null;
		return Plugin_Stop;
	}

	SetEntityHealth(client, TF2Undead_Machines_HasPerk(client, "juggernog") ? 300 : GetConVarInt(convar_Survivor_Health));

	hHealthRefillTimer[client] = null;
	return Plugin_Stop;
}

public Action Timer_DisplayAdvert(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && bShowGlobalMessage[i])
		{
			CPrintToChat(i, "%s Join the TF2 Undead official steamgroup here:\n{white}www.steamcommunity.com/groups/TF2UndeadZombies", sGlobalTag);
		}
	}
}

public Action OnZombieSpellSpawn(int entity)
{
	CreateTimer(1.0, Timer_KillZombieSpell, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillZombieSpell(Handle timer, any data)
{
	int entity = EntRefToEntIndex(data);

	if (IsValidEntity(entity))
	{
		if (!GetConVarBool(convar_Enable_Gnomes) || !bZombieGnomes)
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
}

public Action Timer_LobbySound(Handle timer, any data)
{
	if (hLobbyTimer == null)
	{
		return Plugin_Stop;
	}

	EmitSoundToAll(SOUND_LOBBY_LOOP);
	return Plugin_Continue;
}

public Action Timer_DisplayLobbyHUD(Handle timer)
{
	if (!CheckForValidGameParameters())
	{
		fLobbyTime = GetConVarFloat(convar_Lobby_Time);
		return Plugin_Continue;
	}

	if (!bPauseLobby)
	{
		fLobbyTime--;
	}

	char sLobbyTime[128];
	FormatSeconds(fLobbyTime, sLobbyTime, sizeof(sLobbyTime), "%M:%S");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			PrintHintText(i, "Next round starts in: %s %s", sLobbyTime, bPauseLobby ? "(Paused)" : "");
			if (fLobbyTime > 10.0 || bPauseLobby)
			{
				StopSound(i, SNDCHAN_STATIC, "UI/hint.wav");
			}
		}
	}

	if (fLobbyTime <= 0.0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				StopSound(i, SNDCHAN_AUTO, SOUND_LOBBY_LOOP);
			}
		}

		StartGame();

		hLobbyTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Timer_SpawnZombies(Handle timer, any data)
{
	if (bWavePaused)
	{
		return Plugin_Continue;
	}

	int use = data;
	SpawnZombies(iWaves_Zombie_Spawns_Increment[use] /** GetClientCount(true)*/, use);
	return Plugin_Continue;
}

public Action Timer_NextWaveTimer(Handle timer, any data)
{
	int wave = data + 1;

	char sMaxWaves[12];
	IntToString(iWavesAmount, sMaxWaves, sizeof(sMaxWaves));

	char sBuffer[512];
	FormatEx(sBuffer, sizeof(sBuffer), "Next wave %i/%s in: ", wave, bIsEndless ? "∞" : sMaxWaves);
	ShowTimerHudToAll(sBuffer, fWaveEndTime, bWavePaused);

	if (bWavePaused)
	{
		return Plugin_Continue;
	}

	fWaveEndTime--;

	if (fWaveEndTime <= 0.0)
	{
		StartWave(wave);

		hNextWaveTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Timer_RespawnPlayer(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (client > 0 && !IsPlayerAlive(client) && hLobbyTimer != null)
	{
		TF2_RespawnPlayer(client);
	}
}

/**********************************************************************************************************************/
//Frame Callbacks

public void Frame_CheckRound(any data)
{
	if (hLobbyTimer == null && !PlayersPlaying())
	{
		EndRoundMoveToLobby(false);
	}
}

public void Frame_DelayDamage(any data)
{
	ResetPack(data);
	int zombie = ReadPackCell(data);
	int attacker = ReadPackCell(data);
	CloseHandle(data);

	int value = IsValidEntity(zombie) ? GetConVarInt(convar_Points_Per_Hit) : GetConVarInt(convar_Points_Per_Kill);

	if (TF2Undead_Powerups_IsDoublePoints())
	{
		value *= 2;
	}

	if (hLobbyTimer == null)
	{
		UpdateClientPoints(attacker, attacker, Add, value);
	}
}

/**********************************************************************************************************************/
//Menu Forwards

public int MenuHandler_PreferredConfig(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sFile[PLATFORM_MAX_PATH]; char sName[256];
			GetMenuItem(menu, param2, sFile, sizeof(sFile), _, sName, sizeof(sName));

			strcopy(sPreferredConfig[param1], sizeof(sPreferredConfig[]), sFile);
			SetClientCookie(param1, g_hCookie_PreferredConfig, sPreferredConfig[param1]);
			CPrintToChatAll("%s %N have set their preferred configuration to {white}%s{gray}!", sGlobalTag, param1, sName);
			EmitSoundToClient(param1, SOUND_PREFERRED_CONFIG_SET);
			OpenLobbyMenu(param1);
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public int MenuHandler_LobbyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "information"))
			{
				ShowInformationMenu(param1);
			}
			else if (StrEqual(sInfo, "statistics"))
			{
				TF2Undead_Statistics_ShowStatisticsMenu(param1);
			}
			else if (StrEqual(sInfo, "preffered_config"))
			{
				ChoosePreferredConfig(param1);
			}
			else if (StrEqual(sInfo, "set_talents"))
			{
				TF2Undead_Talents_ShowMenu(param1);
			}
			else if (StrEqual(sInfo, "toggle_global_message"))
			{
				Command_ToggleGlobalMessage(param1, 0);
				OpenLobbyMenu(param1);
			}
			else if (StrEqual(sInfo, "toggle_lobby"))
			{
				Command_ToggleLobby(param1, 0);
				OpenLobbyMenu(param1);
			}
			else if (StrEqual(sInfo, "set_config"))
			{
				SetGameConfigMenu(param1);
			}
			else if (StrEqual(sInfo, "delay_game"))
			{
				fLobbyTime += 30.0;
				CPrintToChatAll("%s {white}%N {gray}has delayed the match by {white}30 {gray}seconds.", sGlobalTag, param1);
				OpenLobbyMenu(param1);
			}
			else if (StrEqual(sInfo, "start_game"))
			{
				Command_StartGame(param1, 0);
				OpenLobbyMenu(param1);
			}
		}
	case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public int MenuHandle_SetGameConfigMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			char sInfo[64];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (strlen(sInfo) > 0)
			{
				strcopy(sGameConfig, sizeof(sGameConfig), sInfo);

				char sWaveName[256];
				RetrieveConfigName(sGameConfig, sWaveName, sizeof(sWaveName));

				CPrintToChatAll("%s {white}%N {gray}has set the config to {white}%s{gray}.", sGlobalTag, param1, sWaveName);
			}

			OpenLobbyMenu(param1);
		}

	case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

/**********************************************************************************************************************/
//Stock Functions

bool TF2_AddMarkerHealth(int iReviver, int iMarker, int iHealthAdd)
{
	if (!IsPlayerAlive(iReviver))
	{
		return false;
	}

	int iHealth = GetEntProp(iMarker, Prop_Send, "m_iHealth");
	int iMaxHealth = 175/*GetEntProp(iMarker, Prop_Send, "m_iMaxHealth")*/;
	int iOwner = GetEntPropEnt(iMarker, Prop_Send, "m_hOwner");

	PrintHintText(iReviver, "Reviving '%N'... [%i/%i]", iOwner, iHealth, iMaxHealth);

	SetEntProp(iMarker, Prop_Send, "m_iHealth", iHealth + iHealthAdd);

	iHealth += iHealthAdd;

	if (iHealth >= iMaxHealth && IsClientInGame(iOwner))
	{
		if (iReviver == iOwner)
		{
			return false;
		}

		//Do revive
		float vecMarkerPos[3];
		GetEntPropVector(iMarker, Prop_Send, "m_vecOrigin", vecMarkerPos);

		EmitGameSoundToAll("MVM.PlayerRevived", iMarker);

		float flMins[3], flMaxs[3];
		GetEntPropVector(iOwner, Prop_Send, "m_vecMaxs", flMaxs);
		GetEntPropVector(iOwner, Prop_Send, "m_vecMins", flMins);

		Handle TraceRay = TR_TraceHullFilterEx(vecMarkerPos, vecMarkerPos, flMins, flMaxs, MASK_PLAYERSOLID, TraceFilterNotSelf, iMarker);
		if (TR_DidHit(TraceRay))
		{
			float vecReviverPos[3];
			GetClientAbsOrigin(iReviver, vecReviverPos);

			TF2_RespawnPlayer(iOwner);
			TeleportEntity(iOwner, vecReviverPos, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			TF2_RespawnPlayer(iOwner);
			TeleportEntity(iOwner, vecMarkerPos, NULL_VECTOR, NULL_VECTOR);
		}

		TFClassType class = view_as<TFClassType>(GetEntProp(iMarker, Prop_Send, "m_nBody") + 1);
		TF2_SetPlayerClass(iOwner, class, true, true);
		TF2_RegeneratePlayer(iOwner);

		ResetPlayer(iOwner);

		iReviveMarker[iOwner] = INVALID_ENT_REFERENCE;
		delete TraceRay;
	}

	return true;
}

void OpenLobbyMenu(int client)
{
	if (hLobbyTimer == null)
	{
		CPrintToChat(client, "%s You cannot open the lobby menu at this time.", sGlobalTag);
		return;
	}

	char sGameConfigName[256];
	RetrieveConfigName(sGameConfig, sGameConfigName, sizeof(sGameConfigName));

	char sPreferredConfigName[256];
	RetrieveConfigName(sPreferredConfig[client], sPreferredConfigName, sizeof(sPreferredConfigName));

	Menu menu = CreateMenu(MenuHandler_LobbyMenu);
	SetMenuTitle(menu, "TF2 Undead (%s) - Lobby Menu\nLoaded Config: %s\n ", PLUGIN_VERSION, sGameConfigName);

	int style = CheckCommandAccess(client, "", ADMFLAG_ROOT) ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE;

	AddMenuItem(menu, "information", "Information & Details", ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "statistics", "Show Statistics Menu", ITEMDRAW_DEFAULT);
	AddMenuItemFormat(menu, "preffered_config", ITEMDRAW_DEFAULT, "Preferred Config: %s", strlen(sPreferredConfigName) > 0 ? sPreferredConfigName : "[Not Set]");
	AddMenuItemFormat(menu, "toggle_global_message", ITEMDRAW_DEFAULT, "Toggle Global Message (%s)", bShowGlobalMessage[client] ? "Enabled" : "Disabled");
	AddMenuItem(menu, "", " ---", CheckCommandAccess(client, "", ADMFLAG_ROOT) ? ITEMDRAW_DISABLED : ITEMDRAW_IGNORE);
	AddMenuItemFormat(menu, "toggle_lobby", style, bPauseLobby ? "Unpause Lobby" : "Pause Lobby");
	AddMenuItemFormat(menu, "start_game", style, "Start Game");
	AddMenuItemFormat(menu, "delay_game", style, "Delay Game");
	AddMenuItemFormat(menu, "set_config", style, "Set Config");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

ePointsModifier GetModifier(const char[] sAction)
{
	if (StrEqual(sAction, "add"))
	{
		return Add;
	}
	else if (StrEqual(sAction, "subtract"))
	{
		return Subtract;
	}
	else if (StrEqual(sAction, "multiply"))
	{
		return Multiply;
	}
	else if (StrEqual(sAction, "divide"))
	{
		return Divide;
	}
	else if (StrEqual(sAction, "set"))
	{
		return Set;
	}

	return Add;
}

void ChoosePreferredConfig(int client)
{
	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_WavesConfig, sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/", sConfig, sCurrentMap);

	DirectoryListing dir = OpenDirectory(sPath);

	if (dir == null)
	{
		return;
	}

	Menu menu = CreateMenu(MenuHandler_PreferredConfig);
	SetMenuTitle(menu, "Pick a preffered config:");

	char sFile[PLATFORM_MAX_PATH];
	FileType type;

	while (ReadDirEntry(dir, sFile, sizeof(sFile), type))
	{
		if (type == FileType_File)
		{
			ReplaceString(sFile, sizeof(sFile), ".cfg", "");

			char sBuffer[256];
			RetrieveConfigName(sFile, sBuffer, sizeof(sBuffer));

			AddMenuItem(menu, sFile, sBuffer);
		}
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

void SetGameConfigMenu(int client)
{
	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_WavesConfig, sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/", sConfig, sCurrentMap);

	DirectoryListing dir = OpenDirectory(sPath);

	if (dir == null)
	{
		return;
	}

	Menu menu = CreateMenu(MenuHandle_SetGameConfigMenu);
	SetMenuTitle(menu, "Choose a config:");

	char sFile[PLATFORM_MAX_PATH];
	FileType type;

	AddMenuItem(menu, "player_preferred", "Player Preferred");

	while (ReadDirEntry(dir, sFile, sizeof(sFile), type))
	{
		if (type == FileType_File)
		{
			ReplaceString(sFile, sizeof(sFile), ".cfg", "", false);
			AddMenuItem(menu, sFile, sFile);
		}
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

bool CheckForValidGameParameters()
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) > 1 && IsPlayerAlive(i))
		{
			count++;
		}
	}
	return count > 0;
}

bool CalculatePreferredConfig(char[] wave_config, int size)
{
	Handle trie = CreateTrie();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && strlen(sPreferredConfig[i]) > 0)
		{
			int amount;
			GetTrieValue(trie, sPreferredConfig[i], amount);

			amount++;

			SetTrieValue(trie, sPreferredConfig[i], amount);
		}
	}

	if (GetTrieSize(trie) == 0)
	{
		GetConVarString(convar_Wave_Backup_Config, wave_config, size);
		CloseHandle(trie);
		return false;
	}

	Handle map = CreateTrieSnapshot(trie);

	int cache;
	char sConfigCache[PLATFORM_MAX_PATH];

	for (int i = 0; i < TrieSnapshotLength(map); i++)
	{
		int size2 = TrieSnapshotKeyBufferSize(map, i);

		char[] sConfig = new char[size2 + 1];
		GetTrieSnapshotKey(map, i, sConfig, size2 + 1);

		int amount;
		GetTrieValue(trie, sConfig, amount);

		if (amount > cache)
		{
			strcopy(sConfigCache, sizeof(sConfigCache), sConfig);
			cache = amount;
		}
	}

	strcopy(wave_config, size, sConfigCache);

	CloseHandle(trie);
	CloseHandle(map);

	return true;
}

void StartGame()
{
	if (strlen(sGameConfig) == 0 || StrEqual(sGameConfig, "player_preferred"))
	{
		CalculatePreferredConfig(sGameConfig, sizeof(sGameConfig));
	}

	Call_StartForward(g_forwardStartGame);
	Call_PushStringEx(sGameConfig, sizeof(sGameConfig), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_Finish();

	if (ParseWaveConfig(sGameConfig))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				ResetPlayer(i);
				CancelClientMenu(i, true);
			}
		}

		char sWaveName[256];
		RetrieveConfigName(sGameConfig, sWaveName, sizeof(sWaveName));

		CPrintToChatAll("%s Game starting under the config: {white}%s", sGlobalTag, sWaveName);

		Call_StartForward(g_forwardStartGame_Post);
		Call_PushString(sGameConfig);
		Call_Finish();

		bWavePaused = false;
		PauseAllZombies(bWavePaused);

		iLastUsableWave = 1;
		StartWave(1);
	}
	else
	{
		CPrintToChatAll("%s Error starting the game, please contact an administrator. [Reason: {white}Invalid Config{gray}]", sGlobalTag);
	}
}

void ResetPlayer(int client, bool resetpoints = false)
{
	if (resetpoints)
	{
		int default_points = GetConVarInt(convar_StartingPoints);

		if (iCurrentPoints[client] < default_points)
		{
			iCurrentPoints[client] = default_points;
		}
	}

	if (GetConVarBool(convar_StripWeapons))
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
		if (!GetConVarBool(convar_EnableBuildings))
		{
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);
		}
	}

	int slot = GetPlayerWeaponSlot(client, 2);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", slot);
}

void TeleportPlayersToGame()
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "trigger_teleport")) != INVALID_ENT_INDEX)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrEqual(sName, "game_start_teleport"))
		{
			SDKHook(entity, SDKHook_StartTouch, Hook_GameStart_OnStartTouch);

			AcceptEntityInput(entity, "Enable");
			AcceptEntityInput(entity, "Disable");

			SDKUnhook(entity, SDKHook_StartTouch, Hook_GameStart_OnStartTouch);
		}
	}
}

bool ParseWaveConfig(const char[] config)
{
	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_WavesConfig, sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", sConfig, sCurrentMap, config);

	KeyValues kv = CreateKeyValues("waves_config");

	if (!FileToKeyValues(kv, sPath))
	{
		return false;
	}

	bIsEndless = view_as<bool>(KvGetNum(kv, "endless"));

	if (KvJumpToKey(kv, "zombie_spawns") && KvGotoFirstSubKey(kv, false))
	{
		iZombieSpawns = 0;

		do
		{
			if (iZombieSpawns >= MAX_ZOMBIE_SPAWNS)
			{
				continue;
			}

			char sWaveClamp[12];
			KvGetSectionName(kv, sWaveClamp, sizeof(sWaveClamp));
			iZombieSpawnWaveClamp[iZombieSpawns] = StringToInt(sWaveClamp);
			KvGetVector(kv, NULL_STRING, fZombieSpawns[iZombieSpawns]);
			iZombieSpawns++;

		} while (KvGotoNextKey(kv, false));

		KvRewind(kv);
	}

	if (KvJumpToKey(kv, "waves") && KvGotoFirstSubKey(kv, false))
	{
		ClearArray(g_hSpecialsList);

		iWavesAmount = 0;

		do
		{
			iWavesAmount++;

			if (iWavesAmount >= MAX_WAVES)
			{
				break;
			}

			bWaves_HasContents[iWavesAmount] = true;
			fWaves_Wave_Time[iWavesAmount] = KvGetFloat(kv, "wave_time");
			fWaves_Next_Wave_Time[iWavesAmount] = KvGetFloat(kv, "next_wave_time");
			bWaves_KillZombies_BetweenWaves[iWavesAmount] = KvGetBool(kv, "clear_zombies");
			bWaves_KillSpecials_BetweenWaves[iWavesAmount] = KvGetBool(kv, "clear_specials");
			KvGetString(kv, "activate_relay", sWaves_ActivateRelay[iWavesAmount], 256);
			iWaves_Starting_Wave_Spawns[iWavesAmount] = KvGetInt(kv, "starting_wave_spawn");
			fWaves_Zombie_Spawns_Timer[iWavesAmount] = KvGetFloat(kv, "zombie_spawns_timer");
			iWaves_Zombie_Spawns_Increment[iWavesAmount] = KvGetInt(kv, "zombie_spawns_increments");
			bWaves_Zombie_Outlines[iWavesAmount] = KvGetBool(kv, "zombies_glow");
			bWaves_Zombie_Gnomes[iWavesAmount] = KvGetBool(kv, "zombie_gnomes");
			fWaves_Zombie_BaseSpeed[iWavesAmount] = KvGetFloat(kv, "zombie_speed", -1.0);
			iWaves_Zombie_BaseHealth[iWavesAmount] = KvGetInt(kv, "zombie_health", -1);

			if (KvJumpToKey(kv, "specials") && KvGotoFirstSubKey(kv, false))
			{
				delete hWaves_Specials[iWavesAmount];
				hWaves_Specials[iWavesAmount] = CreateTrie();

				do
				{
					char sSpecial[MAX_NAME_LENGTH];
					KvGetSectionName(kv, sSpecial, sizeof(sSpecial));

					int iSpecials_Amount = KvGetNum(kv, NULL_STRING);

					SetTrieValue(hWaves_Specials[iWavesAmount], sSpecial, iSpecials_Amount);

					if (FindStringInArray(g_hSpecialsList, sSpecial) == INVALID_ARRAY_INDEX)
					{
						PushArrayString(g_hSpecialsList, sSpecial);
					}
				}
				while (KvGotoNextKey(kv, false));

				KvGoBack(kv);
				KvGoBack(kv);
			}

			//Planks
			iWaves_Planks_Health[iWavesAmount] = KvGetInt(kv, "planks_health", TF2Undead_Planks_GetDataValue("planks_health"));
			iWaves_Planks_Cost[iWavesAmount] = KvGetInt(kv, "planks_cost", TF2Undead_Planks_GetDataValue("planks_cost"));
			iWaves_Planks_Max_Per_Round[iWavesAmount] = KvGetInt(kv, "planks_max_per_round", TF2Undead_Planks_GetDataValue("planks_max_per_round"));
			fWaves_Planks_Rebuild_Cooldown[iWavesAmount] = KvGetFloat(kv, "planks_rebuild_cooldown", TF2Undead_Planks_GetDataValue("planks_rebuild_cooldown"));
			fWaves_Planks_Respawn[iWavesAmount] = KvGetFloat(kv, "planks_respawn", TF2Undead_Planks_GetDataValue("planks_respawn"));

		} while (KvGotoNextKey(kv, false));
	}

	return true;
}

void StartWave(int wave)
{
	Call_StartForward(g_forwardWaveStart);
	Call_PushCell(wave);
	Call_Finish();

	int use = wave;

	if (bIsEndless)
	{
		if (bWaves_HasContents[wave])
		{
			iLastUsableWave = wave;
		}
		else
		{
			use = iLastUsableWave;
		}

		CPrintToChatAll("%s WAVE: {white}%i{gray}/{white}∞", sGlobalTag, wave);
	}
	else
	{
		CPrintToChatAll("%s WAVE: {white}%i{gray}/{white}%i", sGlobalTag, wave, iWavesAmount);
	}

	TeleportPlayersToGame();
	EmitSoundToAll("tf2undead/round_start.wav");

	bZombieOutlines = bWaves_Zombie_Outlines[use];
	bZombieGnomes = bWaves_Zombie_Gnomes[use];
	fZombieSpeed = fWaves_Zombie_BaseSpeed[use];// * GetClientCount(true);
	iZombieHealth = iWaves_Zombie_BaseHealth[use];// * GetClientCount(true);

	SpawnZombies(iWaves_Starting_Wave_Spawns[use]/* * GetClientCount(true)*/, use);

	//Planks
	TF2Undead_Planks_SetDataValue("planks_health", iWaves_Planks_Health[use]);
	TF2Undead_Planks_SetDataValue("planks_cost", iWaves_Planks_Cost[use]);
	TF2Undead_Planks_SetDataValue("planks_max_per_round", iWaves_Planks_Max_Per_Round[use]);
	TF2Undead_Planks_SetDataValue("planks_rebuild_cooldown", fWaves_Planks_Rebuild_Cooldown[use]);
	TF2Undead_Planks_SetDataValue("planks_respawn", fWaves_Planks_Respawn[use]);

	//Zombie Horde Timer
	float fSpawnZombies = fWaves_Zombie_Spawns_Timer[use];

	if (fSpawnZombies <= 0.0)
	{
		fSpawnZombies = 2.0;
	}

	KillTimerSafe(hSpawnZombiesTimer);
	hSpawnZombiesTimer = CreateTimer(fSpawnZombies, Timer_SpawnZombies, use, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	fWaveTime = fWaves_Wave_Time[use];

	if (fWaveTime <= 0.0)
	{
		fWaveTime = 60.0;
	}

	KillTimerSafe(hWaveTimer);
	hWaveTimer = CreateTimer(1.0, Timer_WaveTimer, use, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	CalculateScheduledSpecials(use);

	Call_StartForward(g_forwardWaveStart_Post);
	Call_PushCell(wave);
	Call_Finish();
}

void CalculateScheduledSpecials(int wave)
{
	if (hWaves_Specials[wave] == null)
	{
		return;
	}

	for (int i = 0; i < GetArraySize(g_hSpecialsList); i++)
	{
		char sName[MAX_NAME_LENGTH];
		GetArrayString(g_hSpecialsList, i, sName, sizeof(sName));

		int amount;
		if (GetTrieValue(hWaves_Specials[wave], sName, amount) && amount > 0)
		{
			for (int x = 0; x < amount; x++)
			{
				TF2Undead_Specials_ScheduleSpawn(sName, fZombieSpawns[GetRandomInt(0, iZombieSpawns - 1)]);
			}
		}
	}
}

public Action Timer_WaveTimer(Handle timer, any data)
{
	int wave = data;

	char sMaxWaves[12];
	IntToString(iWavesAmount, sMaxWaves, sizeof(sMaxWaves));

	char sBuffer[512];
	FormatEx(sBuffer, sizeof(sBuffer), "Wave %i/%s: ", wave, bIsEndless ? "∞" : sMaxWaves);
	ShowTimerHudToAll(sBuffer, fWaveTime, bWavePaused);

	if (bWavePaused)
	{
		return Plugin_Continue;
	}

	fWaveTime--;

	if (fWaveTime > 0.0)
	{
		return Plugin_Continue;
	}

	int next_wave = wave + 1;

	if (bWaves_KillZombies_BetweenWaves[wave])
	{
		TF2Undead_Zombies_KillAllZombies();
	}

	if (bWaves_KillSpecials_BetweenWaves[wave])
	{
		TF2Undead_Specials_KillAllSpecials();
	}

	Call_StartForward(g_forwardWaveEnd);
	Call_PushCell(wave);
	Call_PushCell(next_wave);
	Call_Finish();

	if (strlen(sWaves_ActivateRelay[next_wave]) > 0)
	{
		TriggerRelay(sWaves_ActivateRelay[next_wave]);
	}

	KillTimerSafe(hSpawnZombiesTimer);
	KillTimerSafe(hNextWaveTimer);

	if (!bIsEndless && next_wave > iWavesAmount)
	{
		EndRoundMoveToLobby(true);

		hWaveTimer = null;
		return Plugin_Stop;
	}

	TeleportPlayersToGame();

	EmitSoundToAll("tf2undead/round_end.wav");
	CPrintToChatAll("%s Wave {white}%i {gray}has ended! Wave {white}%i {gray}starting in {white}%.0f {gray}seconds...", sGlobalTag, wave, next_wave, fWaves_Next_Wave_Time[wave]);

	fWaveEndTime = fWaves_Next_Wave_Time[wave];

	if (fWaveEndTime < 0.1)
	{
		fWaveEndTime = 0.1;
	}

	KillTimerSafe(hNextWaveTimer);
	hNextWaveTimer = CreateTimer(1.0, Timer_NextWaveTimer, wave, TIMER_REPEAT);

	Call_StartForward(g_forwardWaveEnd_Post);
	Call_PushCell(wave);
	Call_PushCell(next_wave);
	Call_PushCell(bWaves_KillZombies_BetweenWaves[wave]);
	Call_PushCell(bWaves_KillSpecials_BetweenWaves[wave]);
	Call_Finish();

	hWaveTimer = null;
	return Plugin_Stop;
}

void ShowTimerHudToAll(const char[] prefix, float show, bool paused)
{
	char sWaveName[256];
	RetrieveConfigName(sGameConfig, sWaveName, sizeof(sWaveName));

	SetHudTextParams(0.25, 0.98, 99999.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			//ShowSyncHudText(i, g_hHud_Timer, "Points: %i\n%s%02d:%02d", iCurrentPoints[i], prefix, RoundFloat(show) / 60, RoundFloat(show) % 60);
			PrintHintText(i, "Points: %i - %s%02d:%02d - %s%s", iCurrentPoints[i], prefix, RoundFloat(show) / 60, RoundFloat(show) % 60, sWaveName, paused ? " (Paused)" : "");
			StopSound(i, SNDCHAN_STATIC, "UI/hint.wav");
		}
	}
}

void SpawnZombies(int iAmount = -1, int wave = -1)
{
	if (iAmount == -1)
	{
		iAmount = GetConVarInt(convar_DefaultStartZombiesPerWave);
	}

	if (iAmount >= iZombieSpawns)
	{
		SpawnAllZombies();
		return;
	}

	int cache = iAmount;
	bool[] bSpawned = new bool[iZombieSpawns + 1];

	while (cache > 0)
	{
		int random_spawn = GetRandomInt(0, iZombieSpawns - 1);

		if (bSpawned[random_spawn] || wave != -1 && iZombieSpawnWaveClamp[random_spawn] > wave)
		{
			continue;
		}

		int entity = TF2Undead_Zombies_Spawn(fZombieSpawns[random_spawn], NULL_VECTOR, -1, iZombieHealth, fZombieSpeed, -1.0, -1.0, {255, 255, 255, 255}, "", "tf2undead/noises/undead_zombie_death_explode.wav");

		if (IsValidEntity(entity))
		{
			bSpawned[random_spawn] = true;
			cache--;
		}
	}
}

void SpawnAllZombies()
{
	for (int i = 0; i < iZombieSpawns; i++)
	{
		TF2Undead_Zombies_Spawn(fZombieSpawns[i], NULL_VECTOR, -1, iZombieHealth, fZombieSpeed, -1.0, -1.0, {255, 255, 255, 255}, "", "tf2undead/noises/undead_zombie_death_explode.wav");
	}
}

void StartLobby()
{
	fLobbyTime = GetConVarFloat(convar_Lobby_Time);

	if (fLobbyTime > 0.0)
	{
		KillTimerSafe(hLobbyTimer);
		hLobbyTimer = CreateTimer(1.0, Timer_DisplayLobbyHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}

	GetConVarString(convar_Wave_Default_Config, sGameConfig, sizeof(sGameConfig));

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OpenLobbyMenu(i);
		}
	}

	if (GetConVarBool(convar_CreepyLobbyNoises))
	{
		Handle timer_loop = CreateTimer(36.0, Timer_LobbySound, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		TriggerTimer(timer_loop);
	}
}

void EndRoundMoveToLobby(bool bWin)
{
	char sTeam[12];
	GetConVarString(convar_Player_Team, sTeam, sizeof(sTeam));
	TFTeam team = GetTeamID(sTeam);

	if (bWin)
	{
		CPrintToChatAll("%s Survivors have won the round, they get to keep their points.", sGlobalTag);
	}

	TF2_ForceRoundWin(bWin ? team : GetEnemyTeamID(sTeam));
	EmitSoundToAll(bWin ? "tf2undead/game_win.wav" : "tf2undead/game_lose.wav");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == team)
		{
			switch (bWin)
			{
			case true:
				{
					if (g_bPlaying[i])
					{
						if (IsPlayerAlive(i))
						{
							TF2_SetPlayerPowerPlay(i, true);
						}
					}
					else
					{
						iCurrentPoints[i] = GetConVarInt(convar_StartingPoints);
					}
				}
			case false: iCurrentPoints[i] = GetConVarInt(convar_StartingPoints);
			}
		}
	}
}

void TriggerRelay(const char[] name)
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "logic_relay")) != INVALID_ENT_INDEX)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrEqual(sName, name))
		{
			AcceptEntityInput(entity, "Trigger");
		}
	}
}

bool RetrieveConfigName(const char[] config, char[] name, int size)
{
	if (strlen(config) == 0)
	{
		return false;
	}

	if (StrEqual(config, "player_preferred"))
	{
		strcopy(name, size, "Player Preferred");
		return true;
	}

	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_WavesConfig, sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", sConfig, sCurrentMap, config);

	KeyValues kv = CreateKeyValues("waves_config");

	if (!FileToKeyValues(kv, sPath))
	{
		CloseHandle(kv);
		return false;
	}

	KvGetString(kv, "name", name, size);
	CloseHandle(kv);
	return true;
}

void GetEnemyTeamInfo(const char[] team, char[] enemy, int size)
{
	if (strlen(team) > 0)
	{
		strcopy(enemy, size, StrEqual(team, "red") ? "blue" : "red");
	}
}

TFTeam GetTeamID(const char[] team)
{
	return StrEqual(team, "red") ? TFTeam_Red : TFTeam_Blue;
}

TFTeam GetEnemyTeamID(const char[] team)
{
	return StrEqual(team, "red") ? TFTeam_Blue : TFTeam_Red;
}

/*void ClearTimerHud()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ClearSyncHud(i, g_hHud_Timer);
		}
	}
}*/

void UpdateClientPoints(int client, int target, ePointsModifier modifier, int value, bool bShowMessage = false)
{
	if (target == 0 || target > MaxClients || !IsClientInGame(target))
	{
		return;
	}

	char sModifier[64];
	switch (modifier)
	{
	case Add:
		{
			iCurrentPoints[target] +=  value;
			strcopy(sModifier, sizeof(sModifier), "been given");
		}
	case Subtract:
		{
			iCurrentPoints[target] -=  value;
			strcopy(sModifier, sizeof(sModifier), "been deducted");
		}
	case Multiply:
		{
			iCurrentPoints[target] *=  value;
			strcopy(sModifier, sizeof(sModifier), "had your points multiplied by");
		}
	case Divide:
		{
			iCurrentPoints[target] /=  value;
			strcopy(sModifier, sizeof(sModifier), "had your points divided by");
		}
	case Set:
		{
			iCurrentPoints[target]  =  value;
			strcopy(sModifier, sizeof(sModifier), "had your points set to");
		}
	}

	if (iCurrentPoints[target] < 0)
	{
		iCurrentPoints[target] = 0;
	}

	if (bShowMessage)
	{
		char sBy[128];
		Format(sBy, sizeof(sBy), " by {white}%N", client);

		CPrintToChat(target, "%s You have %s {white}%i {gray}points%s{gray}.", sGlobalTag, sModifier, value, client > -1 ? sBy : "");
	}

	if (client > -1)
	{
		LogAction(client, target, "%s %N updated points for %N. (Points: %i)", sGlobalTag, client, target, value);
	}
}

bool PlayersPlaying()
{
	char sTeam[12];
	GetConVarString(convar_Player_Team, sTeam, sizeof(sTeam));
	TFTeam team = GetTeamID(sTeam);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == team && g_bPlaying[i])
		{
			return true;
		}
	}

	return false;
}

void ShowInformationMenu(int client)
{
	Panel panel = CreatePanel();

	DrawPanelText(panel, "This mod is based on the original mode for Call of Duty: World at War.");
	DrawPanelText(panel, "Zombies spawn in the gamemode in waves and you must defeat them and survive.");
	DrawPanelText(panel, "Special zombies spawn throughout the gamemode that can do great amounts of damage.");
	DrawPanelText(panel, "You can purchase weapons off the wall and in the weapons box, prices will be marked.");
	DrawPanelText(panel, "===");
	DrawPanelText(panel, "Press 'E' or the MEDIC! button to interact with everything on the map.");
	DrawPanelText(panel, "Press and hold right click on the mouse to revive players who are down.");
	DrawPanelItem(panel, "Back");

	SendPanelToClient(panel, client, Panel_Information, MENU_TIME_FOREVER);
	CloseHandle(panel);
}

public int Panel_Information(Menu menu, MenuAction action, int param1, int param2)
{
	OpenLobbyMenu(param1);
}

/**********************************************************************************************************************/
//Natives

public int Native_IsInLobby(Handle plugin, int numParams)
{
	return fLobbyTime > 0.0;
}

public int Native_IsWavePaused(Handle plugin, int numParams)
{
	return bWavePaused;
}

public int Native_GetClientPoints(Handle plugin, int numParams)
{
	return iCurrentPoints[GetNativeCell(1)];
}

public int Native_UpdateClientPoints(Handle plugin, int numParams)
{
	UpdateClientPoints(GetNativeCell(1), GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), false);
}

public int Native_AddClientPoints(Handle plugin, int numParams)
{
	UpdateClientPoints(GetNativeCell(1), GetNativeCell(1), Add, GetNativeCell(3), false);
}

public int Native_SubtractClientPoints(Handle plugin, int numParams)
{
	UpdateClientPoints(GetNativeCell(1), GetNativeCell(1), Subtract, GetNativeCell(3), false);
}

public int Native_MultiplyClientPoints(Handle plugin, int numParams)
{
	UpdateClientPoints(GetNativeCell(1), GetNativeCell(1), Multiply, GetNativeCell(3), false);
}

public int Native_DivideClientPoints(Handle plugin, int numParams)
{
	UpdateClientPoints(GetNativeCell(1), GetNativeCell(1), Divide, GetNativeCell(3), false);
}

public int Native_SetClientPoints(Handle plugin, int numParams)
{
	UpdateClientPoints(GetNativeCell(1), GetNativeCell(1), Set, GetNativeCell(3), false);
}
