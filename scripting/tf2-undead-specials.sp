//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2-undead/tf2-undead-specials>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-zombies>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;

//Forwards
Handle g_hForward_OnSpecialSpawn_Post;

//Globals
bool bLate;

//Global Variables
ArrayList g_hArray_SpecialNames;
StringMap g_hTrie_Specials;

char g_sSpecialName[MAX_ENTITY_LIMIT + 1][MAX_NAME_LENGTH];
bool g_bIsIgnitionZombie[MAX_ENTITY_LIMIT + 1];

ArrayList g_hArray_ScheduledSpawns_Names;
ArrayList g_hArray_ScheduledSpawns_VectorSpawn;

float g_fLastSpawn;
float g_fNextSpawn;

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - Specials",
	author = "Keith Warren (Shaders Allen)",
	description = "The specials module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-specials");

	CreateNative("TF2Undead_Specials_Spawn", Native_Spawn);
	CreateNative("TF2Undead_Specials_IsSpecial", Native_IsSpecial);
	CreateNative("TF2Undead_Specials_KillAllSpecials", Native_KillAllSpecials);
	CreateNative("TF2Undead_Specials_GetSpecialName", Native_GetSpecialName);
	CreateNative("TF2Undead_Specials_ScheduleSpawn", Native_ScheduleSpawn);

	g_hForward_OnSpecialSpawn_Post = CreateGlobalForward("TF2Undead_OnSpecialSpawn_Post", ET_Ignore, Param_Cell, Param_String);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_specials_status", "1");

	RegAdminCmd("sm_specials", Command_Specials, ADMFLAG_ROOT, "Displays a menu to spawn special zombies.");
	RegAdminCmd("sm_killspecials", Command_KillSpecials, ADMFLAG_ROOT, "Kill all special zombies on the map.");
	RegAdminCmd("sm_killallspecials", Command_KillSpecials, ADMFLAG_ROOT, "Kill all special zombies on the map.");
	RegAdminCmd("sm_clearspecials", Command_KillSpecials, ADMFLAG_ROOT, "Kill all special zombies on the map.");

	g_hArray_SpecialNames = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
	g_hTrie_Specials = CreateTrie();

	g_hArray_ScheduledSpawns_Names = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
	g_hArray_ScheduledSpawns_VectorSpawn = CreateArray(3);

	CreateTimer(1.0, Timer_SpawnScheduledSpecials, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	TF2Undead_Specials_KillAllSpecials();
}

