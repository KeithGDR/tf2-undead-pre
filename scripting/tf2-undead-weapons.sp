//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define INVALID_WEAPON_ID -1
#define MAX_WEAPONS 64

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Required Externals
#include <cw3-core-redux>
#include <cw3-attributes-redux>
#include <dhooks>
#include <tf2attributes>
#include <tf2items>

//Our Includes
#include <tf2-undead/tf2-undead-weapons>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-hud>
#include <tf2-undead/tf2-undead-specials>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_DefaultWeaponGlow;
ConVar convar_WunderwaffeSpeed;

//Forwards
Handle g_hForward_OnWeaponPurchased;
Handle g_hForward_OnWeaponPurchased_Post;

//Globals
char sCurrentMap[MAX_MAP_NAME_LENGTH];
bool g_bLate;
int iLastButtons[MAXPLAYERS + 1];

//Global Variables
char sSound_Purchase[] = "mvm/mvm_bought_upgrade.wav";
char sSound_Denied[] = "replay/cameracontrolerror.wav";

//Weapons
char sWeapon_Name[MAX_WEAPONS][MAX_NAME_LENGTH];
char sWeapon_Worldmodel[MAX_WEAPONS][PLATFORM_MAX_PATH];
float fWeapon_Coordinates[MAX_WEAPONS][3];
float fWeapon_Angles[MAX_WEAPONS][3];
int iWeapon_PurchaseWeapon[MAX_WEAPONS];
int iWeapon_PurchaseAmmo[MAX_WEAPONS];
int iWeapon_UpgradeAmmo[MAX_WEAPONS];
int iWeapon_UpgradeParticle[MAX_WEAPONS];
int iWeaponsTotal;

int iWeaponTemplate[MAX_WEAPONS] = {INVALID_ENT_REFERENCE, ...};

int iNearWeapon[MAXPLAYERS + 1] = {INVALID_WEAPON_ID, ...};

int iDefaultClip[MAX_ENTITY_LIMIT];
int iDefaultAmmo[MAX_ENTITY_LIMIT];
bool bIsUpgraded[MAX_ENTITY_LIMIT];
Handle g_dhSetClip;

//Ray Gun
Handle g_hSDKWeaponGetDamage;
Handle g_hSDKRocketSetDamage;

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - Weapons",
	author = "Keith Warren (Shaders Allen)",
	description = "Weapons module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-weapons");

	//CreateNative("TF2Undead_Weapons_", Native_);

	g_hForward_OnWeaponPurchased = CreateGlobalForward("TF2Undead_OnWeaponPurchased", ET_Event, Param_CellByRef, Param_String);
	g_hForward_OnWeaponPurchased_Post = CreateGlobalForward("TF2Undead_OnWeaponPurchased_Post", ET_Ignore, Param_Cell, Param_String);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_weapons_status", "1");
	convar_Config = CreateConVar("sm_undead_weapons_config", "configs/undead/weapons/%s.cfg");
	convar_DefaultWeaponGlow = CreateConVar("sm_undead_weapons_default_glow", "255 116 17 100");
	convar_WunderwaffeSpeed = CreateConVar("sm_undead_weapons_wunderwaffe_speed", "650.0");

	RegConsoleCmd("sm_respawnweapons", Command_RespawnWeapons);

	g_dhSetClip = DHookCreate(322, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, OnGetClip1);

	//Ray Gun
	Handle hConf = LoadGameConfigFile("tf2.undead");

	if (hConf != null)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFWeaponBaseGun::GetProjectileDamage");
		PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
		g_hSDKWeaponGetDamage = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFBaseRocket::SetDamage");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hSDKRocketSetDamage = EndPrepSDKCall();

		delete hConf;
	}

	AddCommandListener(Listener_VoiceMenu, "voicemenu");
	CreateTimer(0.1, Timer_ProcessWeapons, _, TIMER_REPEAT);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (StrContains(classname, "tf_weapon_") != -1)
	{
		DHookEntity(g_dhSetClip, true, entity, OnHookRemoved);
	}

	if (StrEqual(classname, "tf_projectile_arrow"))
	{
		SDKHook(entity, SDKHook_Spawn, OnArrowCreated);
	}
}

