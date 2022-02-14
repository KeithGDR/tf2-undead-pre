/**********************************************************************************************************************/
//Headers

//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define INVALID_MACHINE_ID -1
#define MAX_MACHINES 256

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Required Externals
#include <tf2items>
#include <tf2attributes>

//Our Includes
#include <tf2-undead/tf2-undead-machines>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-hud>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_Machine_Distance_Usage;
ConVar convar_DefaultMachineGlow;
ConVar convar_Packapunch_EffectID;
ConVar convar_Deadshot_Divider;

//Forwards
Handle hForward_OnMachineSpawn_Post;
Handle hForward_OnMachinePurchased_Post;
Handle hForward_OnMachinePerkGiven_Post;
Handle hForward_OnMachinePerkRemoved_Post;

//Globals
char sCurrentMap[MAX_MAP_NAME_LENGTH];
bool bLate;

Handle g_hHud_Perks;

//Global Variables
char sSound_Purchase[] = "mvm/mvm_bought_upgrade.wav";
char sSound_Denied[] = "replay/cameracontrolerror.wav";

//Machines
char sMachine_Names[MAX_MACHINES][MAX_NAME_LENGTH];
float fMachine_Coordinates[MAX_MACHINES][3];
float fMachine_Angles[MAX_MACHINES][3];
char sMachine_Models[MAX_MACHINES][PLATFORM_MAX_PATH];
int iMachine_Required[MAX_MACHINES];
int iMachinesTotal;

int iMachineTemplate[MAX_MACHINES] = {INVALID_ENT_REFERENCE, ...};

int iNearMachine[MAXPLAYERS + 1] = {INVALID_MACHINE_ID, ...};
Handle hPlayerPerks[MAXPLAYERS + 1];
int g_iCooldown[MAXPLAYERS + 1];
bool bReloadApplied[MAXPLAYERS + 1];
bool g_bShouldPunch[MAXPLAYERS + 1][6];

bool g_bDeadshot[MAX_ENTITY_LIMIT + 1];
bool g_bPackaPunch[MAX_ENTITY_LIMIT + 1];

/**********************************************************************************************************************/
//Plugin Information

public Plugin myinfo =
{
	name = "TF2 Undead - Machines",
	author = "Keith Warren (Shaders Allen)",
	description = "Machines module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

/**********************************************************************************************************************/
//Global Functions

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-machines");

	CreateNative("TF2Undead_Machines_HasPerk", Native_Machines_HasPerk);

	hForward_OnMachineSpawn_Post = CreateGlobalForward("TF2Undead_OnMachineSpawn_Post", ET_Ignore, Param_Cell, Param_String, Param_Array, Param_Array, Param_String);
	hForward_OnMachinePurchased_Post = CreateGlobalForward("TF2Undead_OnMachinePurchased_Post", ET_Ignore, Param_Cell, Param_String);
	hForward_OnMachinePerkGiven_Post = CreateGlobalForward("TF2Undead_OnMachinePerkGiven_Post", ET_Ignore, Param_Cell, Param_String);
	hForward_OnMachinePerkRemoved_Post = CreateGlobalForward("TF2Undead_OnMachinePerkRemoved_Post", ET_Ignore, Param_Cell, Param_String);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_machines_status", "1");
	convar_Config = CreateConVar("sm_undead_machines_config", "configs/undead/machines/%s.cfg");
	convar_Machine_Distance_Usage = CreateConVar("sm_undead_machines_distance_usage", "100.0");
	convar_DefaultMachineGlow = CreateConVar("sm_undead_machines_default_glow", "6 209 202 100");
	convar_Packapunch_EffectID = CreateConVar("sm_undead_machines_packapunch_effect_id", "1");
	convar_Deadshot_Divider = CreateConVar("sm_undead_machines_deadshot_divider", "3");

	RegAdminCmd("sm_respawnmachines", Command_RespawnMachines, ADMFLAG_ROOT, "Respawn all machines on the map.");
	RegAdminCmd("sm_testmachines", Command_TestMachines, ADMFLAG_ROOT, "Test machines and their perks.");
	RegAdminCmd("sm_clearmachines", Command_ClearMachines, ADMFLAG_ROOT, "Clear all machine perks from yourself.");

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);

	g_hHud_Perks = CreateHudSynchronizer();

	AddCommandListener(Listener_VoiceMenu, "voicemenu");
	CreateTimer(0.1, Timer_ProcessMachines, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ClearAllMachinePerks(i);
		}
	}

	ClearAllMachines();
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
	iMachinesTotal = ParseMachinesConfig(sConfig);

	if (bLate)
	{
		if (!TF2Undead_IsInLobby())
		{
			SpawnMachines();
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}

		bLate = false;
	}
}

