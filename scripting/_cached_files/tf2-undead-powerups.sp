//Pragma
#pragma semicolon 1
#include <tf2items>
#pragma newdecls required

//Defines
#define INVALID_POWERUP_ID -1
#define MAX_POWERUPS 255

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Required Includes
#include <cw3-core-redux>

//Our Includes
#include <tf2-undead/tf2-undead-powerups>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-specials>
#include <tf2-undead/tf2-undead-zombies>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_SpawnPercent;
ConVar convar_AutoKill;
ConVar convar_SpawnParticle;
ConVar convar_SpawnSound;
ConVar convar_PickupParticle;

//Forwards
Handle g_forwardOnPowerupSpawn_Post;
Handle g_forwardOnPowerupPickup;
Handle g_forwardOnPowerupPickup_Post;

//Globals
bool g_bLate;
Handle g_hHud_Perks;

//Global Variables
char sPowerup_Name[MAX_POWERUPS][MAX_NAME_LENGTH];
char sPowerup_Model[MAX_POWERUPS][PLATFORM_MAX_PATH];
char sPowerup_PickupSound[MAX_POWERUPS][PLATFORM_MAX_PATH];
int iPowerup_Timer[MAX_POWERUPS];
bool bPowerup_Disabled[MAX_POWERUPS];
int iPowerupsAmount;

int iPowerupID[MAX_ENTITY_LIMIT + 1] = {INVALID_POWERUP_ID, ...};

int iPowerupTime;
Handle hPowerupTimer;
int g_iPowerupCooldown;
bool g_bIsSpawning;

bool bDoublePoints;
bool bInstantKill;

int iDefaultClip[MAX_ENTITY_LIMIT];
int iDefaultAmmo[MAX_ENTITY_LIMIT];

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - Powerups",
	author = "Keith Warren (Drixevel)",
	description = "Powerups module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("TF2Undead_IsInLobby");

	RegPluginLibrary("tf2-undead-powerups");

	CreateNative("TF2Undead_Powerups_IsDoublePoints", Native_IsDoublePoints);
	CreateNative("TF2Undead_Powerups_IsInstantKill", Native_IsInstantKill);

	g_forwardOnPowerupSpawn_Post = CreateGlobalForward("TF2Undead_OnPowerupSpawn_Post", ET_Event, Param_Cell, Param_Cell);
	g_forwardOnPowerupPickup = CreateGlobalForward("TF2Undead_OnPowerupPickup", ET_Event, Param_CellByRef, Param_CellByRef);
	g_forwardOnPowerupPickup_Post = CreateGlobalForward("TF2Undead_OnPowerupPickup_Post", ET_Ignore, Param_Cell, Param_Cell);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_powerups_status", "1");
	convar_Config = CreateConVar("sm_undead_powerups_config", "configs/undead/powerups.cfg");
	convar_SpawnPercent = CreateConVar("sm_undead_powerups_default_spawn_percentage", "10.0");
	convar_AutoKill = CreateConVar("sm_undead_powerups_default_autokill", "30.0");
	convar_SpawnParticle = CreateConVar("sm_undead_powerups_default_spawn_particle", "");
	convar_SpawnSound = CreateConVar("sm_undead_powerups_default_spawn_sound", "tf2undead/powerups/powerup_spawn.wav");
	convar_PickupParticle = CreateConVar("sm_undead_powerups_default_pickup_particle", "");

	RegAdminCmd("sm_powerup", Command_Powerup, ADMFLAG_ROOT);
	RegAdminCmd("sm_powerups", Command_Powerup, ADMFLAG_ROOT);

	g_hHud_Perks = CreateHudSynchronizer();
}

public void OnMapStart()
{
	//PrecacheSound("tf2undead/powerups/powerup_loop.wav");
}

public void OnMapEnd()
{
	KillTimerSafe(hPowerupTimer);
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_Config, sConfig, sizeof(sConfig));

	ParsePowerupsConfig(sConfig);

	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				for (int x = 0; x < 5; x++)
				{
					CW3_OnWeaponSpawned(GetPlayerWeaponSlot(i, x), x, i);
				}
			}
		}

		g_bLate = false;
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ClearSyncHud(i, g_hHud_Perks);
		}
	}
}

public void TF2Undead_OnWaveEnd_Post(int wave, int next_wave)
{
	ClearAllPowerups();
}

