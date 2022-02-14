//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define INVALID_CHEST_ID -1
#define INVALID_DISPLAY_ID -1
#define MAX_WEAPON_BOXES 256

//Sourcemod Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Required Externals
#include <cw3-core-redux>

//Our Includes
#include <tf2-undead/tf2-undead-weaponbox>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-hud>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_Points;
ConVar convar_DefaultWeaponGlow;

//Forwards
Handle g_hForward_OnWeaponBoxUse;
Handle g_hForward_OnWeaponBoxUse_Post;

//Globals
char sCurrentMap[MAX_MAP_NAME_LENGTH];
bool bLate;

char sSound_Purchase[] = "mvm/mvm_bought_upgrade.wav";
char sSound_Denied[] = "replay/cameracontrolerror.wav";

char sWeaponBox_Name[MAX_WEAPON_BOXES][MAX_NAME_LENGTH];
bool bWeaponBox_Status[MAX_WEAPON_BOXES];
char sWeaponBox_Name_Button[MAX_WEAPON_BOXES][64];
char sWeaponBox_Name_Lid[MAX_WEAPON_BOXES][64];
char sWeaponBox_Name_Hinge[MAX_WEAPON_BOXES][64];
char sWeaponBox_Music[MAX_WEAPON_BOXES][PLATFORM_MAX_PATH];
float vecWeaponBox_Offsets[MAX_WEAPON_BOXES][3];
StringMap g_hTrie_Weapons_Data[MAX_WEAPON_BOXES];
ArrayList g_hArray_Weapons_Global[MAX_WEAPON_BOXES];
StringMap g_hTrie_Weapons_Models[MAX_WEAPON_BOXES];
StringMap g_hTrie_Weapons_Angles[MAX_WEAPON_BOXES];
int g_iWeaponBoxes;

int iEntity_Button[MAX_WEAPON_BOXES] = {INVALID_ENT_REFERENCE, ...};
int iEntity_Lid[MAX_WEAPON_BOXES] = {INVALID_ENT_REFERENCE, ...};
int iEntity_Hinge[MAX_WEAPON_BOXES] = {INVALID_ENT_REFERENCE, ...};
int iEntity_Display[MAX_WEAPON_BOXES] = {INVALID_ENT_REFERENCE, ...};

int iCrateCount[MAX_WEAPON_BOXES];
int iLastWeapon[MAX_WEAPON_BOXES] = {INVALID_DISPLAY_ID, ...};
char sGiveWeapon[MAXPLAYERS + 1][64];
int g_iIsNearBox[MAXPLAYERS + 1] = {INVALID_CHEST_ID, ...};

//Weapon Box Timers
Handle g_hTimer_Weapon_Box[MAX_WEAPON_BOXES];
Handle g_hTimer_Weapon_ModelSwitch[MAX_WEAPON_BOXES];
Handle g_hTimer_Weapon_Move[MAX_WEAPON_BOXES];

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - WeaponBox",
	author = "Keith Warren (Drixevel)",
	description = "WeaponBox module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-weaponbox");

	//CreateNative("", Native_);

	g_hForward_OnWeaponBoxUse = CreateGlobalForward("TF2Undead_OnWeaponBoxUsed", ET_Event, Param_CellByRef);
	g_hForward_OnWeaponBoxUse_Post = CreateGlobalForward("TF2Undead_OnWeaponBoxUsed_Post", ET_Ignore, Param_Cell, Param_String);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_weaponbox_status", "1");
	convar_Config = CreateConVar("sm_undead_weaponbox_config", "configs/undead/weaponboxes/");
	convar_Points = CreateConVar("sm_undead_weaponbox_default_points", "1000");
	convar_DefaultWeaponGlow = CreateConVar("sm_undead_weaponbox_default_glow_weapons", "228 4 244 200");

	HookEntityOutput("func_button", "OnPressed", OnFuncButtonPressed);

	AddCommandListener(Listener_VoiceMenu, "voicemenu");
	CreateTimer(0.1, Timer_ProcessBoxes, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	for (int i = 0; i < g_iWeaponBoxes; i++)
	{
		ResetWeaponBox(false, i);
	}
}