public void OnClientPutInServer(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	hPlayerPerks[client] = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
}

public void OnClientDisconnect(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	iNearMachine[client] = INVALID_MACHINE_ID;
	delete hPlayerPerks[client];
	g_iCooldown[client] = 0;
	bReloadApplied[client] = false;

	for (int i = 0; i < 6; i++)
	{
		g_bShouldPunch[client][i] = false;
	}
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

	if (StringToInt(sVoice) == 0 && StringToInt(sVoice2) == 0 && PurchasePerkNearMachine(client))
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

/**********************************************************************************************************************/
//Commands

public Action Command_RespawnMachines(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	if (TF2Undead_IsInLobby())
	{
		CReplyToCommand(client, "%s You cannot respawn the machines during the lobby phase.", sGlobalTag);
		return Plugin_Handled;
	}

	ClearAllMachines();

	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_Config, sConfig, sizeof(sConfig));

	iMachinesTotal = ParseMachinesConfig(sConfig);

	SpawnMachines();

	PrintToChat(client, "Machines have been respawned.");

	return Plugin_Handled;
}

public Action Command_TestMachines(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	Menu menu = CreateMenu(MenuHandler_TestMachines);
	SetMenuTitle(menu, "Test a machine:");

	AddMenuItem(menu, "all", "All Machines");

	for (int i = 0; i < iMachinesTotal; i++)
	{
		AddMenuItem(menu, sMachine_Names[i], sMachine_Names[i], FindStringInArray(hPlayerPerks[client], sMachine_Names[i]) != INVALID_ARRAY_INDEX ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Action Command_ClearMachines(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ClearAllMachinePerks(client);
	PrintToChat(client, "All perks have been cleared.");
	return Plugin_Handled;
}

/**********************************************************************************************************************/
//Event Callbacks

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!GetConVarBool(convar_Status) || client == 0 || !IsClientInGame(client))
	{
		return;
	}

	ClearAllMachinePerks(client);

	for (int i = 0; i < 5; i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);

		if (IsValidEntity(weapon))
		{
			if (g_bShouldPunch[client][i])
			{
				TF2Attrib_SetByName(weapon, "damage bonus", 1.30);
				TF2Attrib_SetByName(weapon, "fire rate bonus", 0.70);
				TF2Attrib_SetByName(weapon, "Reload time decreased", 0.70);

				g_bShouldPunch[client][i] = false;
			}

			if (FindStringInArray(hPlayerPerks[client], "doubletap"))
			{
				TF2Attrib_SetByName(weapon, "projectile penetration", 1.0);
				TF2Attrib_SetByName(weapon, "energy weapon penetration", 1.0);
				TF2Attrib_SetByName(weapon, "projectile penetration heavy", 1.0);
			}
		}
	}
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!GetConVarBool(convar_Status) || client == 0 || !IsClientInGame(client))
	{
		return;
	}

	for (int i = 0; i < 5; i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);

		if (IsValidEntity(weapon))
		{
			g_bDeadshot[weapon] = false;

			if (g_bPackaPunch[weapon])
			{
				g_bShouldPunch[client][i] = true;
				g_bPackaPunch[weapon] = false;
			}
		}
	}

	ClearAllMachinePerks(client);
}

/**********************************************************************************************************************/
//Undead Forwards

public void TF2Undead_OnStartGame_Post(const char[] wave_config)
{
	if (GetConVarBool(convar_Status))
	{
		SpawnMachines();
	}
}

public void TF2Undead_OnEndGame_Post(bool won)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ClearAllMachinePerks(i);
		}
	}

	ClearAllMachines();
}