public MRESReturn OnGetClip1(int pThis, Handle hReturn)
{
	if (bIsUpgraded[pThis])
	{
		int currentclip = DHookGetReturn(hReturn);
		currentclip *= 1.30;
		DHookSetReturn(hReturn, currentclip);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public void OnHookRemoved(int hookid)
{

}

public void OnMapStart()
{
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
	iWeaponsTotal = ParseWeaponsConfig(sConfig);

	if (g_bLate)
	{
		if (!TF2Undead_IsInLobby())
		{
			SpawnWeapons();
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);

				if (IsPlayerAlive(i))
				{
					for (int x = 0; x < 5; x++)
					{
						CW3_OnWeaponSpawned(GetPlayerWeaponSlot(i, x), x, i);
					}
				}
			}
		}

		g_bLate = false;
	}
}

public void OnPluginEnd()
{
	ClearAllWeapons();
}

public void OnClientPutInServer(int client)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker < 1 || attacker > MaxClients || victim == attacker)
	{
		return Plugin_Continue;
	}

	int active = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

	if (IsValidEntity(active) && bIsUpgraded[active])
	{
		damage *= 1.30;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int slot = GetClientActiveSlot(client);

	for (int i = 0; i < MAX_BUTTONS; i++)
	{
		int button = (1 << i);

		if ((buttons & button))
		{
			if (!(iLastButtons[client] & button))
			{
				OnButtonPress(client, button, slot);
			}
		}
		else if ((iLastButtons[client] & button))
		{
			//OnButtonRelease(client, button, slot);
		}
	}

	iLastButtons[client] = buttons;
}

void OnButtonPress(int client, int button, int slot)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (button & IN_ATTACK)
	{
		AttemptBlackHole(client, slot);
	}
}

/*void OnButtonRelease(int client, int button, int slot)
{
if (!GetConVarBool(convar_Status))
{
return;
}
}*/

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

	if (StringToInt(sVoice) == 0 && StringToInt(sVoice2) == 0 && PurchaseWeapon(client))
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void TF2Undead_OnStartGame_Post(const char[] wave_config)
{
	SpawnWeapons();
}

public void TF2Undead_OnMachinePurchased_Post(int client, const char[] machine)
{
	if (StrEqual(machine, "packapunch"))
	{
		int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

		if (!IsValidEntity(active) || bIsUpgraded[active])
		{
			return;
		}

		int slot = GetWeaponSlot(client, active);

		char sWeapon[128];
		bool bCheck = CW3_GetClientWeaponName(client, slot, sWeapon, sizeof(sWeapon));
		int index = GetWeaponArrayIndex(sWeapon);

		if (bCheck && index != INVALID_WEAPON_ID)
		{
			bIsUpgraded[active] = true;
			TF2Attrib_SetByDefIndex(active, 134, float(iWeapon_UpgradeParticle[index]));
		}
	}
}

public void TF2Undead_OnEndGame_Post()
{
	ClearAllWeapons();
}

void SpawnWeapons()
{
	for (int i = 0; i < iWeaponsTotal; i++)
	{
		SpawnWeapon(i, sWeapon_Name[i], sWeapon_Worldmodel[i], fWeapon_Coordinates[i], fWeapon_Angles[i]);
	}
}

void ClearAllWeapons()
{
	for (int i = 0; i < iWeaponsTotal; i++)
	{
		if (iWeaponTemplate[i] != INVALID_ENT_REFERENCE)
		{
			int entity = EntRefToEntIndex(iWeaponTemplate[i]);
			if (IsValidEntity(entity))
			{
				AcceptEntityInput(entity, "Kill");
			}

			iWeaponTemplate[i] = INVALID_ENT_REFERENCE;
		}
	}
}

