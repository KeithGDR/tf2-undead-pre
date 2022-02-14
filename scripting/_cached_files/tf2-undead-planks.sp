/**********************************************************************************************************************/
//Headers

//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-hud>
#include <tf2-undead/tf2-undead-zombies>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Default_Health;
ConVar convar_Default_Cost;
ConVar convar_Default_MaxPerRound;
ConVar convar_Default_RebuildCooldown;
ConVar convar_Default_Respawn;
ConVar convar_PlankZombieDistance;
ConVar convar_PlankPlayerDistance;

//Forwards
Handle hForward_OnPlankRebuilt_Post;

//Globals
bool g_bLate;
StringMap g_hTrie_DataValues;

float g_fCooldown[MAX_ENTITY_LIMIT + 1];

//Players
int iNearPlank[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
int g_iPlanksRebuilt[MAXPLAYERS + 1];

//Zombies
int g_iFrozenBy[MAX_ENTITY_LIMIT + 1] = {INVALID_ENT_REFERENCE, ...};
Handle g_hSDKAddGesture;
Handle g_hSDKIsPlayingGesture;
Handle g_hSDKLookupActivity;

//Global Variables
char sSound_Purchase[] = "mvm/mvm_bought_upgrade.wav";
char sSound_Denied[] = "replay/cameracontrolerror.wav";

/**********************************************************************************************************************/
//Plugin Information

public Plugin myinfo =
{
	name = "TF2 Undead - Planks",
	author = "Keith Warren (Drixevel)",
	description = "Planks module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.drixevel.com/"
};

/**********************************************************************************************************************/
//Global Functions

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-planks");

	CreateNative("TF2Undead_Planks_GetDataValue", Native_GetDataValue);
	CreateNative("TF2Undead_Planks_SetDataValue", Native_SetDataValue);

	hForward_OnPlankRebuilt_Post = CreateGlobalForward("TF2Undead_OnPlankRebuilt_Post", ET_Ignore, Param_Cell, Param_Cell);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Default_Health = CreateConVar("sm_undead_planks_default_health", "500");
	convar_Default_Cost = CreateConVar("sm_undead_planks_default_cost", "75");
	convar_Default_MaxPerRound = CreateConVar("sm_undead_planks_default_max_per_round", "25");
	convar_Default_RebuildCooldown = CreateConVar("sm_undead_planks_default_rebuild_cooldown", "15.0");
	convar_Default_Respawn = CreateConVar("sm_undead_planks_default_respawn", "0.0");
	convar_PlankZombieDistance = CreateConVar("sm_undead_planks_zombie_distance", "120.0");
	convar_PlankPlayerDistance = CreateConVar("sm_undead_planks_player_distance", "120.0");

	RegAdminCmd("sm_rebuildplanks", Command_RebuildPlanks, ADMFLAG_SLAY, "Rebuild all planks on the map.");
	RegAdminCmd("sm_destroyplanks", Command_DestroyPlanks, ADMFLAG_SLAY, "Destroy all planks on the map.");

	g_hTrie_DataValues = CreateTrie();

	Handle hConf = LoadGameConfigFile("tf2.undead");

	if (hConf != null)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::AddGesture");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		g_hSDKAddGesture = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::IsPlayingGesture");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		g_hSDKIsPlayingGesture = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupActivity");
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		g_hSDKLookupActivity = EndPrepSDKCall();

		delete hConf;
	}

	AddCommandListener(Listener_VoiceMenu, "voicemenu");
	CreateTimer(0.1, Timer_ProcessPlanks, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	DestroyAllPlanks();
}

public void OnMapStart()
{
	PrecacheSound(sSound_Purchase);
	PrecacheSound(sSound_Denied);

	PrecacheSound("physics/wood/wood_crate_break4.wav");
}

public void OnConfigsExecuted()
{
	SetDataValue("planks_health", GetConVarInt(convar_Default_Health));
	SetDataValue("planks_cost", GetConVarInt(convar_Default_Cost));
	SetDataValue("planks_max_per_round", GetConVarInt(convar_Default_MaxPerRound));
	SetDataValue("planks_rebuild_cooldown", GetConVarFloat(convar_Default_RebuildCooldown));
	SetDataValue("planks_respawn", GetConVarFloat(convar_Default_Respawn));

	if (g_bLate)
	{
		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_INDEX)
		{
			char classname[64];
			GetEntityClassname(entity, classname, sizeof(classname));
			OnEntityCreated(entity, classname);
		}

		g_bLate = false;
	}
}

public void OnClientDisconnect(int client)
{
	g_iPlanksRebuilt[client] = 0;
}