public Action TF2Undead_OnZombieTakeDamage(int zombie, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker == 0 || attacker > MaxClients || !IsClientInGame(attacker))
	{
		return Plugin_Continue;
	}

	int active = GetActiveWeapon(attacker);

	if (IsValidEntity(active) && g_bDeadshot[active])
	{
		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
		{
			if (entity == zombie)
			{
				continue;
			}

			float vecZombiePos[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecZombiePos);

			if (GetVectorDistance(damagePosition, vecZombiePos) <= 150.0)
			{
				SDKHooks_TakeDamage(entity, 0, attacker, damage / GetConVarFloat(convar_Deadshot_Divider), DMG_BLAST, active, NULL_VECTOR, damagePosition);
			}
		}
	}

	return Plugin_Continue;
}


/**********************************************************************************************************************/
//Timer Callbacks

public Action Timer_ProcessMachines(Handle timer)
{
	for (int i = 0; i < iMachinesTotal; i++)
	{
		if (iMachineTemplate[i] != INVALID_ENT_REFERENCE)
		{
			ProcessMachine(i, EntRefToEntIndex(iMachineTemplate[i]));
		}
	}
}

/**********************************************************************************************************************/
//Menu Callbacks

public int MenuHandler_TestMachines(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "all"))
			{
				GrantAllMachinePerks(param1);
				PrintToChat(param1, "All machine perks granted.");
			}
			else
			{
				int slot;
				GrantPerk(param1, sInfo, slot);
				PrintToChat(param1, "Machine Perk: %s",  sInfo);
			}

			Command_TestMachines(param1, 0);
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

/**********************************************************************************************************************/
//Stock Functions

void SpawnMachines()
{
	for (int i = 0; i < iMachinesTotal; i++)
	{
		int entity = SpawnMachine(i, sMachine_Names[i], fMachine_Coordinates[i], fMachine_Angles[i], sMachine_Models[i]);

		if (IsValidEntity(entity))
		{
			Call_StartForward(hForward_OnMachineSpawn_Post);
			Call_PushCell(entity);
			Call_PushString(sMachine_Names[i]);
			Call_PushArray(fMachine_Coordinates[i], 3);
			Call_PushArray(fMachine_Angles[i], 3);
			Call_PushString(sMachine_Models[i]);
			Call_Finish();
		}
	}
}

void ClearAllMachines()
{
	for (int i = 0; i < iMachinesTotal; i++)
	{
		if (iMachineTemplate[i] != INVALID_ENT_REFERENCE)
		{
			int entity = EntRefToEntIndex(iMachineTemplate[i]);
			if (IsValidEntity(entity))
			{
				AcceptEntityInput(entity, "Kill");
			}

			iMachineTemplate[i] = INVALID_ENT_REFERENCE;
		}
	}
}

int SpawnMachine(int machine, const char[] name, const float coordinates[3], const float angles[3], const char[] model)
{
	int entity = CreateEntityByName("prop_dynamic");

	if (IsValidEntity(entity))
	{
		DispatchKeyValueVector(entity, "origin", coordinates);
		DispatchKeyValueVector(entity, "angles", angles);
		DispatchKeyValue(entity, "targetname", name);
		DispatchKeyValue(entity, "model", model);
		DispatchKeyValue(entity, "solid", "6");
		DispatchSpawn(entity);

		iMachineTemplate[machine] = EntIndexToEntRef(entity);

		int color[4]; color = GetConVarColor(convar_DefaultMachineGlow);
		TF2_CreateGlow("machine_glow", entity, color);
	}

	return entity;
}

void ProcessMachine(int id, int entity)
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

		RedrawPerksList(i);

		float fOrigin[3];
		GetClientAbsOrigin(i, fOrigin);

		if (GetVectorDistance(fEntityOrigin, fOrigin) > GetConVarFloat(convar_Machine_Distance_Usage))
		{
			if (iNearMachine[i] == id)
			{
				TF2Undead_Hud_ClearPurchaseHud(i);
				iNearMachine[i] = INVALID_MACHINE_ID;
			}

			continue;
		}

		NearMachine(i, id);
	}
}

