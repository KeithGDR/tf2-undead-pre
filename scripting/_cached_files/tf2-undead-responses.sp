//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>

//External Includes
#include <sourcemod-misc>

//Our Includes
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-machines>
#include <tf2-undead/tf2-undead-powerups>
#include <tf2-undead/tf2-undead-specials>
#include <tf2-undead/tf2-undead-weaponbox>
#include <tf2-undead/tf2-undead-weapons>
#include <tf2-undead/tf2-undead-zombies>

//ConVars

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - Responses",
	author = "Keith Warren (Drixevel)",
	description = "Responses module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
}

public void TF2Undead_OnMachinePurchased_Post(int client, const char[] machine)
{
	SpeakResponseConcept(client, "TLK_PLAYER_CHEERS");
}

public void TF2Undead_OnPowerupPickup_Post(int powerup, int client)
{
	SpeakResponseConcept(client, "TLK_PLAYER_CHEERS");
}

public Action TF2Undead_OnWaveStart(int wave)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			SpeakResponseConcept(i, "TLK_MVM_WAVE_START");
		}
	}
}

public void TF2Undead_OnEndGame_Post(bool won)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			SpeakResponseConcept(i, "TLK_GAME_OVER_COMP");
		}
	}
}

public Action TF2Undead_OnZombieTakeDamage(int zombie, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker > 0 && GetEntProp(zombie, Prop_Data, "m_iHealth") >= damage && GetRandomInt(1, 100) >= 80)
	{
		SpeakResponseConcept(attacker, "TLK_PLAYER_JEERS");
	}
}

public void TF2Undead_OnSpecialSpawn_Post(int entity, const char[] type)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && StrEqual(type, "Tank Heavy") && GetRandomInt(1, 10) >= 5)
		{
			SpeakResponseConcept(i, "TLK_MVM_SENTRY_BUSTER");
		}
	}
}

public void TF2Undead_OnWeaponBoxUsed_Post(int client, const char[] weapon_won)
{
	SpeakResponseConcept(client, "TLK_MVM_LOOT_ULTRARARE");
}

public void TF2Undead_OnWeaponPurchased_Post(int client, const char[] weapon_name)
{
	SpeakResponseConcept(client, "TLK_MVM_LOOT_RARE");
}
