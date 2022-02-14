//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define EF_BONEMERGE			(1 << 0)
#define EF_BONEMERGE_FASTCULL	(1 << 7)
#define EF_PARENT_ANIMATES		(1 << 9)

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Required Includes
#include <dhooks>
//#include <pluginbot>

//Our Includes
#include <tf2-undead/tf2-undead-zombies>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-specials>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Conversion;
ConVar convar_Default_Class;
ConVar convar_Default_Health;
ConVar convar_Default_Speed;
ConVar convar_Default_Size;
ConVar convar_Default_Damage;
ConVar convar_Hide_Zombie_Models;
ConVar convar_Disable_Gnomes;
ConVar convar_Zombie_Sound_Volume;
ConVar convar_Hitsounds;
ConVar convar_BloodParticles;

//Forwards
Handle hForward_OnZombieSpawn;
Handle hForward_OnZombieSpawn_Post;
Handle hForward_OnZombieDeath;
Handle hForward_OnZombieDeath_Post;
Handle hForward_OnZombieTraceAttack;
Handle hForward_OnZombieTakeDamage;
Handle hForward_OnZombieTakeDamage_Post;
Handle hForward_OnZombieGnomeSpawn;
Handle hForward_OnZombieGnomeSpawn_Post;

//Globals
bool bLate;

float g_fSpeedOverride = -1.0;
bool g_bDisableGnomes;
Handle g_hArray_ZombieSounds;
Handle g_hArray_ZombieTankSounds;

float fCacheCoordinates[3];

int g_iZombieClass[MAX_ENTITY_LIMIT + 1];
float g_fZombieSpeed[MAX_ENTITY_LIMIT + 1];
float g_fZombieDamage[MAX_ENTITY_LIMIT + 1];
int g_iZombieColor[MAX_ENTITY_LIMIT + 1][4];

bool g_bStopZombie[MAX_ENTITY_LIMIT + 1];

char g_sZombieDeathSound[MAX_ENTITY_LIMIT + 1][PLATFORM_MAX_PATH];

//Global Variables
stock char sDefaultModels[9][PLATFORM_MAX_PATH] =
{
	"models/player/scout.mdl",
	"models/player/soldier.mdl",
	"models/player/pyro.mdl",
	"models/player/demo.mdl",
	"models/player/heavy.mdl",
	"models/player/engineer.mdl",
	"models/player/medic.mdl",
	"models/player/sniper.mdl",
	"models/player/spy.mdl"
};

stock char sZombieItems[9][PLATFORM_MAX_PATH] =
{
	"models/player/items/scout/scout_zombie.mdl",
	"models/player/items/soldier/soldier_zombie.mdl",
	"models/player/items/pyro/pyro_zombie.mdl",
	"models/player/items/demo/demo_zombie.mdl",
	"models/player/items/heavy/heavy_zombie.mdl",
	"models/player/items/engineer/engineer_zombie.mdl",
	"models/player/items/medic/medic_zombie.mdl",
	"models/player/items/sniper/sniper_zombie.mdl",
	"models/player/items/spy/spy_zombie.mdl"
};

enum
{
	DONT_BLEED = -1,
	BLOOD_COLOR_RED = 0,
	BLOOD_COLOR_YELLOW,
	BLOOD_COLOR_GREEN,
	BLOOD_COLOR_MECH
};

//Zombie Speed
Handle g_hSDKGetNBPtr;
Handle g_hSDKGetLocomotionInterface;
Handle g_hSDKGetLocomotionGetBot;
Handle g_hGetEntity;
Handle g_hGetRunSpeed;

//Zombie Collisions
Handle g_dhShouldCollideWith;
Handle g_dhIsEntityTraversable;