public Action Command_RespawnWeapons(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	ClearAllWeapons();

	char sConfig[PLATFORM_MAX_PATH];
	GetConVarString(convar_Config, sConfig, sizeof(sConfig));

	iWeaponsTotal = ParseWeaponsConfig(sConfig);

	SpawnWeapons();

	PrintToChat(client, "Weapons have been respawned.");

	return Plugin_Handled;
}

void SpawnWeapon(int id, const char[] name, const char[] worldmodel, float coordinates[3], float angles[3])
{
	int entity = CreateEntityByName("prop_dynamic");

	if (IsValidEntity(entity))
	{
		DispatchKeyValueVector(entity, "origin", coordinates);
		DispatchKeyValueVector(entity, "angles", angles);
		DispatchKeyValue(entity, "targetname", name);
		DispatchKeyValue(entity, "model", worldmodel);
		DispatchSpawn(entity);

		SetVariantInt(1);
		AcceptEntityInput(entity, "SetShadowsDisabled");

		AcceptEntityInput(entity, "DisableCollisions");

		iWeaponTemplate[id] = EntIndexToEntRef(entity);

		int color[4]; color = GetConVarColor(convar_DefaultWeaponGlow);
		TF2_CreateGlow("wall_weapon_glow", entity, color);
	}
}

public Action Timer_ProcessWeapons(Handle timer)
{
	for (int i = 0; i < iWeaponsTotal; i++)
	{
		if (iWeaponTemplate[i] != INVALID_ENT_REFERENCE)
		{
			ProcessWeapon(i, EntRefToEntIndex(iWeaponTemplate[i]));
		}
	}
}

void ProcessWeapon(int id, int entity)
{
	if (!IsValidEntity(entity))
	{
		return;
	}

	float fEntityOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEntityOrigin);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
		{
			continue;
		}

		float fOrigin[3];
		GetClientAbsOrigin(i, fOrigin);

		if (GetVectorDistance(fEntityOrigin, fOrigin) > 100.0)
		{
			if (iNearWeapon[i] == id)
			{
				TF2Undead_Hud_ClearPurchaseHud(i);
				iNearWeapon[i] = INVALID_WEAPON_ID;
			}

			continue;
		}

		NearWeapon(i, id);
	}
}

void NearWeapon(int client, int weapon)
{
	iNearWeapon[client] = weapon;

	char sDisplay[255]; bool ammo;
	if (CW3_AlreadyHasWeapon(client, sWeapon_Name[weapon]) && iWeapon_PurchaseAmmo[weapon] > 0)
	{
		FormatEx(sDisplay, sizeof(sDisplay), "Press 'E' to purchase ammo");
		ammo = true;
	}
	else
	{
		FormatEx(sDisplay, sizeof(sDisplay), "Press 'E' to purchase this weapon %s", CW3_CanClientUseWeapon(client, sWeapon_Name[weapon]) ? "" : "(Not available for your class)");
	}

	TF2Undead_Hud_ShowPurchaseHud(client, sDisplay, ammo ? iWeapon_PurchaseAmmo[weapon] : iWeapon_PurchaseWeapon[weapon]);
}