public void TF2Undead_OnEndGame_Post()
{
	ClearAllPowerups();
	KillTimerSafe(hPowerupTimer);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ClearSyncHud(i, g_hHud_Perks);
		}
	}
}

void ClearAllPowerups()
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != INVALID_ENT_INDEX)
	{
		if (iPowerupID[entity] > INVALID_POWERUP_ID)
		{
			AcceptEntityInput(entity, "Kill");
			iPowerupID[entity] = INVALID_POWERUP_ID;
		}
	}
}

void ParsePowerupsConfig(const char[] config)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), config);

	KeyValues kv = CreateKeyValues("undead_powerups");

	if (FileToKeyValues(kv, sPath) && KvGotoFirstSubKey(kv))
	{
		iPowerupsAmount = 0;

		do
		{
			KvGetSectionName(kv, sPowerup_Name[iPowerupsAmount], MAX_NAME_LENGTH);
			KvGetString(kv, "model", sPowerup_Model[iPowerupsAmount], PLATFORM_MAX_PATH);
			KvGetString(kv, "pickup_sound", sPowerup_PickupSound[iPowerupsAmount], PLATFORM_MAX_PATH);

			if (strlen(sPowerup_Model[iPowerupsAmount]) > 0)
			{
				PrecacheModel(sPowerup_Model[iPowerupsAmount]);
			}

			if (strlen(sPowerup_PickupSound[iPowerupsAmount]) > 0)
			{
				PrecacheSound(sPowerup_PickupSound[iPowerupsAmount]);
			}

			iPowerup_Timer[iPowerupsAmount] = KvGetInt(kv, "timer", 20);
			bPowerup_Disabled[iPowerupsAmount] = view_as<bool>(KvGetInt(kv, "disabled", 0));

			iPowerupsAmount++;
		}
		while(KvGotoNextKey(kv));
	}

	LogMessage("Successfully parsed '%i' powerups.", iPowerupsAmount);
	CloseHandle(kv);
}

public void OnEntityDestroyed(int entity)
{
	if (!GetConVarBool(convar_Status) || entity <= MaxClients || !IsValidEntity(entity))
	{
		return;
	}

	char sClassname[64];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	if (TF2Undead_IsInLobby() || hPowerupTimer != null || GetTime() - g_iPowerupCooldown <= 15 || g_bIsSpawning)
	{
		return;
	}

	if (StrEqual(sClassname, "tf_zombie") && iPowerupsAmount > 0 && GetRandomFloat(1.0, 100.0) <= GetConVarFloat(convar_SpawnPercent))
	{
		g_bIsSpawning = true;

		float fOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);

		fOrigin[2] += 25.0;

		SpawnRandomPowerup(fOrigin);
	}
}

void SpawnRandomPowerup(float spawn[3])
{
	if (!SpawnPowerup(GetRandomInt(0, iPowerupsAmount - 1), spawn))
	{
		SpawnRandomPowerup(spawn);
	}
}

bool SpawnPowerup(int powerup, float spawn[3])
{
	if (bPowerup_Disabled[powerup])
	{
		return false;
	}

	char sSpawnParticle[PLATFORM_MAX_PATH];
	GetConVarString(convar_SpawnParticle, sSpawnParticle, sizeof(sSpawnParticle));

	char sSpawnSound[PLATFORM_MAX_PATH];
	GetConVarString(convar_SpawnSound, sSpawnSound, sizeof(sSpawnSound));

	char sPickupParticle[PLATFORM_MAX_PATH];
	GetConVarString(convar_PickupParticle, sPickupParticle, sizeof(sPickupParticle));

	int entity = CreateEntityByName("tf_halloween_pickup");

	if (IsValidEntity(entity))
	{
		if (strlen(sSpawnParticle) > 0)
		{
			CreateTempParticle(sSpawnParticle, spawn);
		}

		if (strlen(sSpawnSound) > 0)
		{
			EmitSoundToAll(sSpawnSound, entity);
		}

		float vecAngleVelocity[3];
		vecAngleVelocity[2] += 200.0;

		DispatchKeyValue(entity, "pickup_particle", sPickupParticle);
		DispatchKeyValue(entity, "pickup_sound", sPowerup_PickupSound[powerup]);
		DispatchKeyValue(entity, "powerup_model", sPowerup_Model[powerup]);
		DispatchKeyValueVector(entity, "origin", spawn);
		DispatchKeyValueVector(entity, "basevelocity", vecAngleVelocity);
		DispatchKeyValueVector(entity, "velocity", vecAngleVelocity);

		DispatchSpawn(entity);
		SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);

		char sBuffer[128];
		FormatEx(sBuffer, sizeof(sBuffer), "OnUser1 !self:kill::%i:1", GetConVarInt(convar_AutoKill));

		SetVariantString(sBuffer);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		iPowerupID[entity] = powerup;
		SDKHook(entity, SDKHook_Touch, OnPowerupTouch);

		SetEntProp(entity, Prop_Data, "m_iEFlags", 35913728);
		SetEntProp(entity, Prop_Data, "m_MoveCollide", 1);

		//Handle trigger = CreateTimer(2.0, Timer_RepeatingSound, EntIndexToEntRef(entity), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		//TriggerTimer(trigger);

		g_iPowerupCooldown = GetTime();
		g_bIsSpawning = false;

		Call_StartForward(g_forwardOnPowerupSpawn_Post);
		Call_PushCell(entity);
		Call_PushCell(powerup);
		Call_Finish();
	}

	return true;
}