public void OnMapStart()
{
	GetMapName(sCurrentMap, sizeof(sCurrentMap));

	PrecacheSound(sSound_Purchase);
	PrecacheSound(sSound_Denied);
}

public void OnMapEnd()
{
	for (int i = 0; i < g_iWeaponBoxes; i++)
	{
		ResetWeaponBox(false, i);
	}
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_Config, sConfig, sizeof(sConfig));
	Format(sConfig, sizeof(sConfig), "%s/%s.cfg", sConfig, sCurrentMap);

	ParseWeaponBoxConfig(sConfig);

	if (bLate)
	{
		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_INDEX)
		{
			char classname[64];
			GetEntityClassname(entity, classname, sizeof(classname));
			OnEntityCreated(entity, classname);
		}

		for (int i = 0; i < g_iWeaponBoxes; i++)
		{
			ResetWeaponBox(false, i);
		}

		bLate = false;
	}
}

public void OnClientDisconnect(int client)
{
	sGiveWeapon[client][0] = '\0';
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

	if (StringToInt(sVoice) == 0 && StringToInt(sVoice2) == 0 && OpenWeaponBox(client, g_iIsNearBox[client]))
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void TF2Undead_OnStartGame_Post(const char[] wave_config)
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_INDEX)
	{
		char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		OnEntityCreated(entity, classname);
	}
}

bool OpenWeaponBox(int client, int weaponbox_id)
{
	if (TF2Undead_IsInLobby() || !IsPlayerAlive(client) || weaponbox_id == INVALID_CHEST_ID || iEntity_Button[weaponbox_id] == INVALID_ENT_REFERENCE)
	{
		return false;
	}

	int iButton = EntRefToEntIndex(iEntity_Button[weaponbox_id]);

	if (!IsValidEntity(iButton))
	{
		return false;
	}

	AcceptEntityInput(iButton, bWeaponBox_Status[weaponbox_id] ? "Unlock" : "Lock");

	if (GetEntProp(iButton, Prop_Data, "m_bLocked"))
	{
		CPrintToChat(client, "%s Chest '%s' is currently locked.", sGlobalTag, sWeaponBox_Name[weaponbox_id]);
		return false;
	}

	float vecBoxOrigin[3];
	GetEntPropVector(iButton, Prop_Send, "m_vecOrigin", vecBoxOrigin);

	float vecPlayerOrigin[3];
	GetClientAbsOrigin(client, vecPlayerOrigin);

	if (GetVectorDistance(vecBoxOrigin, vecPlayerOrigin) > 100.0)
	{
		if (strlen(sGiveWeapon[client]) > 0)
		{
			CPrintToChat(client, "%s You must be next to the chest to claim your weapon.", sGlobalTag);
		}

		return false;
	}

	if (strlen(sGiveWeapon[client]) > 0)
	{
		char sWeapon[64];
		strcopy(sWeapon, sizeof(sWeapon), sGiveWeapon[client]);

		EmitSoundToClient(client, sSound_Purchase);
		//CPrintToChat(client, "%s You have randomly received the weapon: {white}%s", sGlobalTag, sWeapon);
		CPrintToChatAll("%s {white}%N {gray}has rolled a random weapon: {white}%s", sGlobalTag, client, sWeapon);

		CW3_EquipItemByName(client, sWeapon, true);
		TriggerTimer(g_hTimer_Weapon_Box[weaponbox_id]);

		Call_StartForward(g_hForward_OnWeaponBoxUse_Post);
		Call_PushCell(client);
		Call_PushString(sWeapon);
		Call_Finish();
	}
	else
	{
		AcceptEntityInput(iButton, "Press", client, iButton);
	}

	return true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!GetConVarBool(convar_Status) || entity <= MaxClients)
	{
		return;
	}

	char sName[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

	if (strlen(sName) == 0)
	{
		return;
	}

	for (int i = 0; i < g_iWeaponBoxes; i++)
	{
		if (StrEqual(sName, sWeaponBox_Name_Button[i]))
		{
			iEntity_Button[i] = EntIndexToEntRef(entity);
		}

		if (StrEqual(sName, sWeaponBox_Name_Lid[i]))
		{
			iEntity_Lid[i] = EntIndexToEntRef(entity);
		}

		if (StrEqual(sName, sWeaponBox_Name_Hinge[i]))
		{
			iEntity_Hinge[i] = EntIndexToEntRef(entity);
		}
	}
}