void NearMachine(int client, int machine)
{
	iNearMachine[client] = machine;
	TF2Undead_Hud_ShowPurchaseHud(client, "Press 'E' to purchase from this machine", iMachine_Required[machine]);
}

bool PurchasePerkNearMachine(int client)
{
	if (TF2Undead_IsInLobby() || !IsPlayerAlive(client) || iNearMachine[client] == INVALID_MACHINE_ID)
	{
		return false;
	}

	if (TF2Undead_IsWavePaused() && !CheckCommandAccess(client, "", ADMFLAG_ROOT))
	{
		CPrintToChat(client, "%s The wave is currently paused!", sGlobalTag);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	int machine = iNearMachine[client];

	if (StrEqual(sMachine_Names[machine], "packapunch"))
	{
		int active = GetActiveWeapon(client);

		if (!IsValidEntity(active))
		{
			CPrintToChat(client, "%s You do not have an active weapon.", sGlobalTag);
			EmitSoundToClient(client, sSound_Denied);
			return false;
		}

		if (g_bPackaPunch[active])
		{
			CPrintToChat(client, "%s Your currently active weapon has packapunch already.", sGlobalTag);
			EmitSoundToClient(client, sSound_Denied);
			return false;
		}
	}
	else if (FindStringInArray(hPlayerPerks[client], sMachine_Names[machine]) != INVALID_ARRAY_INDEX)
	{
		CPrintToChat(client, "%s You already own this perk.", sGlobalTag);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	if (iMachine_Required[machine] > TF2Undead_GetClientPoints(client))
	{
		int display = iMachine_Required[machine] - TF2Undead_GetClientPoints(client);
		CPrintToChat(client, "%s You need {white}%i {gray}more points to purchase from this machine.", sGlobalTag, display);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	int slot;
	if (GrantPerk(client, sMachine_Names[machine], slot))
	{
		//CPrintToChat(client, "%s You purchased the machine perk: {white}%s", sGlobalTag, sMachine_Names[machine]);

		if (StrEqual(sMachine_Names[machine], "packapunch"))
		{
			char sSlotName[32];
			GetSlotName(slot, sSlotName, sizeof(sSlotName));
			CPrintToChatAll("%s {white}%N {gray}has upgraded his %s weapon: {white}%s", sGlobalTag, client, sSlotName, sMachine_Names[machine]);
			PrintCenterText(client, "Weapon %s Upgraded: %s", sSlotName, sMachine_Names[machine]);
		}
		else
		{
			CPrintToChatAll("%s {white}%N {gray}has purchased the Machine Perk: {white}%s", sGlobalTag, client, sMachine_Names[machine]);
			PrintCenterText(client, "Machine Perk Purchased: %s", sMachine_Names[machine]);
		}

		EmitSoundToClient(client, sSound_Purchase);
		TF2Undead_UpdateClientPoints(client, Subtract, iMachine_Required[machine]);

		Call_StartForward(hForward_OnMachinePurchased_Post);
		Call_PushCell(client);
		Call_PushString(sMachine_Names[machine]);
		Call_Finish();
	}

	return true;
}

void GetSlotName(int slot, char[] name, int size)
{
	switch (slot)
	{
		case 0: strcopy(name, size, "Primary");
		case 1: strcopy(name, size, "Secondary");
		case 2: strcopy(name, size, "Melee");
	}
}

void RedrawPerksList(int client)
{
	if (client == 0 || IsFakeClient(client))
	{
		return;
	}

	int perks = GetArraySize(hPlayerPerks[client]);

	if (perks == 0)
	{
		return;
	}

	char sBuffer[128];
	for (int i = 0; i < perks; i++)
	{
		char sMachine[MAX_NAME_LENGTH];
		GetArrayString(hPlayerPerks[client], i, sMachine, sizeof(sMachine));

		if (i == 0)
		{
			Format(sBuffer, sizeof(sBuffer), "%s", sMachine);
			continue;
		}

		Format(sBuffer, sizeof(sBuffer), "%s\n%s", sBuffer, sMachine);
	}

	SetHudTextParams(0.0, 0.0, 99999.0, 255, 255, 255, 255);
	ShowSyncHudText(client, g_hHud_Perks, sBuffer);
}

int ParseMachinesConfig(const char[] config)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), config, sCurrentMap);

	KeyValues keyvalues = CreateKeyValues("machines_config");
	int amount;

	if (FileToKeyValues(keyvalues, sPath) && KvGotoFirstSubKey(keyvalues))
	{
		do {
			KvGetSectionName(keyvalues, sMachine_Names[amount], MAX_NAME_LENGTH);
			KvGetVector(keyvalues, "coordinates", fMachine_Coordinates[amount]);
			KvGetVector(keyvalues, "angles", fMachine_Angles[amount]);
			KvGetString(keyvalues, "model", sMachine_Models[amount], PLATFORM_MAX_PATH);
			iMachine_Required[amount] = KvGetNum(keyvalues, "required");

			PrecacheModel(sMachine_Models[amount]);
			amount++;
		}
		while (KvGotoNextKey(keyvalues));
	}

	delete keyvalues;
	return amount;
}