/*public Action Timer_RepeatingSound(Handle timer, any data)
{
	int entity = EntRefToEntIndex(data);

	if (IsValidEntity(entity))
	{
		EmitSoundToAll("tf2undead/powerups/powerup_loop.wav", entity, SNDCHAN_STATIC);
		return Plugin_Continue;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			StopSound(i, SNDCHAN_STATIC, "tf2undead/powerups/powerup_loop.wav");
		}
	}

	return Plugin_Stop;
}*/

public Action OnPowerupTouch(int entity, int other)
{
	int client = other;

	if (client == 0 || client > MaxClients || client == entity)
	{
		return Plugin_Continue;
	}

	AcceptEntityInput(entity, "Kill");

	/*for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			StopSound(i, SNDCHAN_STATIC, "tf2undead/powerups/powerup_loop.wav");
		}
	}*/

	EmitSoundToClient(client, "tf2undead/powerups/powerup_grab.wav", entity);

	int powerup = iPowerupID[entity];
	iPowerupID[entity] = INVALID_POWERUP_ID;

	if (strlen(sPowerup_PickupSound[powerup]) > 0)
	{
		EmitSoundToAll(sPowerup_PickupSound[powerup], entity);
	}

	CPrintToChatAll("%s {white}%N {gray}has picked up the Powerup: {white}%s", sGlobalTag, client, sPowerup_Name[powerup]);

	Call_StartForward(g_forwardOnPowerupPickup);
	Call_PushCellRef(powerup);
	Call_PushCellRef(client);
	Call_Finish();

	if (StrEqual(sPowerup_Name[powerup], "Double Points"))
	{
		bDoublePoints = true;

		iPowerupTime = iPowerup_Timer[powerup];

		if (iPowerupTime > 0)
		{
			KillTimerSafe(hPowerupTimer);
			hPowerupTimer = CreateTimer(1.0, Timer_DisableDoublePoints, _, TIMER_REPEAT);
		}
	}
	else if (StrEqual(sPowerup_Name[powerup], "Instant Kill"))
	{
		bInstantKill = true;

		iPowerupTime = iPowerup_Timer[powerup];

		if (iPowerupTime > 0)
		{
			KillTimerSafe(hPowerupTimer);
			hPowerupTimer = CreateTimer(1.0, Timer_DisableInstantKill, _, TIMER_REPEAT);
		}
	}
	else if (StrEqual(sPowerup_Name[powerup], "Nuke"))
	{
		TF2Undead_Zombies_KillAllZombies();
	}
	else if (StrEqual(sPowerup_Name[powerup], "Max Ammo"))
	{
		RestoreAllAmmo();
	}

	Call_StartForward(g_forwardOnPowerupPickup_Post);
	Call_PushCell(powerup);
	Call_PushCell(client);
	Call_Finish();

	return Plugin_Continue;
}

public Action Timer_DisableDoublePoints(Handle timer)
{
	iPowerupTime--;

	if (iPowerupTime > 0)
	{
		DisplayPerksHud("Double Points", iPowerupTime);
		return Plugin_Continue;
	}

	bDoublePoints = false;
	hPowerupTimer = null;
	return Plugin_Stop;
}