//Zombie Blood Particles
ArrayList g_hArray_BloodParticles;

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - Zombies",
	author = "Keith Warren (Shaders Allen)",
	description = "Zombies module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-zombies");

	CreateNative("TF2Undead_Zombies_Spawn", Native_SpawnZombie);
	CreateNative("TF2Undead_Zombies_KillAllZombies", Native_KillAllZombies);
	CreateNative("TF2Undead_Zombies_FreezeZombie", Native_FreezeZombie);
	CreateNative("TF2Undead_Zombies_IsZombieFrozen", Native_IsZombieFrozen);

	hForward_OnZombieSpawn = CreateGlobalForward("TF2Undead_OnZombieSpawn", ET_Event, Param_Cell);
	hForward_OnZombieSpawn_Post = CreateGlobalForward("TF2Undead_OnZombieSpawn_Post", ET_Ignore, Param_Cell, Param_Cell);
	hForward_OnZombieDeath = CreateGlobalForward("TF2Undead_OnZombieDeath", ET_Event, Param_Cell);
	hForward_OnZombieDeath_Post = CreateGlobalForward("TF2Undead_OnZombieDeath_Post", ET_Ignore, Param_Cell);
	hForward_OnZombieTraceAttack = CreateGlobalForward("TF2Undead_OnZombieTraceAttack", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef, Param_CellByRef, Param_Cell, Param_Cell);
	hForward_OnZombieTakeDamage = CreateGlobalForward("TF2Undead_OnZombieTakeDamage", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_Cell);
	hForward_OnZombieTakeDamage_Post = CreateGlobalForward("TF2Undead_OnZombieTakeDamage_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Array, Param_Array, Param_Cell);
	hForward_OnZombieGnomeSpawn = CreateGlobalForward("TF2Undead_OnZombieGnomeSpawn", ET_Event, Param_Cell);
	hForward_OnZombieGnomeSpawn_Post = CreateGlobalForward("TF2Undead_OnZombieGnomeSpawn_Post", ET_Ignore, Param_Cell);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_zombies_status", "1");
	convar_Conversion = CreateConVar("sm_undead_zombies_conversion", "1");
	convar_Default_Class = CreateConVar("sm_undead_zombies_default_class", "-1");
	convar_Default_Health = CreateConVar("sm_undead_zombies_default_health", "40");
	convar_Default_Speed = CreateConVar("sm_undead_zombies_default_speed", "55.0");
	convar_Default_Size = CreateConVar("sm_undead_zombies_default_size", "1.0");
	convar_Default_Damage = CreateConVar("sm_undead_zombies_default_damage", "15.0");
	convar_Hide_Zombie_Models = CreateConVar("sm_undead_zombies_hide_model", "1");
	convar_Disable_Gnomes = CreateConVar("sm_undead_zombies_disable_gnomes", "1");
	convar_Zombie_Sound_Volume = CreateConVar("sm_undead_zombies_sounds_volume", "1.0");
	convar_Hitsounds = CreateConVar("sm_undead_zombies_hitsounds", "1");
	convar_BloodParticles = CreateConVar("sm_undead_zombies_blood_particles", "0");

	RegAdminCmd("sm_managezombies", Command_ManageZombies, ADMFLAG_ROOT, "Spawn a zombie.");
	RegAdminCmd("sm_zombie", Command_SpawnZombie, ADMFLAG_ROOT, "Spawn a zombie.");
	RegAdminCmd("sm_spawnzombie", Command_SpawnZombie, ADMFLAG_ROOT, "Spawn a zombie.");
	RegAdminCmd("sm_killzombie", Command_KillZombie, ADMFLAG_ROOT, "Kill a specific zombie.");
	RegAdminCmd("sm_clearzombie", Command_KillZombie, ADMFLAG_ROOT, "Kill a specific zombie.");
	RegAdminCmd("sm_killzombies", Command_KillZombies, ADMFLAG_ROOT, "Kill all zombies on the map.");
	RegAdminCmd("sm_killallzombies", Command_KillZombies, ADMFLAG_ROOT, "Kill all zombies on the map.");
	RegAdminCmd("sm_clearzombies", Command_KillZombies, ADMFLAG_ROOT, "Kill all zombies on the map.");
	RegAdminCmd("sm_pausezombies", Command_PauseZombies, ADMFLAG_ROOT, "Pause all zombies on the map.");
	RegAdminCmd("sm_freezezombie", Command_FreezeZombie, ADMFLAG_ROOT, "Freeze a zombie from moving.");
	RegAdminCmd("sm_setzombiespeed", Command_SetZombieSpeed, ADMFLAG_ROOT, "Force and override the speed of the zombies.");

	HookEvent("teamplay_round_start", OnRoundStart);

	UserMsg BreakModel = GetUserMessageId("BreakModel");

	if (BreakModel != INVALID_MESSAGE_ID)
	{
		HookUserMessage(BreakModel, BreakModel2, true);
	}

	AddNormalSoundHook(OnSoundCreation);

	g_hArray_ZombieSounds = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	PushArrayString(g_hArray_ZombieSounds, "tf2undead/noises/undead_zombie01.wav");
	PushArrayString(g_hArray_ZombieSounds, "tf2undead/noises/undead_zombie02.wav");
	PushArrayString(g_hArray_ZombieSounds, "tf2undead/noises/undead_zombie03.wav");
	PushArrayString(g_hArray_ZombieSounds, "tf2undead/noises/undead_zombie04.wav");
	PushArrayString(g_hArray_ZombieSounds, "tf2undead/noises/undead_zombie05.wav");
	PushArrayString(g_hArray_ZombieSounds, "tf2undead/noises/undead_zombie06.wav");
	PushArrayString(g_hArray_ZombieSounds, "tf2undead/noises/undead_zombie07.wav");

	g_hArray_ZombieTankSounds = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	PushArrayString(g_hArray_ZombieTankSounds, "tf2undead/noises/undead_giant_zombie01.wav");
	PushArrayString(g_hArray_ZombieTankSounds, "tf2undead/noises/undead_giant_zombie02.wav");
	PushArrayString(g_hArray_ZombieTankSounds, "tf2undead/noises/undead_giant_zombie03.wav");

	//Zombies Speed
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(73);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetNBPtr = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(49);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetLocomotionInterface = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(46);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetLocomotionGetBot = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(47);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hGetEntity = EndPrepSDKCall();

	g_hGetRunSpeed = DHookCreate(83, HookType_Raw, ReturnType_Float, ThisPointer_Address, CRobotLocomotion_GetRunSpeed);

	//Zombie Collisions
	g_dhShouldCollideWith = DHookCreate(100, HookType_Raw, ReturnType_Bool, ThisPointer_Address, ShouldCollideWith);
	DHookAddParam(g_dhShouldCollideWith, HookParamType_CBaseEntity);

	g_dhIsEntityTraversable = DHookCreate(95, HookType_Raw, ReturnType_Bool, ThisPointer_Address, IsEntityTraversable);
	DHookAddParam(g_dhIsEntityTraversable, HookParamType_CBaseEntity);
	DHookAddParam(g_dhIsEntityTraversable, HookParamType_Int);

	//Zombie Blood Particles
	g_hArray_BloodParticles = CreateArray(ByteCountToCells(64));
	PushArrayString(g_hArray_BloodParticles, "blood_impact_red_01");
	PushArrayString(g_hArray_BloodParticles, "blood_impact_red_01_chunk");
	PushArrayString(g_hArray_BloodParticles, "blood_impact_red_01_droplets");
	PushArrayString(g_hArray_BloodParticles, "blood_impact_red_01_goop");
	PushArrayString(g_hArray_BloodParticles, "blood_impact_red_01_smalldroplets");
}