public Action OnFuncButtonPressed(const char[] output, int caller, int activator, float delay)
{
	if (!GetConVarBool(convar_Status) || activator == 0 || activator > MaxClients || TF2Undead_IsInLobby())
	{
		return Plugin_Handled;
	}

	int weaponbox_id = g_iIsNearBox[activator];

	if (weaponbox_id == INVALID_CHEST_ID)
	{
		return Plugin_Handled;
	}

	float vecBoxOrigin[3];
	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", vecBoxOrigin);

	float vecPlayerOrigin[3];
	GetClientAbsOrigin(activator, vecPlayerOrigin);

	if (GetVectorDistance(vecBoxOrigin, vecPlayerOrigin) > 100.0)
	{
		return Plugin_Handled;
	}

	if (TF2Undead_IsWavePaused() && !CheckCommandAccess(activator, "", ADMFLAG_ROOT))
	{
		CPrintToChat(activator, "%s The wave is currently paused!", sGlobalTag);
		EmitSoundToClient(activator, sSound_Denied);
		return Plugin_Handled;
	}

	if (iEntity_Hinge[weaponbox_id] == INVALID_ENT_REFERENCE)
	{
		CPrintToChat(activator, "%s Error opening this chest, please try again later.", sGlobalTag);
		EmitSoundToClient(activator, sSound_Denied);
		return Plugin_Handled;
	}

	int iHinge = EntRefToEntIndex(iEntity_Hinge[weaponbox_id]);

	if (!IsValidEntity(iHinge))
	{
		CPrintToChat(activator, "%s Error opening this chest, please try again later.", sGlobalTag);
		EmitSoundToClient(activator, sSound_Denied);
		return Plugin_Handled;
	}

	int owner = GetEntPropEnt(iHinge, Prop_Data, "m_hOwnerEntity");

	if (owner > 0 && activator == owner)
	{
		return Plugin_Handled;
	}

	if (GetEntProp(iHinge, Prop_Data, "m_toggle_state") != 1 || owner > 0 && activator != owner)
	{
		CPrintToChat(activator, "%s The chest is currently in use, please try again soon.", sGlobalTag);
		EmitSoundToClient(activator, sSound_Denied);
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(activator))
	{
		CPrintToChat(activator, "%s You must be alive to use this weapon chest.", sGlobalTag);
		EmitSoundToClient(activator, sSound_Denied);
		return Plugin_Handled;
	}

	int points = GetConVarInt(convar_Points);
	if (points > TF2Undead_GetClientPoints(activator))
	{
		int display = points - TF2Undead_GetClientPoints(activator);
		CPrintToChat(activator, "%s You need {white}%i {gray}more points to open this chest.", sGlobalTag, display);
		EmitSoundToClient(activator, sSound_Denied);
		return Plugin_Handled;
	}

	char sName[64];
	GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));

	if (StrEqual(sName, sWeaponBox_Name_Button[weaponbox_id]))
	{
		StartBoxSpawnEvent(activator, weaponbox_id);
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

void StartBoxSpawnEvent(int client, int weaponbox_id)
{
	if (iEntity_Lid[weaponbox_id] == INVALID_ENT_REFERENCE || iEntity_Hinge[weaponbox_id] == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int ilid = EntRefToEntIndex(iEntity_Lid[weaponbox_id]);
	int iHinge = EntRefToEntIndex(iEntity_Hinge[weaponbox_id]);

	if (!IsValidEntity(iHinge) || !IsValidEntity(ilid))
	{
		return;
	}

	AcceptEntityInput(iHinge, "Open", client, iHinge);

	Call_StartForward(g_hForward_OnWeaponBoxUse);
	Call_PushCellRef(client);
	Call_Finish();

	EmitSoundToAll(sWeaponBox_Music[weaponbox_id], iHinge, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	TF2Undead_UpdateClientPoints(client, Subtract, GetConVarInt(convar_Points));

	SetEntPropEnt(iHinge, Prop_Data, "m_hOwnerEntity", client);

	float vecOrigin[3];
	GetEntPropVector(iHinge, Prop_Send, "m_vecOrigin", vecOrigin);
	vecOrigin[0] += vecWeaponBox_Offsets[weaponbox_id][0];
	vecOrigin[1] += vecWeaponBox_Offsets[weaponbox_id][1];
	vecOrigin[2] += vecWeaponBox_Offsets[weaponbox_id][2];

	int weapon = CreateEntityByName("prop_dynamic");

	if (!IsValidEntity(weapon))
	{
		return;
	}

	char sName[64];
	iLastWeapon[weaponbox_id] = GetRandomWeapon(client, weaponbox_id, sName, sizeof(sName));

	if (iLastWeapon[weaponbox_id] == INVALID_DISPLAY_ID)
	{
		return;
	}

	float vecAngles[3];
	GetTrieArray(g_hTrie_Weapons_Angles[weaponbox_id], sName, vecAngles, sizeof(vecAngles));

	char sModel[PLATFORM_MAX_PATH];
	GetTrieString(g_hTrie_Weapons_Models[weaponbox_id], sName, sModel, sizeof(sModel));

	DispatchKeyValue(weapon, "targetname", "weapon_box_weapon");
	DispatchKeyValue(weapon, "model", sModel);
	DispatchKeyValueVector(weapon, "origin", vecOrigin);
	DispatchKeyValueVector(weapon, "angles", vecAngles);
	DispatchSpawn(weapon);

	AttachParticle(weapon, "superrare_beams1");

	SetVariantInt(1);
	AcceptEntityInput(weapon, "SetShadowsDisabled");

	AcceptEntityInput(weapon, "DisableCollisions");

	int color[4]; color = GetConVarColor(convar_DefaultWeaponGlow);
	TF2_CreateGlow("weapon_glow", weapon, color);

	iCrateCount[weaponbox_id] = 8;
	iEntity_Display[weaponbox_id] = EntIndexToEntRef(weapon);

	g_hTimer_Weapon_Move[weaponbox_id] = CreateTimer(0.1, Timer_MoveWeapon, weaponbox_id, TIMER_REPEAT);

	DataPack pack;
	g_hTimer_Weapon_ModelSwitch[weaponbox_id] = CreateDataTimer(0.5, Timer_ChangeWeaponType, pack, TIMER_REPEAT);
	WritePackCell(pack, GetClientUserId(client));
	WritePackCell(pack, weaponbox_id);
}

int GetRandomWeapon(int client, int weaponbox_id, char[] name, int size)
{
	char sClass[32];
	TF2_GetClientClassName(client, sClass, sizeof(sClass));

	ArrayList weapon_array;
	if (GetTrieValue(g_hTrie_Weapons_Data[weaponbox_id], sClass, weapon_array) && weapon_array != null)
	{
		return GetRandomWeaponIndex(weapon_array, name, size, iLastWeapon[weaponbox_id]);
	}

	return INVALID_DISPLAY_ID;
}

public Action Timer_ChangeWeaponType(Handle timer, any data)
{
	ResetPack(data);

	int userid = ReadPackCell(data);
	int client = GetClientOfUserId(userid);
	int weaponbox_id = ReadPackCell(data);

	if (iEntity_Display[weaponbox_id] == INVALID_ENT_REFERENCE)
	{
		g_hTimer_Weapon_ModelSwitch[weaponbox_id] = null;
		return Plugin_Stop;
	}

	int entity_weapon = EntRefToEntIndex(iEntity_Display[weaponbox_id]);

	if (client == 0)
	{
		if (IsValidEntity(entity_weapon))
		{
			AcceptEntityInput(entity_weapon, "Kill");
		}

		g_hTimer_Weapon_ModelSwitch[weaponbox_id] = null;
		return Plugin_Stop;
	}

	if (!IsValidEntity(entity_weapon))
	{
		g_hTimer_Weapon_ModelSwitch[weaponbox_id] = null;
		return Plugin_Stop;
	}

	char sName[64];
	iLastWeapon[weaponbox_id] = GetRandomWeapon(client, weaponbox_id, sName, sizeof(sName));

	if (iLastWeapon[weaponbox_id] == INVALID_DISPLAY_ID)
	{
		g_hTimer_Weapon_ModelSwitch[weaponbox_id] = null;
		return Plugin_Stop;
	}

	char sModel[PLATFORM_MAX_PATH];
	GetTrieString(g_hTrie_Weapons_Models[weaponbox_id], sName, sModel, sizeof(sModel));

	if (strlen(sModel) > 0)
	{
		SetEntityModel(entity_weapon, sModel);

		float vecAngles[3];
		GetTrieArray(g_hTrie_Weapons_Angles[weaponbox_id], sName, vecAngles, sizeof(vecAngles));
		DispatchKeyValueVector(entity_weapon, "angles", vecAngles);
	}

	iCrateCount[weaponbox_id]--;

	if (iCrateCount[weaponbox_id] <= 0)
	{
		strcopy(sGiveWeapon[client], 64, sName);
		CPrintToChat(client, "%s Press 'E' next to the chest to claim your weapon: {white}%s", sGlobalTag, sGiveWeapon[client]);

		DataPack pack;
		g_hTimer_Weapon_Box[weaponbox_id] = CreateDataTimer(15.0, Timer_CloseLid, pack, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(pack, userid);
		WritePackCell(pack, weaponbox_id);

		g_hTimer_Weapon_ModelSwitch[weaponbox_id] = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Timer_MoveWeapon(Handle timer, any data)
{
	int weaponbox_id = data;

	if (iEntity_Display[weaponbox_id] == INVALID_ENT_REFERENCE)
	{
		g_hTimer_Weapon_Move[weaponbox_id] = null;
		return Plugin_Stop;
	}

	int entity_weapon = EntRefToEntIndex(iEntity_Display[weaponbox_id]);

	if (!IsValidEntity(entity_weapon))
	{
		g_hTimer_Weapon_Move[weaponbox_id] = null;
		return Plugin_Stop;
	}

	float vecOrigin[3];
	GetEntPropVector(entity_weapon, Prop_Send, "m_vecOrigin", vecOrigin);

	if (g_hTimer_Weapon_Box[weaponbox_id] != null)
	{
		vecOrigin[2] -= 0.2;
	}
	else
	{
		vecOrigin[2] += 0.6;
	}

	DispatchKeyValueVector(entity_weapon, "origin", vecOrigin);

	return Plugin_Continue;
}

public Action Timer_CloseLid(Handle timer, any data)
{
	ResetPack(data);

	int userid = ReadPackCell(data);
	int client = GetClientOfUserId(userid);
	int weaponbox_id = ReadPackCell(data);

	if (iEntity_Display[weaponbox_id] == INVALID_ENT_REFERENCE)
	{
		g_hTimer_Weapon_Box[weaponbox_id] = null;
		return Plugin_Stop;
	}

	int weapon = EntRefToEntIndex(iEntity_Display[weaponbox_id]);

	if (client > 0)
	{
		sGiveWeapon[client][0] = '\0';
	}

	if (IsValidEntity(weapon))
	{
		AcceptEntityInput(weapon, "Kill");
	}

	ResetWeaponBox(true, weaponbox_id);

	g_hTimer_Weapon_Box[weaponbox_id] = null;
	return Plugin_Stop;
}

int GetRandomWeaponIndex(Handle& array, char[] name, int size, int exclude)
{
	int random = GetRandomInt(0, GetArraySize(array) - 1);

	if (exclude != INVALID_DISPLAY_ID && random == exclude)
	{
		if (random == 0)
		{
			random++;
		}
		else
		{
			random--;
		}
	}

	GetArrayString(array, random, name, size);
	return random;
}

int FindEntityByName(const char[] name, const char[] entitytype)
{
	int entity = INVALID_ENT_INDEX;
	while((entity = FindEntityByClassname(entity, entitytype)) != INVALID_ENT_INDEX)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrEqual(sName, name))
		{
			return entity;
		}
	}

	return INVALID_ENT_INDEX;
}

stock bool CW3_CanClientUseWeapon(int client, char[] weapon)
{
	Handle hWeaponConfig = CW3_FindItemByName(weapon);

	if (hWeaponConfig == null)
	{
		return false;
	}

	KvRewind(hWeaponConfig);
	KvJumpToKey(hWeaponConfig, "classes");
	KvGotoFirstSubKey(hWeaponConfig, false);

	char sClass[64];
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:		strcopy(sClass, sizeof(sClass), "scout");
		case TFClass_Sniper:	strcopy(sClass, sizeof(sClass), "sniper");
		case TFClass_Soldier:	strcopy(sClass, sizeof(sClass), "soldier");
		case TFClass_DemoMan:	strcopy(sClass, sizeof(sClass), "demoman");
		case TFClass_Medic:		strcopy(sClass, sizeof(sClass), "medic");
		case TFClass_Heavy:		strcopy(sClass, sizeof(sClass), "heavy");
		case TFClass_Pyro:		strcopy(sClass, sizeof(sClass), "pyro");
		case TFClass_Spy:		strcopy(sClass, sizeof(sClass), "spy");
		case TFClass_Engineer:	strcopy(sClass, sizeof(sClass), "engineer");
	}

	bool bCanUse;
	do
	{
		char sKey[64];
		KvGetSectionName(hWeaponConfig, sKey, sizeof(sKey));

		if (StrEqual(sKey, sClass))
		{
			bCanUse = true;
		}
	}
	while(KvGotoNextKey(hWeaponConfig, false));

	return bCanUse;
}

public Action Timer_ProcessBoxes(Handle timer, any data)
{
	for (int i = 0; i < g_iWeaponBoxes; i++)
	{
		if (iEntity_Button[i] == INVALID_ENT_REFERENCE)
		{
			continue;
		}

		int iButton = EntRefToEntIndex(iEntity_Button[i]);

		if (!IsValidEntity(iButton))
		{
			continue;
		}

		float vecBoxOrigin[3];
		GetEntPropVector(iButton, Prop_Send, "m_vecOrigin", vecBoxOrigin);

		for (int x = 1; x <= MaxClients; x++)
		{
			if (!IsClientInGame(x) || !IsPlayerAlive(x))
			{
				continue;
			}

			float vecPlayerOrigin[3];
			GetClientAbsOrigin(x, vecPlayerOrigin);

			float distance = GetVectorDistance(vecBoxOrigin, vecPlayerOrigin);

			if (g_iIsNearBox[x] == INVALID_CHEST_ID && distance <= 100.0)
			{
				TF2Undead_Hud_ShowPurchaseHud(x, "Press 'E' to open this chest", GetConVarInt(convar_Points));
				g_iIsNearBox[x] = i;
			}
			else if (g_iIsNearBox[x] == i && distance > 100.0)
			{
				TF2Undead_Hud_ClearPurchaseHud(x);
				g_iIsNearBox[x] = INVALID_CHEST_ID;
			}
		}
	}

	return Plugin_Continue;
}

void ParseWeaponBoxConfig(const char[] config)
{
	KeyValues kv = CreateKeyValues("undead_weaponboxes");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), config);

	if (FileToKeyValues(kv, sPath) && KvGotoFirstSubKey(kv))
	{
		g_iWeaponBoxes = 0;

		do
		{
			KvGetSectionName(kv, sWeaponBox_Name[g_iWeaponBoxes], sizeof(sWeaponBox_Name[]));
			bWeaponBox_Status[g_iWeaponBoxes] = KvGetBool(kv, "status", true);
			KvGetString(kv, "button", sWeaponBox_Name_Button[g_iWeaponBoxes], sizeof(sWeaponBox_Name_Button[]));
			KvGetString(kv, "lid", sWeaponBox_Name_Lid[g_iWeaponBoxes], sizeof(sWeaponBox_Name_Lid[]));
			KvGetString(kv, "hinge", sWeaponBox_Name_Hinge[g_iWeaponBoxes], sizeof(sWeaponBox_Name_Hinge[]));
			KvGetString(kv, "music", sWeaponBox_Music[g_iWeaponBoxes], sizeof(sWeaponBox_Music[]));
			KvGetVector(kv, "offsets", vecWeaponBox_Offsets[g_iWeaponBoxes]);

			if (strlen(sWeaponBox_Music[g_iWeaponBoxes]) > 0)
			{
				PrecacheSound(sWeaponBox_Music[g_iWeaponBoxes]);

				char sDownload[PLATFORM_MAX_PATH];
				FormatEx(sDownload, sizeof(sDownload), "sound/%s", sWeaponBox_Music[g_iWeaponBoxes]);
				AddFileToDownloadsTable(sDownload);
			}

			delete g_hTrie_Weapons_Data[g_iWeaponBoxes];
			delete g_hArray_Weapons_Global[g_iWeaponBoxes];
			delete g_hTrie_Weapons_Models[g_iWeaponBoxes];
			delete g_hTrie_Weapons_Angles[g_iWeaponBoxes];

			if (KvJumpToKey(kv, "weapons") && KvGotoFirstSubKey(kv))
			{
				g_hTrie_Weapons_Data[g_iWeaponBoxes] = CreateTrie();
				g_hArray_Weapons_Global[g_iWeaponBoxes] = CreateArray(ByteCountToCells(64));
				g_hTrie_Weapons_Models[g_iWeaponBoxes] = CreateTrie();
				g_hTrie_Weapons_Angles[g_iWeaponBoxes] = CreateTrie();

				do
				{
					char sName[64];
					KvGetSectionName(kv, sName, sizeof(sName));

					char sModel[PLATFORM_MAX_PATH];
					KvGetString(kv, "model", sModel, sizeof(sModel));

					char sClass[32];
					KvGetString(kv, "class", sClass, sizeof(sClass));

					PushArrayString(g_hArray_Weapons_Global[g_iWeaponBoxes], sName);
					SetTrieString(g_hTrie_Weapons_Models[g_iWeaponBoxes], sName, sModel);

					Handle weapons_array;
					GetTrieValue(g_hTrie_Weapons_Data[g_iWeaponBoxes], sClass, weapons_array);

					if (weapons_array == null)
					{
						weapons_array = CreateArray(ByteCountToCells(64));
						SetTrieValue(g_hTrie_Weapons_Data[g_iWeaponBoxes], sClass, weapons_array);
					}

					PushArrayString(weapons_array, sName);

					float vecAngles[3];
					KvGetVector(kv, "angles", vecAngles);
					SetTrieArray(g_hTrie_Weapons_Angles[g_iWeaponBoxes], sName, vecAngles, sizeof(vecAngles));
				}
				while(KvGotoNextKey(kv));

				KvGoBack(kv);
				KvGoBack(kv);
			}

			g_iWeaponBoxes++;
		}
		while (KvGotoNextKey(kv));
	}

	delete kv;
	LogMessage("Successfully parsed '%i' weapon boxes for the map '%s'.", g_iWeaponBoxes, sCurrentMap);
}

void ResetWeaponBox(bool skip = false, int weaponbox_id)
{
	int iWeapon = FindEntityByName("weapon_box_weapon", "prop_dynamic");

	if (IsValidEntity(iWeapon))
	{
		AcceptEntityInput(iWeapon, "Kill");
	}

	if (iEntity_Hinge[weaponbox_id] != INVALID_ENT_REFERENCE)
	{
		int iHinge = EntRefToEntIndex(iEntity_Hinge[weaponbox_id]);

		if (IsValidEntity(iHinge))
		{
			SetEntPropEnt(iHinge, Prop_Data, "m_hOwnerEntity", 0);
			AcceptEntityInput(iHinge, "Close");
		}
	}

	iLastWeapon[weaponbox_id] = INVALID_DISPLAY_ID;

	if (skip) KillTimerSafe(g_hTimer_Weapon_Box[weaponbox_id]);
	KillTimerSafe(g_hTimer_Weapon_ModelSwitch[weaponbox_id]);
	KillTimerSafe(g_hTimer_Weapon_Move[weaponbox_id]);
}