public Action Timer_DisableInstantKill(Handle timer)
{
	iPowerupTime--;

	if (iPowerupTime > 0)
	{
		DisplayPerksHud("Instant Kill", iPowerupTime);
		return Plugin_Continue;
	}

	bInstantKill = false;
	hPowerupTimer = null;
	return Plugin_Stop;
}

void DisplayPerksHud(const char[] name, int time)
{
	SetHudTextParams(-1.0, 0.7, 2.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowSyncHudText(i, g_hHud_Perks, "%s: %i seconds", name, time);
		}
	}
}

void RestoreAllAmmo()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			RefillAllWeaponsAmmo(i);
		}
	}
}

void RefillAllWeaponsAmmo(int client)
{
	for (int i = 0; i < 2; i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);

		if (IsValidEntity(weapon))
		{
			SetClip(weapon, iDefaultClip[weapon]);
			SetAmmo(client, weapon, iDefaultAmmo[weapon]);
		}
	}
}

public int Native_IsDoublePoints(Handle plugin, int numParams)
{
	return bDoublePoints;
}

public int Native_IsInstantKill(Handle plugin, int numParams)
{
	return bInstantKill;
}

public Action Command_Powerup(int client, int args)
{
	if (args > 0)
	{
		char sID[12];
		GetCmdArg(1, sID, sizeof(sID));
		int id = StringToInt(sID);

		if (id < 1 || id > iPowerupsAmount)
		{
			CPrintToChat(client, "%s Error spawning powerup, invalid ID. [Max: {white}%i{gray}]", sGlobalTag, id);
			return Plugin_Handled;
		}

		if (bPowerup_Disabled[id])
		{
			CPrintToChat(client, "%s Error spawning powerup, ID '{white}%i{gray}' is disabled.", sGlobalTag, id);
			return Plugin_Handled;
		}

		float vecSpawn[3];
		GetClientLookPosition(client, vecSpawn);

		SpawnPowerup(id, vecSpawn);
		CPrintToChat(client, "%s Spawning Powerup: {white}%s", sGlobalTag, sPowerup_Name[id]);

		return Plugin_Handled;
	}

	Menu menu = CreateMenu(MenuHandler_Powerup);
	SetMenuTitle(menu, "Choose a powerup:");

	for (int i = 0; i < iPowerupsAmount; i++)
	{
		char sID[12];
		IntToString(i, sID, sizeof(sID));

		AddMenuItem(menu, sID, sPowerup_Name[i], bPowerup_Disabled[i] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_Powerup(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[12]; char sDisplay[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));
			int powerup = StringToInt(sInfo);

			float vecSpawn[3];
			GetClientLookPosition(param1, vecSpawn);

			SpawnPowerup(powerup, vecSpawn);
			CPrintToChat(param1, "%s Spawning Powerup: {white}%s", sGlobalTag, sDisplay);
		}
	}
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int iItemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{
	if (IsValidEntity(entityIndex) && StrContains(classname, "tf_weapon") != -1)
	{
		Handle pack;
		CreateDataTimer(0.2, Timer_DelayWeaponSpawn, pack, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(pack, GetClientUserId(client));
		WritePackCell(pack, EntIndexToEntRef(entityIndex));
	}
}

public void CW3_OnWeaponSpawned(int weapon, int slot, int client)
{
	if (!IsValidEntity(weapon))
	{
		return;
	}

	char sClassname[32];
	GetEntityClassname(weapon, sClassname, sizeof(sClassname));

	if (StrContains(sClassname, "tf_weapon") != -1)
	{
		Handle pack;
		CreateDataTimer(0.2, Timer_DelayWeaponSpawn, pack, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(pack, GetClientUserId(client));
		WritePackCell(pack, EntIndexToEntRef(weapon));
	}
}

public Action Timer_DelayWeaponSpawn(Handle timer, any data)
{
	ResetPack(data);

	int client = GetClientOfUserId(ReadPackCell(data));
	int weapon = EntRefToEntIndex(ReadPackCell(data));

	if (client > 0 && IsPlayerAlive(client) && IsValidEntity(weapon))
	{
		iDefaultClip[weapon] = GetClip(weapon);
		iDefaultAmmo[weapon] = GetAmmo(client, weapon);
	}
}