bool PurchaseWeapon(int client)
{
	if (TF2Undead_IsInLobby() || !IsPlayerAlive(client) || iNearWeapon[client] == INVALID_WEAPON_ID)
	{
		return false;
	}

	if (TF2Undead_IsWavePaused() && !CheckCommandAccess(client, "", ADMFLAG_ROOT))
	{
		CPrintToChat(client, "%s The wave is currently paused!", sGlobalTag);
		EmitSoundToClient(client, sSound_Denied);
		return false;
	}

	int weapon_id = iNearWeapon[client];

	if (CW3_AlreadyHasWeapon(client, sWeapon_Name[weapon_id]) && iWeapon_PurchaseAmmo[weapon_id] > 0)
	{
		if (iWeapon_PurchaseAmmo[weapon_id] > TF2Undead_GetClientPoints(client))
		{
			int display = iWeapon_PurchaseAmmo[weapon_id] - TF2Undead_GetClientPoints(client);
			CPrintToChat(client, "%s You need {white}%i {gray}more points to purchase ammo for this wall weapon.", sGlobalTag, display);
			EmitSoundToClient(client, sSound_Denied);
			return false;
		}

		int slot = CW3_GetWeaponSlot(client, sWeapon_Name[weapon_id]);

		if (slot == -1)
		{
			return false;
		}

		int weapon = GetPlayerWeaponSlot(client, slot);

		if (!IsValidEntity(weapon))
		{
			return false;
		}

		//CPrintToChat(client, "%s You purchased more ammo for the weapon: {white}%s", sGlobalTag, sWeapon_Name[weapon_id]);
		CPrintToChatAll("%s {white}%N {gray}has purchased weapon ammo: {white}%s", sGlobalTag, client, sWeapon_Name[weapon_id]);
		PrintCenterText(client, "Wall Weapon Ammo Purchased: %s", sWeapon_Name[weapon_id]);

		EmitSoundToClient(client, sSound_Purchase);
		TF2Undead_UpdateClientPoints(client, Subtract, iWeapon_PurchaseAmmo[weapon_id]);

		SetClip(weapon, iDefaultClip[weapon]);
		SetAmmo(client, weapon, iDefaultAmmo[weapon]);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
	else
	{
		if (!CW3_CanClientUseWeapon(client, sWeapon_Name[weapon_id]))
		{
			CPrintToChat(client, "%s You are not allowed to use this weapon.", sGlobalTag);
			EmitSoundToClient(client, sSound_Denied);
			return false;
		}

		if (iWeapon_PurchaseWeapon[weapon_id] > TF2Undead_GetClientPoints(client))
		{
			int display = iWeapon_PurchaseWeapon[weapon_id] - TF2Undead_GetClientPoints(client);
			CPrintToChat(client, "%s You need {white}%i {gray}more points to purchase this wall weapon.", sGlobalTag, display);
			EmitSoundToClient(client, sSound_Denied);
			return false;
		}

		int entity = CW3_EquipItemByName(client, sWeapon_Name[weapon_id], true);

		if (IsValidEntity(entity))
		{
			Call_StartForward(g_hForward_OnWeaponPurchased);
			Call_PushCellRef(client);
			Call_PushStringEx(sWeapon_Name[weapon_id], MAX_NAME_LENGTH, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
			Call_Finish();

			//CPrintToChat(client, "%s You purchased the weapon: {white}%s", sGlobalTag, sWeapon_Name[weapon_id]);
			CPrintToChatAll("%s {white}%N {gray}has purchased the wall weapon: {white}%s", sGlobalTag, client, sWeapon_Name[weapon_id]);
			PrintCenterText(client, "Wall Weapon Purchased: %s", sWeapon_Name[weapon_id]);

			EmitSoundToClient(client, sSound_Purchase);
			TF2Undead_UpdateClientPoints(client, Subtract, iWeapon_PurchaseWeapon[weapon_id]);

			Call_StartForward(g_hForward_OnWeaponPurchased_Post);
			Call_PushCell(client);
			Call_PushString(sWeapon_Name[weapon_id]);
			Call_Finish();
		}
	}

	return true;
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{
	if (StrEqual(classname, "tf_weapon_robot_arm") || itemDefinitionIndex == 589)
	{
		DataPack pack;
		CreateDataTimer(0.01, Timer_ReplaceWeapon, pack);
		WritePackCell(pack, client);
		WritePackCell(pack, entityIndex);
		return;
	}

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

	if (client > 0 && IsValidEntity(weapon))
	{
		iDefaultClip[weapon] = GetClip(weapon);
		iDefaultAmmo[weapon] = GetAmmo(client, weapon);
	}
}

public Action Timer_ReplaceWeapon(Handle timer, any data)
{
	ResetPack(data);
	int client = ReadPackCell(data);
	int entity = ReadPackCell(data);

	if (IsValidEntity(entity))
	{
		RemovePlayerItem(client, entity);
		AcceptEntityInput(entity, "Kill");
	}

	Handle hItem = TF2Items_CreateItem(OVERRIDE_CLASSNAME | OVERRIDE_ITEM_DEF | OVERRIDE_ITEM_LEVEL | OVERRIDE_ITEM_QUALITY | OVERRIDE_ATTRIBUTES);
	TF2Items_SetClassname(hItem, "tf_weapon_wrench");
	TF2Items_SetItemIndex(hItem, 7);
	TF2Items_SetLevel(hItem, 1);
	TF2Items_SetQuality(hItem, 6);
	TF2Items_SetNumAttributes(hItem, 0);

	int iWeapon = TF2Items_GiveNamedItem(client, hItem);
	CloseHandle(hItem);

	EquipPlayerWeapon(client, iWeapon);
}

int CW3_GetWeaponSlot(int client, char[] weapon)
{
	KeyValues hWeaponConfig = view_as<KeyValues>(CW3_FindItemByName(weapon));

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

	int slot = -1;
	do
	{
		char sKey[64];
		KvGetSectionName(hWeaponConfig, sKey, sizeof(sKey));

		if (StrEqual(sKey, sClass))
		{
			slot = KvGetInt(hWeaponConfig, NULL_STRING);
		}
	}
	while(KvGotoNextKey(hWeaponConfig, false));

	return slot;
}

bool CW3_AlreadyHasWeapon(int client, char[] weapon)
{
	int slot = CW3_GetWeaponSlot(client, weapon);

	if (slot == -1 || GetPlayerWeaponSlot(client, slot) == INVALID_ENT_INDEX)
	{
		return false;
	}

	char sEquipped[256];
	CW3_GetClientWeaponName(client, slot, sEquipped, sizeof(sEquipped));

	return StrEqual(weapon, sEquipped);
}

bool CW3_CanClientUseWeapon(int client, char[] weapon)
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

int ParseWeaponsConfig(const char[] config)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), config, sCurrentMap);

	KeyValues keyvalues = CreateKeyValues("weapons_config");
	int amount;

	if (FileToKeyValues(keyvalues, sPath) && KvGotoFirstSubKey(keyvalues))
	{
		do
		{
			KvGetSectionName(keyvalues, sWeapon_Name[amount], MAX_NAME_LENGTH);
			KvGetString(keyvalues, "worldmodel", sWeapon_Worldmodel[amount], PLATFORM_MAX_PATH);
			KvGetVector(keyvalues, "coordinates", fWeapon_Coordinates[amount]);
			KvGetVector(keyvalues, "angle", fWeapon_Angles[amount]);
			iWeapon_PurchaseWeapon[amount] = KvGetNum(keyvalues, "purchase_weapon");
			iWeapon_PurchaseAmmo[amount] = KvGetNum(keyvalues, "purchase_ammo");
			iWeapon_UpgradeAmmo[amount] = KvGetNum(keyvalues, "upgrade_ammo");
			iWeapon_UpgradeParticle[amount] = KvGetNum(keyvalues, "upgrade_particle");

			amount++;
		}
		while (KvGotoNextKey(keyvalues));
	}

	delete keyvalues;
	return amount;
}

