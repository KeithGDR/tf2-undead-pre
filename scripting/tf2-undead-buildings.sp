//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define INVALID_BUILDING_ID -1
#define MAX_BUILDINGS 256

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>

////External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2-undead/tf2-undead-buildings>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-hud>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_Distance_Usage;
ConVar convar_DefaultBuildingGlow;

//Forwards
Handle hForward_OnBuildingSpawn_Post;
Handle hForward_OnBuildingPurchased_Post;

//Globals
char sCurrentMap[MAX_MAP_NAME_LENGTH];
bool bLate;

//Global Variables
char sSound_Purchase[] = "mvm/mvm_bought_upgrade.wav";
char sSound_Denied[] = "replay/cameracontrolerror.wav";

//Buildings
float fBuilding_Coordinates[MAX_BUILDINGS][3];
float fBuilding_Angles[MAX_BUILDINGS][3];
char sBuilding_Entity[MAX_BUILDINGS][MAX_NAME_LENGTH];
int iBuilding_Level[MAX_BUILDINGS];
float fBuilding_Duration[MAX_BUILDINGS];
int iBuilding_Recharge[MAX_BUILDINGS];
int iBuilding_Required[MAX_BUILDINGS];
int iBuildingsTotal;

int iBuildingTemplate[MAX_BUILDINGS] = {INVALID_ENT_REFERENCE, ...};
int iBuildingRecharge[MAX_BUILDINGS];
int iNearBuilding[MAXPLAYERS + 1] = {INVALID_BUILDING_ID, ...};

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - Buildings",
	author = "Keith Warren (Shaders Allen)",
	description = "Buildings module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-buildings");

	hForward_OnBuildingSpawn_Post = CreateGlobalForward("TF2Undead_OnBuildingSpawn_Post", ET_Ignore, Param_Cell, Param_Array, Param_Array, Param_String);
	hForward_OnBuildingPurchased_Post = CreateGlobalForward("TF2Undead_OnBuildingPurchased_Post", ET_Ignore, Param_Cell);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_buildings_status", "1");
	convar_Config = CreateConVar("sm_undead_buildings_config", "configs/undead/buildings/%s.cfg");
	convar_Distance_Usage = CreateConVar("sm_undead_buildings_distance_usage", "100.0");
	convar_DefaultBuildingGlow = CreateConVar("sm_undead_buildings_default_glow", "244 170 66 100");

	RegAdminCmd("sm_respawnbuildings", Command_RespawnBuildings, ADMFLAG_ROOT, "Respawn all buildings on the map.");

	AddCommandListener(Listener_VoiceMenu, "voicemenu");
	CreateTimer(0.1, Timer_ProcessBuildings, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	GetMapName(sCurrentMap, sizeof(sCurrentMap));

	PrecacheSound(sSound_Purchase);
	PrecacheSound(sSound_Denied);
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_Config, sConfig, sizeof(sConfig));
	iBuildingsTotal = ParseBuildingsConfig(sConfig);

	if (bLate)
	{
		if (!TF2Undead_IsInLobby())
		{
			SpawnBuildings();
		}

		bLate = false;
	}
}

public void OnPluginEnd()
{
	ClearAllBuildings();
}

public Action Listener_VoiceMenu(int client, const char[] command, int argc)
{
	if (!GetConVarBool(convar_Status) || client == 0 || client > MaxClients || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	char sVoice[32];
	GetCmdArg(1, sVoice, sizeof(sVoice));

	char sVoice2[32];
	GetCmdArg(2, sVoice2, sizeof(sVoice2));

	if (StringToInt(sVoice) == 0 && StringToInt(sVoice2) == 0 && PurchaseBuilding(client))
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Command_RespawnBuildings(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	if (TF2Undead_IsInLobby())
	{
		CReplyToCommand(client, "%s You cannot respawn the buildings during the lobby phase.", sGlobalTag);
		return Plugin_Handled;
	}

	ClearAllBuildings();

	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_Config, sConfig, sizeof(sConfig));

	iBuildingsTotal = ParseBuildingsConfig(sConfig);

	SpawnBuildings();

	return Plugin_Handled;
}

public void TF2Undead_OnStartGame_Post(const char[] wave_config)
{
	if (GetConVarBool(convar_Status))
	{
		SpawnBuildings();
	}
}

public void TF2Undead_OnEndGame_Post()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	ClearAllBuildings();
}