public Action Listener_VoiceMenu(int client, const char[] command, int argc)
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	char sVoice[32];
	GetCmdArg(1, sVoice, sizeof(sVoice));

	char sVoice2[32];
	GetCmdArg(2, sVoice2, sizeof(sVoice2));

	if (StringToInt(sVoice) == 0 && StringToInt(sVoice2) == 0 && RebuildPlank(client))
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void OnGameFrame()
{
	if (TF2Undead_IsInLobby() || TF2Undead_IsWavePaused())
	{
		return;
	}

	float vecOrigin[3];

	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "func_brush")) != INVALID_ENT_INDEX)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrContains(sName, "wood_panel_") != -1 && GetEntProp(entity, Prop_Data, "m_iDisabled") == 0)
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
			int plank = EntRefToEntIndex(g_iFrozenBy[entity]);

			if (!IsValidEntity(plank) || GetEntProp(plank, Prop_Data, "m_iDisabled") == 1)
			{
				TF2Undead_Zombies_FreezeZombie(entity, false);
			}

			g_iFrozenBy[entity] = INVALID_ENT_REFERENCE;
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_brush"))
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrContains(sName, "wood_panel_") != -1)
		{
			SetPlankStats(entity);
		}
	}
}

/**********************************************************************************************************************/
//Commands

public Action Command_RebuildPlanks(int client, int args)
{
	RebuildAllPlanks();
	CPrintToChatAll("%s {white}%N {gray}has rebuilt all planks on the map.", sGlobalTag, client);
	return Plugin_Handled;
}

public Action Command_DestroyPlanks(int client, int args)
{
	DestroyAllPlanks();
	CPrintToChatAll("%s {white}%N {gray}has destroyed all planks on the map.", sGlobalTag, client);
	return Plugin_Handled;
}

/**********************************************************************************************************************/
//Undead Forwards

public void TF2Undead_OnStartGame_Post(const char[] wave_config)
{
	RebuildAllPlanks();

	for (int i = 1; i <= MaxClients; i++)
	{
		g_iPlanksRebuilt[i] = 0;
	}
}

public void TF2Undead_OnWaveEnd_Post(int last_wave, int next_wave, bool clear_zombies, bool clear_specials)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iPlanksRebuilt[i] = 0;
	}
}

public void TF2Undead_OnEndGame_Post(bool won)
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != INVALID_ENT_INDEX)
	{
		g_fCooldown[entity] = 0.0;
	}
}

/**********************************************************************************************************************/
//Timer Callbacks

public Action Timer_ProcessPlanks(Handle timer)
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "func_brush")) != INVALID_ENT_INDEX)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrContains(sName, "wood_panel_") != -1)
		{
			ProcessPlank(entity);
		}
	}
}

public Action Timer_RespawnPlank(Handle timer, any data)
{
	int entity = EntRefToEntIndex(data);

	if (IsValidEntity(entity))
	{
		SetPlankStats(entity);
	}
}

/**********************************************************************************************************************/
//Stock Functions

bool RebuildPlank(int client)
{
	if (TF2Undead_IsInLobby() || !IsPlayerAlive(client) || iNearPlank[client] == INVALID_ENT_REFERENCE)
	{
		return false;
	}

	int entity = EntRefToEntIndex(iNearPlank[client]);

	if (!IsValidEntity(entity))
	{
		return false;
	}

	if (TF2Undead_IsWavePaused() && !CheckCommandAccess(client, "", ADMFLAG_ROOT))
	{
		CPrintToChat(client, "%s The wave is currently paused!", sGlobalTag);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	int max = GetDataValue("planks_max_per_round");
	if (g_iPlanksRebuilt[client] > max)
	{
		CPrintToChat(client, "%s You have reached the maximum amount of planks purchased this round. ({white}%i{gray})", sGlobalTag, max);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	if (GetGameTime() - g_fCooldown[entity] <= GetDataValue("planks_rebuild_cooldown"))
	{
		CPrintToChat(client, "%s The nearest plank cannot be rebuilt at this time.", sGlobalTag);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	int cost = GetDataValue("planks_cost");
	if (cost > 0 && cost > TF2Undead_GetClientPoints(client))
	{
		int display = cost - TF2Undead_GetClientPoints(client);
		CPrintToChat(client, "%s You need {white}%i {gray}more points to rebuild the nearest plank.", sGlobalTag, display);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}
	else if (cost <= 0)
	{
		int display = cost > 0 ? cost : -cost;
		CPrintToChat(client, "%s You have be given {white}%i {gray}points for rebuilding the nearest plank.", sGlobalTag, display);
	}

	//CPrintToChat(client, "%s You rebuilt the nearest plank!", sGlobalTag);
	CPrintToChatAll("%s {white}%N {gray}has rebuilt a plank near them!", sGlobalTag, client);
	PrintCenterText(client, "Plank rebuilt!");

	EmitSoundToClient(client, sSound_Purchase);
	TF2Undead_UpdateClientPoints(client, Subtract, cost);

	SetPlankStats(entity);

	iNearPlank[client] = INVALID_ENT_REFERENCE;
	g_iPlanksRebuilt[client]++;
	g_fCooldown[entity] = GetGameTime();

	Call_StartForward(hForward_OnPlankRebuilt_Post);
	Call_PushCell(client);
	Call_PushCell(entity);
	Call_Finish();

	return true;
}

void ProcessPlank(int entity)
{
	if (!IsValidEntity(entity) || GetEntProp(entity, Prop_Data, "m_iDisabled") == 0)
	{
		return;
	}

	float fEntityOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEntityOrigin);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) < 1)
		{
			continue;
		}

		float fOrigin[3];
		GetClientAbsOrigin(i, fOrigin);

		if (GetVectorDistance(fEntityOrigin, fOrigin) > GetConVarFloat(convar_PlankPlayerDistance))
		{
			if (iNearPlank[i] == EntIndexToEntRef(entity))
			{
				TF2Undead_Hud_ClearPurchaseHud(i);
				iNearPlank[i] = INVALID_ENT_REFERENCE;
			}

			continue;
		}

		NearPlank(i, entity);
	}
}