public void OnPLuginEnd()
{
	TF2Undead_Zombies_KillAllZombies();
}

public MRESReturn CRobotLocomotion_GetRunSpeed(Address pThis, Handle hReturn, Handle hParams)
{
	Address INextBot2 = SDKCall(g_hSDKGetLocomotionGetBot, pThis);
	int iEntity = SDKCall(g_hGetEntity, INextBot2);
	DHookSetReturn(hReturn, g_fSpeedOverride > -1.0 ? g_fSpeedOverride : g_fZombieSpeed[iEntity]);
	return MRES_Supercede;
}

public Action BreakModel2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	BfReadShort(msg);

	float vec3[3];
	BfReadVecCoord(msg, vec3);

	if (GetVectorDistance(vec3, fCacheCoordinates) <= 10.0)
	{
		fCacheCoordinates[0] = 0.0;
		fCacheCoordinates[1] = 0.0;
		fCacheCoordinates[2] = 0.0;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void OnMapStart()
{
	for (int i = 0; i < GetArraySize(g_hArray_ZombieSounds); i++)
	{
		char sSound[PLATFORM_MAX_PATH];
		GetArrayString(g_hArray_ZombieSounds, i, sSound, sizeof(sSound));

		PrecacheSound(sSound);

		char sDownload[PLATFORM_MAX_PATH];
		FormatEx(sDownload, sizeof(sDownload), "sound/%s", sSound);

		AddFileToDownloadsTable(sDownload);
	}

	for (int i = 0; i < GetArraySize(g_hArray_ZombieTankSounds); i++)
	{
		char sSound[PLATFORM_MAX_PATH];
		GetArrayString(g_hArray_ZombieTankSounds, i, sSound, sizeof(sSound));

		PrecacheSound(sSound);

		char sDownload[PLATFORM_MAX_PATH];
		FormatEx(sDownload, sizeof(sDownload), "sound/%s", sSound);

		AddFileToDownloadsTable(sDownload);
	}
}

public void OnConfigsExecuted()
{
	if (bLate)
	{
		int entity = INVALID_ENT_INDEX;
		while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
		{
			char sClassname[128];
			GetEntityClassname(entity, sClassname, sizeof(sClassname));
			OnEntityCreated(entity, sClassname);
		}

		bLate = false;
	}
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//Fixes a weird issue where zombies would lag the server for a brief time on every 1st spawn but not while other NPCs are active.
	int entity = CreateEntityByName("base_boss");

	if (IsValidEntity(entity))
	{
		float vecTele[3] = {-154.75, -3429.33, -111.37};
		DispatchKeyValueVector(entity, "origin", vecTele);
		DispatchSpawn(entity);
		ActivateEntity(entity);
	}
}

public Action OnSoundCreation(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (entity > MaxClients && IsValidEntity(entity))
	{
		char sClassname[32];
		GetEntityClassname(entity, sClassname, sizeof(sClassname));

		if (StrEqual(sClassname, "tf_zombie") && StrContains(sample, "skelly_") != -1)
		{
			SetEntDataFloat(entity, 15 * 4, GetGameTime() + 1.0);

			if (TF2Undead_Specials_IsSpecial(entity))
			{
				char sSpecial[MAX_NAME_LENGTH];
				TF2Undead_Specials_GetSpecialName(entity, sSpecial, sizeof(sSpecial));

				if (StrEqual(sSpecial, "Tank Heavy"))
				{
					GetArrayString(g_hArray_ZombieTankSounds, GetRandomInt(0, GetArraySize(g_hArray_ZombieTankSounds) - 1), sample, sizeof(sample));
				}
				else
				{
					GetArrayString(g_hArray_ZombieSounds, GetRandomInt(0, GetArraySize(g_hArray_ZombieSounds) - 1), sample, sizeof(sample));
				}
			}
			else
			{
				GetArrayString(g_hArray_ZombieSounds, GetRandomInt(0, GetArraySize(g_hArray_ZombieSounds) - 1), sample, sizeof(sample));
			}

			volume = GetConVarFloat(convar_Zombie_Sound_Volume);
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public Action TF2Undead_OnStartGame(char[] wave_config)
{
	g_fSpeedOverride = -1.0;
}

public void OnClientPutInServer(int client)
{
	if (GetConVarBool(convar_Status))
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (GetConVarBool(convar_Status) && attacker > MaxClients && IsValidEntity(attacker))
	{
		char sClassname[32];
		GetEntityClassname(attacker, sClassname, sizeof(sClassname));

		if (StrEqual(sClassname, "tf_zombie") && damage > 0.0)
		{
			damage = g_fZombieDamage[attacker];
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (StrEqual(classname, "tf_zombie"))
	{
		SDKHook(entity, SDKHook_Spawn, OnZombieSpawn);
		SDKHook(entity, SDKHook_TraceAttack, OnZombieTraceAttack);
		SDKHook(entity, SDKHook_OnTakeDamage, OnZombieTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, OnZombieTakeDamagePost);
	}

	if (StrEqual(classname, "tf_projectile_spellspawnzombie"))
	{
		SDKHook(entity, SDKHook_Spawn, OnZombieSpellSpawn);
		SDKHook(entity, SDKHook_SpawnPost, OnZombieSpellSpawnPost);
	}
}

public void OnEntityDestroyed(int entity)
{
	if (entity <= MaxClients)
	{
		return;
	}

	char sClassname[32];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	if (StrEqual(sClassname, "tf_zombie"))
	{
		g_bStopZombie[entity] = false;

		Call_StartForward(hForward_OnZombieDeath);
		Call_PushCell(entity);
		Call_Finish();

		if (strlen(g_sZombieDeathSound[entity]) > 0)
		{
			if (IsSoundPrecached(g_sZombieDeathSound[entity]))
			{
				EmitSoundToAll(g_sZombieDeathSound[entity], entity);
			}

			g_sZombieDeathSound[entity][0] = '\0';
		}

		Call_StartForward(hForward_OnZombieDeath_Post);
		Call_PushCell(entity);
		Call_Finish();
	}
}

public Action OnZombieSpawn(int entity)
{
	Action results;

	Call_StartForward(hForward_OnZombieSpawn);
	Call_PushCell(entity);
	Call_Finish(results);

	return results;
}

public Action OnZombieTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	Action results;

	Call_StartForward(hForward_OnZombieTraceAttack);
	Call_PushCell(victim);
	Call_PushCellRef(attacker);
	Call_PushCellRef(inflictor);
	Call_PushFloatRef(damage);
	Call_PushCellRef(damagetype);
	Call_PushCellRef(ammotype);
	Call_PushCell(hitbox);
	Call_PushCell(hitgroup);
	Call_Finish(results);

	return results;
}

public Action TF2Undead_OnZombieTraceAttack(int zombie, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (attacker > 0 && hitgroup == 1)
	{
		float fOrigin[3];
		GetEntPropVector(zombie, Prop_Send, "m_vecOrigin", fOrigin);

		fOrigin[2] += 70.0;

		CreateTempParticle("crit_text", fOrigin);

		damage *= 2.0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action OnZombieTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (RoundFloat(damage) > GetEntProp(victim, Prop_Data, "m_iHealth"))
	{
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", fCacheCoordinates);
	}

	Action results;

	Call_StartForward(hForward_OnZombieTakeDamage);
	Call_PushCell(victim);
	Call_PushCellRef(attacker);
	Call_PushCellRef(inflictor);
	Call_PushFloatRef(damage);
	Call_PushCellRef(damagetype);
	Call_PushCellRef(weapon);
	Call_PushArrayEx(damageForce, sizeof(damageForce), SM_PARAM_COPYBACK);
	Call_PushArrayEx(damagePosition, sizeof(damagePosition), SM_PARAM_COPYBACK);
	Call_PushCell(damagecustom);
	Call_Finish(results);

	return results;
}

public void OnZombieTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (GetConVarBool(convar_BloodParticles))
	{
		char sParticle[64];
		GetArrayString(g_hArray_BloodParticles, GetRandomInt(0, GetArraySize(g_hArray_BloodParticles) - 1), sParticle, sizeof(sParticle));

		float vecOrigin[3];
		vecOrigin[0] = damagePosition[0];
		vecOrigin[1] = damagePosition[1];
		vecOrigin[2] = damagePosition[2];

		CreateTempParticle(sParticle, vecOrigin);
	}

	Call_StartForward(hForward_OnZombieTakeDamage_Post);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushCell(inflictor);
	Call_PushFloat(damage);
	Call_PushCell(damagetype);
	Call_PushCell(weapon);
	Call_PushArray(damageForce, sizeof(damageForce));
	Call_PushArray(damagePosition, sizeof(damagePosition));
	Call_PushCell(damagecustom);
	Call_Finish();

	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && IsPlayerAlive(attacker) && !IsFakeClient(attacker))
	{
		if (GetConVarBool(convar_Hitsounds))
		{
			Handle fakeEvent = CreateEvent("npc_hurt", true);
			SetEventInt(fakeEvent, "attacker_player", GetClientUserId(attacker));
			SetEventInt(fakeEvent, "entindex", victim);

			int dmg = RoundFloat(damage);
			int activeWep = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
			int idx;

			if (IsValidEntity(activeWep))
			{
				idx = GetEntProp(activeWep, Prop_Send, "m_iItemDefinitionIndex");
			}

			if (idx == 153)
			{
				dmg *= 2;
			}

			if (idx == 441 || idx == 442 || idx == 588)
			{
				dmg = RoundFloat(float(dmg) * 0.2);
			}

			SetEventInt(fakeEvent, "damageamount", dmg);
			FireEvent(fakeEvent);
		}
	}
}

public Action OnZombieSpellSpawn(int entity)
{
	Action results;

	Call_StartForward(hForward_OnZombieGnomeSpawn);
	Call_PushCell(entity);
	Call_Finish(results);

	return results;
}

public Action OnZombieSpellSpawnPost(int entity)
{
	CreateTimer(1.0, Timer_KillZombieSpell, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillZombieSpell(Handle timer, any data)
{
	int entity = EntRefToEntIndex(data);

	if (IsValidEntity(entity))
	{
		if (GetConVarBool(convar_Disable_Gnomes) || g_bDisableGnomes)
		{
			//AcceptEntityInput(entity, "KillHierarchy");
			SDKHooks_TakeDamage(entity, 0, 0, 999999999.0, DMG_BULLET);
		}
		else
		{
			Call_StartForward(hForward_OnZombieGnomeSpawn_Post);
			Call_PushCell(entity);
			Call_Finish();
		}
	}
}

public Action TF2Undead_OnZombieSpawn(int zombie)
{
	if (GetConVarBool(convar_Conversion))
	{
		if (GetConVarBool(convar_Hide_Zombie_Models)) SetEntityRenderMode(zombie, RENDER_NONE);
		SetBloodColor(zombie, BLOOD_COLOR_RED);
		SetEntProp(zombie, Prop_Send, "m_CollisionGroup", 2);
		RequestFrame(Frame_DelaySpawn, zombie);
	}

	return Plugin_Continue;
}

public void Frame_DelaySpawn(any data)
{
	int entity_zombie = data;

	char sZombie[MAX_NAME_LENGTH];
	FormatEx(sZombie, sizeof(sZombie), "zombie_%i", entity_zombie);
	DispatchKeyValue(entity_zombie, "targetname", sZombie);

	float vecPosition[3];
	GetEntPropVector(entity_zombie, Prop_Send, "m_vecOrigin", vecPosition);

	//Skeleton
	int entity_skeleton = CreateEntityByName("simple_bot");

	if (IsValidEntity(entity_skeleton))
	{
		int class = g_iZombieClass[entity_zombie];
		if (class == -1) class = GetRandomInt(0, sizeof(sDefaultModels));
		if (class == 7 || class == 5) class--;	//Disable sniper and engineer due to bonemerging issues.

		DispatchSpawn(entity_skeleton);

		SetEntityModel(entity_skeleton, sDefaultModels[class]);
		SetEntityMoveType(entity_skeleton, MOVETYPE_NONE);

		SetEntityRenderMode(entity_skeleton, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity_skeleton, g_iZombieColor[entity_zombie][0], g_iZombieColor[entity_zombie][1], g_iZombieColor[entity_zombie][2], g_iZombieColor[entity_zombie][3]);

		SetEntProp(entity_skeleton, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES);
		SetEntProp(entity_skeleton, Prop_Send, "m_CollisionGroup", 2);
		SetEntProp(entity_skeleton, Prop_Send, "m_nSkin", class == 8 ? 22 : 4);

		SetVariantString(sZombie);
		AcceptEntityInput(entity_skeleton, "SetParent");

		SpawnWearable(entity_zombie, "lefteye", sZombieItems[class]);
	}

	Call_StartForward(hForward_OnZombieSpawn_Post);
	Call_PushCell(entity_zombie);
	Call_PushCell(entity_skeleton);
	Call_Finish();
}

int SpawnWearable(int entity_zombie, const char[] sAttach, const char[] sModel, int iSkin = 1)
{
	if (!IsValidEntity(entity_zombie) || strlen(sAttach) == 0)
	{
		return INVALID_ENT_INDEX;
	}

	int entity_attachment = CreateEntityByName("prop_dynamic");

	if (IsValidEntity(entity_attachment))
	{
		DispatchKeyValue(entity_attachment, "model", sModel);
		DispatchKeyValueFloat(entity_attachment, "modelscale", GetEntPropFloat(entity_zombie, Prop_Send, "m_flModelScale"));
		DispatchSpawn(entity_attachment);

		SetEntProp(entity_attachment, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES);
		SetEntProp(entity_attachment, Prop_Send, "m_CollisionGroup", 2);
		SetEntProp(entity_attachment, Prop_Send, "m_nSkin", iSkin);

		SetVariantString("!activator");
		AcceptEntityInput(entity_attachment, "SetParent", entity_zombie);

		SetVariantString(sAttach);
		AcceptEntityInput(entity_attachment, "SetParentAttachmentMaintainOffset", entity_zombie, entity_attachment);

		SetEntityRenderMode(entity_attachment, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity_attachment, g_iZombieColor[entity_zombie][0], g_iZombieColor[entity_zombie][1], g_iZombieColor[entity_zombie][2], g_iZombieColor[entity_zombie][3]);

		return entity_attachment;
	}

	return INVALID_ENT_INDEX;
}

public Action Command_ManageZombies(int client, int args)
{
	if (client == 0)
	{
		return Plugin_Handled;
	}

	Menu menu = CreateMenu(MenuHandler_ManageZombies);
	SetMenuTitle(menu, "Zombie Manager");

	AddMenuItem(menu, "spawn", "Spawn Zombie");
	AddMenuItem(menu, "kill", "Kill Zombie");
	AddMenuItem(menu, "killall", "Kill All Zombies");
	AddMenuItem(menu, "pause", "Pause Zombies");
	AddMenuItem(menu, "freeze", "Freeze Zombie");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_ManageZombies(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "spawn"))
			{
				Command_SpawnZombie(param1, 0);
				Command_ManageZombies(param1, 0);
			}
			else if (StrEqual(sInfo, "kill"))
			{
				Command_KillZombie(param1, 0);
				Command_ManageZombies(param1, 0);
			}
			else if (StrEqual(sInfo, "killall"))
			{
				Command_KillZombies(param1, 0);
				Command_ManageZombies(param1, 0);
			}
			else if (StrEqual(sInfo, "pause"))
			{
				Command_PauseZombies(param1, 0);
				Command_ManageZombies(param1, 0);
			}
			else if (StrEqual(sInfo, "freeze"))
			{
				Command_FreezeZombie(param1, 0);
				Command_ManageZombies(param1, 0);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public Action Command_SpawnZombie(int client, int args)
{
	if (client == 0)
	{
		return Plugin_Handled;
	}

	float fLookpoint[3];
	GetClientLookPosition(client, fLookpoint);

	int entity = SpawnZombie(fLookpoint);

	if (IsValidEntity(entity))
	{
		CPrintToChat(client, "%s You have spawned a zombie!", sGlobalTag);
	}
	else
	{
		CPrintToChat(client, "%s Error spawning this zombie.", sGlobalTag);
	}

	return Plugin_Handled;
}

public Action Command_KillZombie(int client, int args)
{
	if (client == 0)
	{
		return Plugin_Handled;
	}

	int target = GetClientAimTarget(client, false);

	if (IsValidEntity(target))
	{
		char sClassname[128];
		GetEntityClassname(target, sClassname, sizeof(sClassname));

		if (StrEqual(sClassname, "tf_zombie"))
		{
			//AcceptEntityInput(target, "KillHierarchy");
			SDKHooks_TakeDamage(target, 0, 0, 999999999.0, DMG_BULLET);
			CPrintToChat(client, "%s Zombie has been killed.", sGlobalTag);
		}
	}
	else
	{
		CPrintToChat(client, "%s Zombie not found, please aim your crosshair at it.", sGlobalTag);
	}

	return Plugin_Handled;
}

public Action Command_KillZombies(int client, int args)
{
	TF2Undead_Zombies_KillAllZombies();
	CPrintToChat(client, "%s All zombies have been killed.", sGlobalTag);
	return Plugin_Handled;
}

public Action Command_PauseZombies(int client, int args)
{
	char sStatus[12];
	GetCmdArgString(sStatus, sizeof(sStatus));
	bool status = view_as<bool>(StringToInt(sStatus));

	PauseAllZombies(status);
	CPrintToChatAll("%s {white}%N {gray}has {white}%s{gray} the zombies.", sGlobalTag, client, status ? "paused" : "unpaused");

	return Plugin_Handled;
}

public Action Command_FreezeZombie(int client, int args)
{
	int target = GetClientAimTarget(client, false);

	if (IsValidEntity(target))
	{
		char sClassname[128];
		GetEntityClassname(target, sClassname, sizeof(sClassname));

		if (StrEqual(sClassname, "tf_zombie"))
		{
			g_bStopZombie[target] = !g_bStopZombie[target];
			CPrintToChat(client, "%s Zombie has been %s.", sGlobalTag, g_bStopZombie[target] ? "frozen" : "unfrozen");
		}
	}

	return Plugin_Handled;
}

public void OnGameFrame()
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		if (g_bStopZombie[entity])
		{
			/*INextBot bot = PluginBot_GetNextBotOfEntity(entity);

			ILocomotion locom = bot.GetLocomotionInterface();
			locom.Reset();
			//locom.Stop();
			locom.SetDesiredSpeed(0.0);
			locom.SetSpeedLimit(0.0);

			DHookRaw(g_dhShouldCollideWith, true, (view_as<Address>(locom)));
			DHookRaw(g_dhIsEntityTraversable, true, (view_as<Address>(locom)));
			*/
		}
	}
}

public MRESReturn ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)
{
	/*int entity = DHookGetParam(hParams, 1);

	char sClassname[128];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	if (StrEqual(sClassname, "func_brush"))
	{
	DHookSetReturn(hReturn, true);
	return MRES_Supercede;
	}*/

	DHookSetReturn(hReturn, false);
	return MRES_Ignored;
}

public MRESReturn IsEntityTraversable(Address pThis, Handle hReturn, Handle hParams)
{
	/*int entity = DHookGetParam(hParams, 1);

	char sClassname[128];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	if (StrEqual(sClassname, "func_brush"))
	{
	DHookSetReturn(hReturn, false);
	return MRES_Supercede;
	}*/

	DHookSetReturn(hReturn, true);
	return MRES_Ignored;
}

public Action Command_SetZombieSpeed(int client, int args)
{
	char sArg[32];
	GetCmdArgString(sArg, sizeof(sArg));
	g_fSpeedOverride = StringToFloat(sArg);
	PrintToChat(client, "Speed set to %f!", g_fSpeedOverride);
	return Plugin_Handled;
}

public int Native_SpawnZombie(Handle plugin, int numParams)
{
	int size;

	float vecCoordinates[3];
	GetNativeArray(1, vecCoordinates, sizeof(vecCoordinates));

	float vecAngles[3];
	GetNativeArray(2, vecAngles, sizeof(vecAngles));

	GetNativeStringLength(9, size);
	char[] sSpawnSound = new char[size + 1];
	GetNativeString(9, sSpawnSound, size + 1);

	GetNativeStringLength(10, size);
	char[] sDeathSound = new char[size + 1];
	GetNativeString(10, sDeathSound, size + 1);

	GetNativeStringLength(11, size);
	char[] sParticle = new char[size + 1];
	GetNativeString(11, sParticle, size + 1);

	int iColor[4];
	GetNativeArray(8, iColor, sizeof(iColor));

	return SpawnZombie(vecCoordinates, vecAngles, GetNativeCell(3), GetNativeCell(4), GetNativeCell(5), GetNativeCell(6), GetNativeCell(7), iColor, sSpawnSound, sDeathSound, sParticle);
}

int SpawnZombie(float coordinates[3], float angles[3] = NULL_VECTOR, int class = -1, int health = -1, float speed = -1.0, float size = -1.0, float damage = -1.0, int color[4] = {255, 255, 255, 255}, const char[] spawn_sound = "", const char[] death_sound = "", const char[] particle = "")
{
	if (class == -1)
	{
		class = GetConVarInt(convar_Default_Class);
	}

	if (health == -1)
	{
		health = GetConVarInt(convar_Default_Health);
	}

	if (speed == -1.0)
	{
		speed = GetConVarFloat(convar_Default_Speed);
	}

	if (size == -1.0)
	{
		size = GetConVarFloat(convar_Default_Size) + GetRandomFloat(-0.2, 0.2);
	}

	if (damage == -1.0)
	{
		damage = GetConVarFloat(convar_Default_Damage);
	}

	int entity = CreateEntityByName("tf_zombie");

	if (IsValidEntity(entity))
	{
		g_iZombieClass[entity] = class;

		DispatchKeyValueVector(entity, "origin", coordinates);
		DispatchKeyValueVector(entity, "angles", angles);
		DispatchSpawn(entity);

		SetEntProp(entity, Prop_Data, "m_iHealth", health);
		SetEntPropFloat(entity, Prop_Data, "m_flModelScale", size);

		if (g_hSDKGetNBPtr != null && g_hSDKGetLocomotionInterface != null)
		{
			Address pNB = SDKCall(g_hSDKGetNBPtr, entity);
			Address pLocomotion = SDKCall(g_hSDKGetLocomotionInterface, pNB);

			if (pLocomotion != Address_Null)
			{
				DHookRaw(g_hGetRunSpeed, true, pLocomotion);
			}
		}

		g_fZombieSpeed[entity] = speed;
		g_fZombieDamage[entity] = damage;
		g_iZombieColor[entity] = color;

		if (strlen(spawn_sound) > 0 && IsSoundPrecached(spawn_sound))
		{
			EmitSoundToAll(spawn_sound);
		}

		if (strlen(death_sound) > 0 && IsSoundPrecached(death_sound))
		{
			strcopy(g_sZombieDeathSound[entity], PLATFORM_MAX_PATH, death_sound);
		}

		if (strlen(particle) > 0)
		{
			AttachParticle(entity, particle, 0.0, "flag");
		}
	}

	return entity;
}

public int Native_KillAllZombies(Handle plugin, int numParams)
{
	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		if (!TF2Undead_Specials_IsSpecial(entity))
		{
			//AcceptEntityInput(entity, "KillHierarchy");
			SDKHooks_TakeDamage(entity, 0, 0, 999999999.0, DMG_BULLET);
		}
	}
}

public int Native_FreezeZombie(Handle plugin, int numParams)
{
	g_bStopZombie[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_IsZombieFrozen(Handle plugin, int numParams)
{
	return g_bStopZombie[GetNativeCell(1)];
}

stock int GetBloodColor(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_bloodColor");
}

stock void SetBloodColor(int entity, int blood_color)
{
	SetEntProp(entity, Prop_Data, "m_bloodColor", blood_color);
}