bool GrantAllMachinePerks(int client)
{
	for (int i = 0; i < iMachinesTotal; i++)
	{
		int slot;
		GrantPerk(client, sMachine_Names[i], slot);
	}

	return true;
}

bool GrantPerk(int client, const char[] machine, int& slot)
{
	if (!IsPlayerAlive(client) || !StrEqual(machine, "packapunch") && FindStringInArray(hPlayerPerks[client], machine) != INVALID_ARRAY_INDEX)
	{
		return false;
	}

	if (StrEqual(machine, "deadshot"))
	{
		for (int i = 0; i < 5; i++)
		{
			int weapon = GetPlayerWeaponSlot(client, i);

			if (IsValidEntity(weapon))
			{
				TF2Attrib_SetByName(weapon, "projectile penetration", 1.0);
				TF2Attrib_SetByName(weapon, "energy weapon penetration", 1.0);
				TF2Attrib_SetByName(weapon, "projectile penetration heavy", 1.0);
				g_bDeadshot[weapon] = true;
			}
		}
	}
	else if (StrEqual(machine, "doubletap"))
	{
		for (int i = 0; i < 5; i++)
		{
			int weapon = GetPlayerWeaponSlot(client, i);

			if (IsValidEntity(weapon))
			{
				TF2Attrib_SetFireRateBonus(weapon, 0.30);
				TF2Attrib_SetByName(weapon, "bullets per shot bonus", 2.0);
			}
		}
	}
	else if (StrEqual(machine, "juggernog"))
	{
		SetEntityHealth(client, 300);
	}
	else if (StrEqual(machine, "packapunch"))
	{
		int weapon = GetActiveWeapon(client);

		if (IsValidEntity(weapon) && !g_bPackaPunch[weapon])
		{
			TF2Attrib_SetByName(weapon, "damage bonus", 1.30);
			TF2Attrib_SetFireRateBonus(weapon, 0.30);
			TF2Attrib_SetByName(weapon, "Reload time decreased", 0.70);
			TF2Attrib_SetByName(weapon, "attach particle effect", GetConVarInt(convar_Packapunch_EffectID) * 1.0);
			g_bPackaPunch[weapon] = true;
		}
	}
	else if (StrEqual(machine, "quickrevive"))
	{

	}
	else if (StrEqual(machine, "speedcola"))
	{
		if (TF2Attrib_GetByName(client, "Reload time decreased") == Address_Null)
		{
			TF2Attrib_SetByName(client, "Reload time decreased", 0.70);
			bReloadApplied[client] = true;
		}

		TF2Attrib_SetByName(client, "deploy time decreased", 0.70);
	}
	else if (StrEqual(machine, "staminup"))
	{
		TF2Attrib_SetByName(client, "move speed bonus", 1.70);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
	}

	if (!StrEqual(machine, "packapunch"))
	{
		PushArrayString(hPlayerPerks[client], machine);
		RedrawPerksList(client);
	}

	Call_StartForward(hForward_OnMachinePerkGiven_Post);
	Call_PushCell(client);
	Call_PushString(machine);
	Call_Finish();

	return true;
}