public void OnMapStart()
{
	PrecacheSound("mvm/mvm_warning.wav");
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	ParseSpecialsConfig();

	if (bLate)
	{
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
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

void ParseSpecialsConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/undead/specials.cfg");

	KeyValues kv = CreateKeyValues("undead_specials");

	if (FileToKeyValues(kv, sPath) && KvGotoFirstSubKey(kv))
	{
		ClearArray(g_hArray_SpecialNames);
		ClearTrieSafe(g_hTrie_Specials);

		do
		{
			char sName[MAX_NAME_LENGTH];
			KvGetSectionName(kv, sName, sizeof(sName));
			PushArrayString(g_hArray_SpecialNames, sName);

			StringMap trie = CreateTrie();

			int iClass = KvGetNum(kv, "class");
			SetTrieValue(trie, "class", iClass);

			float fSize = KvGetFloat(kv, "size");
			SetTrieValue(trie, "size", fSize);

			int iHealth = KvGetNum(kv, "health");
			SetTrieValue(trie, "health", iHealth);

			float fSpeed = KvGetFloat(kv, "speed");
			SetTrieValue(trie, "speed", fSpeed);

			float fDamage = KvGetFloat(kv, "damage");
			SetTrieValue(trie, "damage", fDamage);

			int iColor[4];
			KvGetColor(kv, "color", iColor[0], iColor[1], iColor[2], iColor[3]);
			SetTrieArray(trie, "color", iColor, sizeof(iColor));

			char sSpawnSound[PLATFORM_MAX_PATH];
			KvGetString(kv, "spawn_sound", sSpawnSound, sizeof(sSpawnSound));
			SetTrieString(trie, "spawn_sound", sSpawnSound);

			char sDeathSound[PLATFORM_MAX_PATH];
			KvGetString(kv, "death_sound", sDeathSound, sizeof(sDeathSound));
			SetTrieString(trie, "death_sound", sDeathSound);

			char sParticle[PLATFORM_MAX_PATH];
			KvGetString(kv, "particle", sParticle, sizeof(sParticle));
			SetTrieString(trie, "particle", sParticle);

			SetTrieValue(g_hTrie_Specials, sName, trie);
		}
		while (KvGotoNextKey(kv));
	}

	CloseHandle(kv);
}

public Action Command_Specials(int client, int args)
{
	Menu menu = CreateMenu(MenuHandler_Specials);
	SetMenuTitle(menu, "Spawn a special zombie:");

	for (int i = 0; i < GetArraySize(g_hArray_SpecialNames); i++)
	{
		char sName[MAX_NAME_LENGTH];
		GetArrayString(g_hArray_SpecialNames, i, sName, sizeof(sName));

		AddMenuItem(menu, sName, sName);
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_Specials(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			float vecCoordinates[3];
			GetClientLookPosition(param1, vecCoordinates);

			SpawnSpecial(sInfo, vecCoordinates);
			CPrintToChat(param1, "Special zombie spawned: %s", sInfo);

			Command_Specials(param1, 0);
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public Action Command_KillSpecials(int client, int args)
{
	TF2Undead_Specials_KillAllSpecials();
	CPrintToChat(client, "%s All special zombies have been killed.", sGlobalTag);
	return Plugin_Handled;
}

public int Native_Spawn(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sName = new char[size + 1];
	GetNativeString(1, sName, size + 1);

	float vecCoordinates[3];
	GetNativeArray(2, vecCoordinates, sizeof(vecCoordinates));

	float vecAngles[3];
	GetNativeArray(3, vecAngles, sizeof(vecAngles));

	return SpawnSpecial(sName, vecCoordinates, vecAngles);
}

public int Native_IsSpecial(Handle plugin, int numParams)
{
	return strlen(g_sSpecialName[GetNativeCell(1)]) > 0;
}

int SpawnSpecial(const char[] name, const float vecCoordinates[3], const float vecAngles[3] = NULL_VECTOR)
{
	int entity = INVALID_ENT_INDEX;

	StringMap trie;
	GetTrieValue(g_hTrie_Specials, name, trie);

	if (trie == null)
	{
		return entity;
	}

	int iClass;
	GetTrieValue(trie, "class", iClass);

	float fSize;
	GetTrieValue(trie, "size", fSize);

	int iHealth;
	GetTrieValue(trie, "health", iHealth);

	float fSpeed;
	GetTrieValue(trie, "speed", fSpeed);

	float fDamage;
	GetTrieValue(trie, "damage", fDamage);

	int iColor[4];
	GetTrieArray(trie, "color", iColor, sizeof(iColor));

	char sSpawnSound[PLATFORM_MAX_PATH];
	GetTrieString(trie, "spawn_sound", sSpawnSound, sizeof(sSpawnSound));

	char sDeathSound[PLATFORM_MAX_PATH];
	GetTrieString(trie, "death_sound", sDeathSound, sizeof(sDeathSound));

	char sParticle[PLATFORM_MAX_PATH];
	GetTrieString(trie, "particle", sParticle, sizeof(sParticle));

	entity = TF2Undead_Zombies_Spawn(vecCoordinates, vecAngles, iClass, iHealth, fSpeed, fSize, fDamage, iColor, sSpawnSound, sDeathSound, sParticle);

	if (IsValidEntity(entity))
	{
		strcopy(g_sSpecialName[entity], PLATFORM_MAX_PATH, name);

		if (StrEqual(name, "Explosive Demo"))
		{
			SDKHook(entity, SDKHook_OnTakeDamagePost, ExplosiveDemo_OnTakeDamagePost);
		}
		else if (StrEqual(name, "Ignition Pyro"))
		{
			g_bIsIgnitionZombie[entity] = true;
		}

		Call_StartForward(g_hForward_OnSpecialSpawn_Post);
		Call_PushCell(entity);
		Call_PushString(name);
		Call_Finish();

		CPrintToChatAll("%s A {white}%s {gray}has been spawned!", sGlobalTag, name);
		EmitSoundToAll("mvm/mvm_warning.wav");
	}

	return entity;
}

public void ExplosiveDemo_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	float vecOrigin[3];
	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vecOrigin);

	Explode(vecOrigin, 150.0, 150.0, "hightower_explosion"/*, "ui/duel_challenge_rejected_with_restriction.wav"*/);
	AcceptEntityInput(victim, "Kill");
}

void Explode(float flPos[3], float flDamage, float flRadius, const char[] strParticle/*, const char[] strSound*/)
{
    int iBomb = CreateEntityByName("tf_generic_bomb");
    DispatchKeyValueVector(iBomb, "origin", flPos);
    DispatchKeyValueFloat(iBomb, "damage", flDamage);
    DispatchKeyValueFloat(iBomb, "radius", flRadius);
    DispatchKeyValue(iBomb, "health", "1");
    DispatchKeyValue(iBomb, "explode_particle", strParticle);
    //DispatchKeyValue(iBomb, "sound", strSound);
    DispatchSpawn(iBomb);

    AcceptEntityInput(iBomb, "Detonate");
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (g_bIsIgnitionZombie[attacker])
	{
		IgniteEntity(victim, 5.0);
	}
}

public void OnEntityDestroyed(int entity)
{
	if (entity > MaxClients)
	{
		g_sSpecialName[entity][0] = '\0';
		g_bIsIgnitionZombie[entity] = false;
	}
}

public int Native_KillAllSpecials(Handle plugin, int numParams)
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		if (TF2Undead_Specials_IsSpecial(entity))
		{
			//AcceptEntityInput(entity, "KillHierarchy");
			SDKHooks_TakeDamage(entity, 0, 0, 999999999.0, DMG_BULLET);
			g_sSpecialName[entity][0] = '\0';
		}
	}
}