void SpawnBuildings()
{
	for (int i = 0; i < iBuildingsTotal; i++)
	{
		int entity = SpawnBuilding(i, fBuilding_Coordinates[i], fBuilding_Angles[i], sBuilding_Entity[i], iBuilding_Level[i]);

		if (IsValidEntity(entity))
		{
			Call_StartForward(hForward_OnBuildingSpawn_Post);
			Call_PushCell(entity);
			Call_PushArray(fBuilding_Coordinates[i], 3);
			Call_PushArray(fBuilding_Angles[i], 3);
			Call_PushString(sBuilding_Entity[i]);
			Call_Finish();
		}
	}
}

void ClearAllBuildings()
{
	for (int i = 0; i < iBuildingsTotal; i++)
	{
		if (iBuildingTemplate[i] != INVALID_ENT_REFERENCE)
		{
			int entity = EntRefToEntIndex(iBuildingTemplate[i]);
			if (IsValidEntity(entity))
			{
				AcceptEntityInput(entity, "Kill");
			}

			iBuildingTemplate[i] = INVALID_ENT_REFERENCE;
			iBuildingRecharge[i] = 0;
		}
	}
}

int SpawnBuilding(int building, const float coordinates[3], const float angles[3], const char[] entity_name, int level)
{
	int entity = CreateEntityByName(entity_name);

	if (IsValidEntity(entity))
	{
		char sDefault[12];
		IntToString(level - 1, sDefault, sizeof(sDefault));

		DispatchKeyValueVector(entity, "origin", coordinates);
		DispatchKeyValueVector(entity, "angles", angles);
		DispatchKeyValue(entity, "defaultupgrade", sDefault);

		if (StrEqual(entity_name, "obj_sentrygun"))
		{
			SetEntProp(entity, Prop_Send, "m_bDisposableBuilding", 1);
			SetEntProp(entity, Prop_Send, "m_iUpgradeLevel", level);
			SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
			SetEntProp(entity, Prop_Data, "m_spawnflags", 4);
			SetEntProp(entity, Prop_Send, "m_bBuilding", 1);

			DispatchSpawn(entity);

			SetVariantInt(3);
			AcceptEntityInput(entity, "SetTeam");
			SetEntProp(entity, Prop_Send, "m_nSkin", 1);

			ActivateEntity(entity);
		}
		else if (StrEqual(entity_name, "obj_dispenser"))
		{
			SetEntProp(entity, Prop_Send, "m_bDisposableBuilding", 1);
			SetEntProp(entity, Prop_Send, "m_iHighestUpgradeLevel", level);
			SetEntProp(entity, Prop_Data, "m_spawnflags", 4);
			SetEntProp(entity, Prop_Send, "m_bBuilding", 1);

			DispatchSpawn(entity);

			SetVariantInt(3);
			AcceptEntityInput(entity, "SetTeam");
			SetEntProp(entity, Prop_Send, "m_nSkin", 1);

			ActivateEntity(entity);
		}

		SDKHook(entity, SDKHook_OnTakeDamage, OnBuildingTakeDamage);

		//AcceptEntityInput(entity, "Disable");
		SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
		iBuildingTemplate[building] = EntIndexToEntRef(entity);

		int color[4]; color = GetConVarColor(convar_DefaultBuildingGlow);
		TF2_CreateGlow("building_glow", entity, color);
	}

	return entity;
}

public Action OnBuildingTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	damage = 0.0;
	return Plugin_Changed;
}

public Action Timer_ProcessBuildings(Handle timer)
{
	for (int i = 0; i < iBuildingsTotal; i++)
	{
		if (iBuildingTemplate[i] != INVALID_ENT_REFERENCE)
		{
			ProcessBuilding(i, EntRefToEntIndex(iBuildingTemplate[i]));
		}
	}
}

void ProcessBuilding(int id, int entity)
{
	if (!IsValidEntity(entity))
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

		if (GetVectorDistance(fEntityOrigin, fOrigin) > GetConVarFloat(convar_Distance_Usage))
		{
			if (iNearBuilding[i] == id)
			{
				TF2Undead_Hud_ClearPurchaseHud(i);
				iNearBuilding[i] = INVALID_BUILDING_ID;
			}

			continue;
		}

		NearBuilding(i, id);
	}
}