int GetWeaponArrayIndex(const char[] weapon)
{
	for (int i = 0; i < iWeaponsTotal; i++)
	{
		if (StrEqual(weapon, sWeapon_Name[i]))
		{
			return i;
		}
	}

	return INVALID_WEAPON_ID;
}

//////////////////////////////////////////////////////////
/*
Attributes
*/
//////////////////////////////////////////////////////////

int iBlackHole_RequiredAmmo[MAXPLAYERS + 1][MAXSLOTS + 1];
float fBlackHole_Duration[MAXPLAYERS + 1][MAXSLOTS + 1];
bool bHasBlackHole[MAXPLAYERS + 1];

float fWunder_Damage[MAXPLAYERS + 1][MAXSLOTS + 1];
float fWunder_Radius[MAXPLAYERS + 1][MAXSLOTS + 1];

bool bRayGun[MAXPLAYERS + 1][MAXSLOTS + 1];

public Action CW3_OnAddAttribute(int slot, int client, const char[] attrib, const char[] plugin, const char[] value, bool whileActive)
{
	if (!StrEqual(plugin, "tf2undead-weapons"))
	{
		return Plugin_Continue;
	}

	Action action;

	if (StrEqual(attrib, "alt-fire blackhole"))
	{
		char sPart[2][12];
		ExplodeString(value, " ", sPart, 2, 12);

		iBlackHole_RequiredAmmo[client][slot] = StringToInt(sPart[0]);	//Required Ammo
		fBlackHole_Duration[client][slot] = StringToFloat(sPart[1]);	//Duration
		bHasBlackHole[client] = false;

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "wunderwaffe projectile"))
	{
		char sPart[2][12];
		ExplodeString(value, " ", sPart, 2, 12);

		fWunder_Damage[client][slot] = StringToFloat(sPart[0]);	//Damage
		fWunder_Radius[client][slot] = StringToFloat(sPart[1]);	//Radius
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "is ray gun"))
	{
		bRayGun[client][slot] = StringToBool(value);

		int weapon = GetPlayerWeaponSlot(client, slot);

		if (IsValidEntity(weapon))
		{
			TF2Attrib_SetByName(weapon, "override projectile type", 8.0);
		}

		action = Plugin_Handled;
	}

	return action;
}