void TF2Attrib_SetFireRateBonus(int weapon, float bonus)
{
	float firerate;
	Address addr = TF2Attrib_GetByName(weapon, "fire rate bonus");

	firerate = addr != Address_Null ? TF2Attrib_GetValue(addr) : 1.00 - bonus;
	TF2Attrib_SetByName(weapon, "fire rate bonus", firerate);
}

bool ClearAllMachinePerks(int client)
{
	if (client == 0 || IsFakeClient(client))
	{
		return false;
	}

	int perks = GetArraySize(hPlayerPerks[client]);

	if (perks == 0)
	{
		return false;
	}

	for (int i = 0; i < perks; i++)
	{
		char sMachine[MAX_NAME_LENGTH];
		GetArrayString(hPlayerPerks[client], i, sMachine, sizeof(sMachine));

		ClearPerk(client, sMachine, false);
	}

	ClearArray(hPlayerPerks[client]);
	ClearSyncHud(client, g_hHud_Perks);

	TF2_RegeneratePlayer(client);

	return true;
}

bool ClearPerk(int client, const char[] machine, bool remove = true)
{
	int index = INVALID_ARRAY_INDEX;
	if (!StrEqual(machine, "packapunch"))
	{
		index = FindStringInArray(hPlayerPerks[client], machine);

		if (index == INVALID_ARRAY_INDEX)
		{
			return false;
		}
	}

	if (StrEqual(machine, "deadshot"))
	{
		for (int i = 0; i < 5; i++)
		{
			int weapon = GetPlayerWeaponSlot(client, i);

			if (IsValidEntity(weapon))
			{
				TF2Attrib_RemoveByName(weapon, "projectile penetration");
				TF2Attrib_RemoveByName(weapon, "energy weapon penetration");
				TF2Attrib_RemoveByName(weapon, "projectile penetration heavy");
			}
		}
	}
	else if (StrEqual(machine, "doubletap"))
	{
		for (int i = 0; i < 5; i++)
		{
			int weapon = GetPlayerWeaponSlot(client, i);

			if (IsValidEntity(weapon))
			{
				TF2Attrib_RemoveByName(weapon, "fire rate bonus");
				TF2Attrib_RemoveByName(weapon, "bullets per shot bonus");
			}
		}
	}
	else if (StrEqual(machine, "juggernog"))
	{

	}
	else if (StrEqual(machine, "packapunch"))
	{
		for (int i = 0; i < 5; i++)
		{
			int weapon = GetPlayerWeaponSlot(client, i);

			if (IsValidEntity(weapon) && g_bPackaPunch[weapon])
			{
				TF2Attrib_RemoveByName(weapon, "damage bonus");
				TF2Attrib_RemoveByName(weapon, "fire rate bonus");
				TF2Attrib_RemoveByName(weapon, "Reload time decreased");
				g_bPackaPunch[weapon] = false;
			}
		}
	}
	else if (StrEqual(machine, "quickrevive"))
	{

	}
	else if (StrEqual(machine, "speedcola"))
	{
		if (bReloadApplied[client])
		{
			TF2Attrib_RemoveByName(client, "Reload time decreased");
		}

		TF2Attrib_RemoveByName(client, "deploy time decreased");
	}
	else if (StrEqual(machine, "staminup"))
	{
		TF2Attrib_RemoveByName(client, "move speed bonus");
	}

	if (remove && !StrEqual(machine, "packapunch"))
	{
		RemoveFromArray(hPlayerPerks[client], index);
		RedrawPerksList(client);
	}

	Call_StartForward(hForward_OnMachinePerkRemoved_Post);
	Call_PushCell(client);
	Call_PushString(machine);
	Call_Finish();

	return true;
}

/**********************************************************************************************************************/
//Natives

public int Native_Machines_HasPerk(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int length;
	GetNativeStringLength(2, length);

	char[] sMachine = new char[length + 1];
	GetNativeString(2, sMachine, length + 1);

	return view_as<bool>(FindStringInArray(hPlayerPerks[client], sMachine) != INVALID_ARRAY_INDEX);
}