void NearBuilding(int client, int building)
{
	iNearBuilding[client] = building;
	TF2Undead_Hud_ShowPurchaseHud(client, "Press 'E' to purchase this building", iBuilding_Required[building]);
}

bool PurchaseBuilding(int client)
{
	if (TF2Undead_IsInLobby() || !IsPlayerAlive(client) || iNearBuilding[client] == INVALID_BUILDING_ID)
	{
		return false;
	}

	if (TF2Undead_IsWavePaused() && !CheckCommandAccess(client, "", ADMFLAG_ROOT))
	{
		CPrintToChat(client, "%s The wave is currently paused!", sGlobalTag);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	int building = iNearBuilding[client];

	if (iBuilding_Required[building] > TF2Undead_GetClientPoints(client))
	{
		int display = iBuilding_Required[building] - TF2Undead_GetClientPoints(client);
		CPrintToChat(client, "%s You need {white}%i {gray}more points to purchase this building.", sGlobalTag, display);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	int timeleft = GetTime() - iBuildingRecharge[building];
	if (timeleft <= iBuilding_Recharge[building])
	{
		int display = iBuilding_Recharge[building] - timeleft;
		CPrintToChat(client, "%s You can purchase this building again in {white}%i {gray}seconds.", sGlobalTag, display);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	int entity = EntRefToEntIndex(iBuildingTemplate[building]);

	if (IsValidEntity(entity))
	{
		if (GetEntProp(entity, Prop_Send, "m_bDisabled") == 0)
		{
			CPrintToChat(client, "%s This building is currently active.", sGlobalTag);
			EmitSoundToClient(client, sSound_Denied);
			return false;
		}

		//CPrintToChat(client, "%s You purchased this building!", sGlobalTag);
		CPrintToChatAll("%s {white}%N {gray}has purchased a building!", sGlobalTag, client);
		PrintCenterText(client, "Building Purchased!");

		EmitSoundToClient(client, sSound_Purchase);
		TF2Undead_UpdateClientPoints(client, Subtract, iBuilding_Required[building]);

		Call_StartForward(hForward_OnBuildingPurchased_Post);
		Call_PushCell(client);
		Call_Finish();

		//AcceptEntityInput(entity, "Enable");
		SetEntProp(entity, Prop_Send, "m_bDisabled", 0);
		SetEntProp(entity, Prop_Send, "m_iAmmoShells", 200);
		SetEntProp(entity, Prop_Send, "m_iAmmoRockets", 20);

		CreateTimer(fBuilding_Duration[building], Timer_DisableObject, building, TIMER_FLAG_NO_MAPCHANGE);
	}

	return true;
}

public Action Timer_DisableObject(Handle timer, any data)
{
	int building = data;

	int entity = EntRefToEntIndex(iBuildingTemplate[building]);

	if (IsValidEntity(entity))
	{
		//AcceptEntityInput(entity, "Disable");
		SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
		iBuildingRecharge[building] = GetTime();
	}
}

int ParseBuildingsConfig(const char[] config)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), config, sCurrentMap);

	KeyValues keyvalues = CreateKeyValues("buildings_config");
	int amount;

	if (FileToKeyValues(keyvalues, sPath) && KvGotoFirstSubKey(keyvalues))
	{
		do {
			KvGetVector(keyvalues, "coordinates", fBuilding_Coordinates[amount]);
			KvGetVector(keyvalues, "angles", fBuilding_Angles[amount]);
			KvGetString(keyvalues, "entity", sBuilding_Entity[amount], MAX_NAME_LENGTH);
			iBuilding_Level[amount] = KvGetNum(keyvalues, "level");
			fBuilding_Duration[amount] = KvGetFloat(keyvalues, "duration");
			iBuilding_Recharge[amount] = KvGetNum(keyvalues, "recharge");
			iBuilding_Required[amount] = KvGetNum(keyvalues, "required");

			amount++;
		}
		while (KvGotoNextKey(keyvalues));
	}

	delete keyvalues;
	return amount;
}