public int Native_GetSpecialName(Handle plugin, int numParams)
{
	SetNativeString(2, g_sSpecialName[GetNativeCell(1)], GetNativeCell(3));
}

public int Native_ScheduleSpawn(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sSpecial = new char[size + 1];
	GetNativeString(1, sSpecial, size + 1);

	float vecOrigin[3];
	GetNativeArray(2, vecOrigin, sizeof(vecOrigin));

	PushArrayString(g_hArray_ScheduledSpawns_Names, sSpecial);
	PushArrayArray(g_hArray_ScheduledSpawns_VectorSpawn, vecOrigin, sizeof(vecOrigin));
}

public Action Timer_SpawnScheduledSpecials(Handle timer)
{
	int length = GetArraySize(g_hArray_ScheduledSpawns_Names);

	if (length == 0 || TF2Undead_IsInLobby() || TF2Undead_IsWavePaused() || GetGameTime() - g_fLastSpawn <= g_fNextSpawn)
	{
		return Plugin_Continue;
	}

	int random = GetRandomInt(0, length - 1);

	char sSpecial[MAX_NAME_LENGTH];
	GetArrayString(g_hArray_ScheduledSpawns_Names, random, sSpecial, sizeof(sSpecial));

	float vecPosition[3];
	GetArrayArray(g_hArray_ScheduledSpawns_VectorSpawn, random, vecPosition, sizeof(vecPosition));

	SpawnSpecial(sSpecial, vecPosition);

	RemoveFromArray(g_hArray_ScheduledSpawns_Names, random);
	RemoveFromArray(g_hArray_ScheduledSpawns_VectorSpawn, random);

	LoadNextSpawn();

	return Plugin_Continue;
}

void ClearScheduledSpawns()
{
	ClearArray(g_hArray_ScheduledSpawns_Names);
	ClearArray(g_hArray_ScheduledSpawns_VectorSpawn);

	g_fLastSpawn = 0.0;
	g_fNextSpawn = 0.0;
}

void LoadNextSpawn()
{
	g_fLastSpawn = GetGameTime();
	g_fNextSpawn = GetRandomFloat(12.0, 48.0);
}

public Action TF2Undead_OnWaveStart(int wave)
{
	LoadNextSpawn();
}

public Action TF2Undead_OnWaveEnd(int wave, int next_wave)
{
	ClearScheduledSpawns();
}

public Action TF2Undead_OnEndGame(bool won)
{
	ClearScheduledSpawns();
}