void NearPlank(int client, int entity)
{
	int cost = GetDataValue("planks_cost");

	iNearPlank[client] = EntIndexToEntRef(entity);
	TF2Undead_Hud_ShowPurchaseHud(client, "Press 'E' to rebuild this plank", cost > 0 ? cost : 0);
}

void ScanForZombies(int plank, float plank_origin[3])
{
	float vecZombieOrigin[3];

	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecZombieOrigin);

		if (GetVectorDistance(plank_origin, vecZombieOrigin) <= GetConVarFloat(convar_PlankZombieDistance))
		{
			TF2Undead_Zombies_FreezeZombie(entity, true);
			g_iFrozenBy[entity] = EntIndexToEntRef(plank);

			int health = GetEntProp(plank, Prop_Data, "m_iHealth");

			if (health <= 0)
			{
				AcceptEntityInput(plank, "Disable");

				float respawn = GetDataValue("planks_respawn");
				if (respawn > 0.0)
				{
					CreateTimer(respawn, Timer_RespawnPlank, EntIndexToEntRef(plank), TIMER_FLAG_NO_MAPCHANGE);
				}

				continue;
			}

			SetEntProp(plank, Prop_Data, "m_iHealth", health - 1);

			//1257
			//ACT_MP_COMPETITIVE_WINNERSTATE
			//idk just go through the activities tab in hammer for the skeleton
			int gesture = SDKCall(g_hSDKLookupActivity, entity, "ACT_MP_ATTACK_STAND_MELEE");

			if (gesture >= 0 && !SDKCall(g_hSDKIsPlayingGesture, entity, gesture))
			{
				SDKCall(g_hSDKAddGesture, entity, gesture, true);
				EmitGameSoundToAll("Breakable.Crate", plank);
			}
		}
	}
}

void RebuildAllPlanks()
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "func_brush")) != INVALID_ENT_INDEX)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrContains(sName, "wood_panel_") != -1)
		{
			SetPlankStats(entity);
		}
	}
}

void SetPlankStats(int entity)
{
	SetEntProp(entity, Prop_Data, "m_iHealth", GetDataValue("planks_health"));
	SetEntProp(entity, Prop_Data, "m_iDisabled", 0);

	AcceptEntityInput(entity, "Enable");
	g_fCooldown[entity] = 0.0;
}

void DestroyAllPlanks()
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "func_brush")) != INVALID_ENT_INDEX)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrContains(sName, "wood_panel_") != -1)
		{
			SetEntProp(entity, Prop_Data, "m_iDisabled", 1);
			AcceptEntityInput(entity, "Disable");
		}
	}
}

any GetDataValue(const char[] key)
{
	any value;
	GetTrieValue(g_hTrie_DataValues, key, value);

	return value;
}

void SetDataValue(const char[] key, any value)
{
	SetTrieValue(g_hTrie_DataValues, key, value);
}

/**********************************************************************************************************************/
//Natives

public int Native_GetDataValue(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sKey = new char[size + 1];
	GetNativeString(1, sKey, size + 1);

	return GetDataValue(sKey);
}

public int Native_SetDataValue(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sKey = new char[size + 1];
	GetNativeString(1, sKey, size + 1);

	SetDataValue(sKey, GetNativeCell(2));
}