public void CW3_OnWeaponRemoved(int slot, int client)
{
	iBlackHole_RequiredAmmo[client][slot] = 0;
	fBlackHole_Duration[client][slot] = 0.0;
	bHasBlackHole[client] = false;

	fWunder_Damage[client][slot] = 0.0;
	fWunder_Radius[client][slot] = 0.0;

	bRayGun[client][slot] = false;
}

//Black Hole
void AttemptBlackHole(int client, int slot)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || slot == -1)
	{
		return;
	}

	if (iBlackHole_RequiredAmmo[client][slot] > 0 && !bHasBlackHole[client] && TF2_IsPlayerInCondition(client, TFCond_Zoomed))
	{
		int deduct = iBlackHole_RequiredAmmo[client][slot] - 1;

		int weapon = GetPlayerWeaponSlot(client, slot);
		int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");

		if (ammotype != -1)
		{
			int current = GetEntProp(client, Prop_Data, "m_iAmmo", _, ammotype) - deduct;

			if (current <= 0)
			{
				current = 0;
			}

			SetEntProp(client, Prop_Data, "m_iAmmo", current, _, ammotype);
		}

		CreateBlackHole(client, fBlackHole_Duration[client][slot]);
	}
}

void CreateBlackHole(int client, float duration)
{
	float vecLook[3];
	if (!GetClientLookPosition(client, vecLook))
	{
		return;
	}

	TFTeam team = TF2_GetClientTeam(client);

	CreateParticle("eb_tp_vortex01", duration, vecLook);
	CreateParticle(team == TFTeam_Red ? "raygun_projectile_red_crit" : "raygun_projectile_blue_crit", duration, vecLook);
	CreateParticle(team == TFTeam_Red ? "eyeboss_vortex_red" : "eyeboss_vortex_blue", duration, vecLook);

	EmitSoundToAll("tf2zombies/blackhole_spawn.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, vecLook, NULL_VECTOR, true, 0.0);

	bHasBlackHole[client] = true;

	DataPack pack;
	CreateDataTimer(0.1, Timer_Pull, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	WritePackFloat(pack, 0.0);
	WritePackCell(pack, GetClientUserId(client));
	WritePackFloat(pack, duration);
	WritePackFloat(pack, vecLook[0]);
	WritePackFloat(pack, vecLook[1]);
	WritePackFloat(pack, vecLook[2]);
}

public Action Timer_Pull(Handle timer, DataPack pack)
{
	ResetPack(pack);

	float time = ReadPackFloat(pack);
	int client = GetClientOfUserId(ReadPackCell(pack));
	float fDuration = ReadPackFloat(pack);

	float pos[3];
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	if (time >= fDuration)
	{
		if (client > 0)
		{
			bHasBlackHole[client] = false;
		}

		return Plugin_Stop;
	}

	EmitSoundToAll("tf2zombies/blackhole_loop.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_STOPLOOPING, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos, NULL_VECTOR, true, 0.0);

	ResetPack(pack);
	WritePackFloat(pack, time + 0.1);

	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		float cpos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", cpos);

		if (GetVectorDistance(pos, cpos) > 250.0)
		{
			continue;
		}

		float velocity[3];
		MakeVectorFromPoints(pos, cpos, velocity);
		NormalizeVector(velocity, velocity);
		ScaleVector(velocity, -200.0);
		TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, velocity);

		float fSize = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");

		if (fSize > 0.2)
		{
			float temp = TF2Undead_Specials_IsSpecial(entity) ? 0.01 : 0.1;
			SetEntPropFloat(entity, Prop_Send, "m_flModelScale", fSize - temp);
			continue;
		}

		AcceptEntityInput(entity, "Kill");
	}

	return Plugin_Continue;
}

//Wunderwaffe Explosion
public void OnEntityDestroyed(int entity)
{
	if (entity <= MaxClients)
	{
		return;
	}

	char sClassname[32];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	if (StrEqual(sClassname, "tf_projectile_energy_ring"))
	{
		int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

		if (client < 1 || client > MaxClients)
		{
			return;
		}

		int slot = GetClientActiveSlot(client);

		if (slot != -1 && fWunder_Damage[client][slot] > 0.0)
		{
			float vecAngles[3];
			GetClientEyeAngles(client, vecAngles);

			float vecPosition[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecPosition);

			RocketsGameFired(client, vecPosition, vecAngles, GetConVarFloat(convar_WunderwaffeSpeed), fWunder_Damage[client][slot], fWunder_Radius[client][slot]);
		}
	}
}

void RocketsGameFired(int client, float vPosition[3], float vAngles[3], float flSpeed = 650.0, float flDamage = 800.0, float flRadius = 200.0, bool bCritical = true)
{
	char strClassname[32] = "CTFProjectile_Rocket";
	int iRocket = CreateEntityByName("tf_projectile_energy_ball");

	if (IsValidEntity(iRocket))
	{
		float vVelocity[3];
		float vBuffer[3];

		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);

		vVelocity[0] = vBuffer[0] * flSpeed;
		vVelocity[1] = vBuffer[1] * flSpeed;
		vVelocity[2] = vBuffer[2] * flSpeed;

		TeleportEntity(iRocket, vPosition, vAngles, vVelocity);

		SetEntData(iRocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iTeamNum"), GetClientTeam(client), true);
		SetEntData(iRocket, FindSendPropInfo(strClassname, "m_bCritical"), bCritical, true);
		SetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity", client);

		SetEntPropFloat(iRocket, Prop_Data, "m_flRadius", flRadius);
		SetEntPropFloat(iRocket, Prop_Data, "m_flModelScale", flRadius);

		DispatchSpawn(iRocket);

		CreateParticle("critgun_weaponmodel_blu", 0.5, vPosition);

		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
		{
			float vecZombiePos[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecZombiePos);

			if (GetVectorDistance(vPosition, vecZombiePos) <= flRadius)
			{
				SDKHooks_TakeDamage(entity, 0, client, flDamage, DMG_BLAST, GetActiveWeapon(client), NULL_VECTOR, vPosition);
			}
		}
	}
}

//////////////////////////////////////////
//Ray Gun

public void OnArrowCreated(int entity)
{
	if (IsValidEntity(entity))
	{
		int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

		if (client > 0)
		{
			int slot = GetClientActiveSlot(client);

			if (bRayGun[client][slot])
			{
				ReplaceArrowProjectile(client, entity, slot);
			}
		}
	}
}

void ReplaceArrowProjectile(int client, int entity, int slot)
{
	int hLauncher = GetPlayerWeaponSlot(client, slot);

	float vecEyePosition[3];
	GetClientEyePosition(client, vecEyePosition);

	float vecEyeAngles[3];
	GetClientEyeAngles(client, vecEyeAngles);

	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecEyePosition);

	Handle trace = TR_TraceRayFilterEx(vecEyePosition, vecEyeAngles, MASK_SHOT, RayType_Infinite, TraceFilterSelf, client);

	float vecEndPosition[3];
	TR_GetEndPosition(vecEndPosition, trace);

	delete trace;

	float vecMagic[3];
	vecMagic = vecEyeAngles;
	vecMagic[1] -= 45.0;

	float vecProjectileOffset[3];
	GetAngleVectors(vecMagic, vecProjectileOffset, NULL_VECTOR, NULL_VECTOR);

	ScaleVector(vecProjectileOffset, 25.0);

	float vecProjectileSource[3];
	AddVectors(vecEyePosition, vecProjectileOffset, vecProjectileSource);

	bool bCloseRange = GetVectorDistance(vecEyePosition, vecEndPosition, true) < 900.0;

	float vecVelocity[3];

	if (bCloseRange)
	{
		vecProjectileSource = vecEyePosition;
		GetAngleVectors(vecEyeAngles, vecVelocity, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		MakeVectorFromPoints(vecProjectileSource, vecEndPosition, vecVelocity);
	}

	NormalizeVector(vecVelocity, vecVelocity);

	float flVelocityScalar = 1.0;
	Address pAttrib;
	if ((pAttrib = TF2Attrib_GetByName(hLauncher, "Projectile speed increased")) || (pAttrib = TF2Attrib_GetByName(hLauncher, "Projectile speed decreased")))
	{
		flVelocityScalar = TF2Attrib_GetValue(pAttrib);
	}

	ScaleVector(vecVelocity, 1000.0 * flVelocityScalar);

	int manglerShot = CreateEntityByName("tf_projectile_energy_ball");

	if (slot != -1 && IsValidEntity(manglerShot))
	{
		AcceptEntityInput(entity, "Kill");

		SetEntPropEnt(manglerShot, Prop_Send, "m_hLauncher", hLauncher);
		SetEntPropEnt(manglerShot, Prop_Send, "m_hOriginalLauncher", hLauncher);
		SetEntPropEnt(manglerShot, Prop_Send, "m_hOwnerEntity", client);

		SetEntProp(manglerShot, Prop_Send, "m_fEffects", 16);

		// CTFWeaponBaseGun::GetProjectileDamage
		float damage = SDKCall(g_hSDKWeaponGetDamage, hLauncher);

		// CTFBaseRocket::SetDamage(float)
		SDKCall(g_hSDKRocketSetDamage, manglerShot, damage);

		SetEntProp(manglerShot, Prop_Send, "m_iTeamNum", TF2_GetClientTeam(client));

		DispatchKeyValueVector(manglerShot, "origin", vecProjectileSource);
		DispatchKeyValueVector(manglerShot, "basevelocity", vecVelocity);
		DispatchKeyValueVector(manglerShot, "velocity", vecVelocity);
		DispatchSpawn(manglerShot);

		SDKHook(manglerShot, SDKHook_StartTouch, RocketTouch);
	}
}

#define FSOLID_TRIGGER 0x8
#define FSOLID_VOLUME_CONTENTS 0x20

void RocketTouch(int rocket, int other)
{
	int solidFlags = GetEntProp(other, Prop_Send, "m_usSolidFlags");

	if (solidFlags & (FSOLID_TRIGGER | FSOLID_VOLUME_CONTENTS))
	{
		return;
	}

	EmitGameSoundToAll("Weapon_CowMangler.Explode", rocket);

	int client = GetEntPropEnt(rocket, Prop_Data, "m_hOwnerEntity");

	if (client == 0)
	{
		return;
	}

	float vecRocketPos[3];
	GetEntPropVector(rocket, Prop_Data, "m_vecOrigin", vecRocketPos);

	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		float vecZombiePos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecZombiePos);

		if (GetVectorDistance(vecZombiePos, vecRocketPos) <= 80.0)
		{
			SDKHooks_TakeDamage(entity, 0, client, 35.0, DMG_BLAST, GetActiveWeapon(client), NULL_VECTOR, vecRocketPos);
		}
	}
}

public bool TraceFilterSelf(int entity, int contentsMask, int client)
{
	return entity != client;
}
