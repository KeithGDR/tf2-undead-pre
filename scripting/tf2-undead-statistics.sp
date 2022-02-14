//Pragmas
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <sdkhooks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2-undead/tf2-undead-statistics>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-machines>
#include <tf2-undead/tf2-undead-weaponbox>
#include <tf2-undead/tf2-undead-weapons>
#include <tf2-undead/tf2-undead-zombies>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_DatabaseConfig;
ConVar convar_Table_Statistics;

//Globals
bool g_blate;
Database g_Database;

enum eStats
{
	zombie_kills,		//Done
	waves_completed,	//Done
	games_total,		//Done
	games_won,			//Done
	Float:damage_taken,	//Done
	Float:damage_done,	//Done
	Float:time_played,	//Done
	weaponcrates,		//Done
	weaponspurchased,	//Done
	machinespurchased,	//Done
	powerups,			//Done
};

int g_iStatistics[MAXPLAYERS + 1][eStats];
char g_sFirstJoin[MAXPLAYERS + 1][64];

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - Statistics",
	author = "Keith Warren (Shaders Allen)",
	description = "Statistics module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-statistics");

	CreateNative("TF2Undead_Statistics_ShowStatisticsMenu", Native_ShowStatisticsMenu);

	g_blate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_statistics_status", "1");
	convar_DatabaseConfig = CreateConVar("sm_undead_statistics_database_config", "default");
	convar_Table_Statistics = CreateConVar("sm_undead_statistics_table_statistics", "undead_statistics");

	HookEvent("player_disconnect", Event_OnPlayerDisconnect);

	RegConsoleCmd("sm_statistics", Command_Statistics, "Show your Undead statistics.");
	RegConsoleCmd("sm_stats", Command_Statistics, "Show your Undead statistics.");
	RegConsoleCmd("sm_stat", Command_Statistics, "Show your Undead statistics.");
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (g_Database == null)
	{
		char sDatabase[256];
		GetConVarString(convar_DatabaseConfig, sDatabase, sizeof(sDatabase));
		SQL_TConnect(OnSQLConnect, sDatabase);
	}
}

public void OnClientPutInServer(int client)
{
	if (!GetConVarBool(convar_Status) || IsFakeClient(client))
	{
		return;
	}

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	if (g_Database != null)
	{
		char sTable_Statistics[32];
		GetConVarString(convar_Table_Statistics, sTable_Statistics, sizeof(sTable_Statistics));

		char sQuery[MAX_QUERY_LENGTH];
		FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM `%s` WHERE steamid = '%i';", sTable_Statistics, GetSteamAccountID(client));
		SQL_TQuery(g_Database, TQuery_OnPullStatistics, sQuery, GetClientUserId(client));
	}
}

public void TQuery_OnPullStatistics(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Error parsing client statistics: %s", error);
		return;
	}

	int client = GetClientOfUserId(data);

	if (!IsPlayerIndex(client))
	{
		return;
	}

	if (SQL_FetchRow(hndl))
	{
		g_iStatistics[client][zombie_kills] = SQL_FetchInt(hndl, 3);
		g_iStatistics[client][waves_completed] = SQL_FetchInt(hndl, 4);
		g_iStatistics[client][games_total] = SQL_FetchInt(hndl, 5);
		g_iStatistics[client][games_won] = SQL_FetchInt(hndl, 6);
		g_iStatistics[client][damage_taken] = SQL_FetchFloat(hndl, 7);
		g_iStatistics[client][damage_done] = SQL_FetchFloat(hndl, 8);
		g_iStatistics[client][time_played] = SQL_FetchFloat(hndl, 9);
		g_iStatistics[client][weaponcrates] = SQL_FetchInt(hndl, 10);
		g_iStatistics[client][weaponspurchased] = SQL_FetchInt(hndl, 11);
		g_iStatistics[client][machinespurchased] = SQL_FetchInt(hndl, 12);
		g_iStatistics[client][powerups] = SQL_FetchInt(hndl, 13);

		SQL_FetchString(hndl, 14, g_sFirstJoin[client], sizeof(g_sFirstJoin[]));
	}

	char sTable_Statistics[32];
	GetConVarString(convar_Table_Statistics, sTable_Statistics, sizeof(sTable_Statistics));

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	int size = 2 * strlen(sName) + 1;
	char[] sEscapedName = new char[size];
	SQL_EscapeString(g_Database, sName, sEscapedName, size);

	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `%s` (name, steamid, zombie_kills, waves_completed, games_total, games_won, damage_taken, damage_done, time_played, weaponcrates, weaponspurchased, machinespurchased, powerups) VALUES ('%s', '%i', '0', '0', '0', '0', '0.0', '0.0', '0.0', '0', '0', '0', '0') ON DUPLICATE KEY UPDATE name = '%s', last_updated = NOW();", sTable_Statistics, sEscapedName, GetSteamAccountID(client), sEscapedName);
	SQL_VoidQuery(g_Database, sQuery);
}

public void OnClientDisconnect(int client)
{
	if (g_Database != null)
	{
		char sTable_Statistics[32];
		GetConVarString(convar_Table_Statistics, sTable_Statistics, sizeof(sTable_Statistics));

		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		int size = 2 * strlen(sName) + 1;
		char[] sEscapedName = new char[size];
		SQL_EscapeString(g_Database, sName, sEscapedName, size);

		char sQuery[MAX_QUERY_LENGTH];
		FormatEx(sQuery, sizeof(sQuery), "UPDATE `%s` SET name = '%s', zombie_kills = '%i', waves_completed = '%i', games_total = '%i', games_won = '%i', damage_taken = '%f', damage_done = '%f', weaponcrates = '%i', weaponspurchased = '%i', machinespurchased = '%i', powerups = '%i' WHERE steamid = '%i';", sTable_Statistics, sEscapedName, g_iStatistics[client][zombie_kills], g_iStatistics[client][waves_completed], g_iStatistics[client][games_total], g_iStatistics[client][games_won], g_iStatistics[client][damage_taken], g_iStatistics[client][damage_done], g_iStatistics[client][weaponcrates], g_iStatistics[client][weaponspurchased], g_iStatistics[client][machinespurchased], g_iStatistics[client][powerups], GetSteamAccountID(client));
		SQL_VoidQuery(g_Database, sQuery);
	}

	g_iStatistics[client][zombie_kills] = 0;
	g_iStatistics[client][waves_completed] = 0;
	g_iStatistics[client][games_total] = 0;
	g_iStatistics[client][games_won] = 0;
	g_iStatistics[client][damage_taken] = 0.0;
	g_iStatistics[client][damage_done] = 0.0;
	g_iStatistics[client][time_played] = 0.0;
	g_iStatistics[client][weaponcrates] = 0;
	g_iStatistics[client][weaponspurchased] = 0;
	g_iStatistics[client][machinespurchased] = 0;
	g_iStatistics[client][powerups] = 0;
}

public void Event_OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if (!IsPlayerIndex(client) || IsFakeClient(client))
	{
		return;
	}

	if (g_Database != null)
	{
		char sTable_Statistics[32];
		GetConVarString(convar_Table_Statistics, sTable_Statistics, sizeof(sTable_Statistics));

		char sQuery[MAX_QUERY_LENGTH];
		FormatEx(sQuery, sizeof(sQuery), "UPDATE `%s` SET time_played = time_played + '%f' WHERE steamid = '%i';", sTable_Statistics, GetClientTime(client), GetSteamAccountID(client));
		SQL_VoidQuery(g_Database, sQuery);
	}
}

public void OnSQLConnect(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Error connecting to database: %s", error);
		return;
	}

	if (g_Database != null)
	{
		CloseHandle(hndl);
		return;
	}

	g_Database = view_as<Database>(hndl);
	LogMessage("Successfully connected to database.");

	char sTable_Statistics[32];
	GetConVarString(convar_Table_Statistics, sTable_Statistics, sizeof(sTable_Statistics));

	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` INT NOT NULL AUTO_INCREMENT , `name` VARCHAR(32) NOT NULL DEFAULT '' , `steamid` INT(32) NOT NULL , `zombie_kills` INT(12) NOT NULL , `waves_completed` INT(12) NOT NULL , `games_total` INT(12) NOT NULL , `games_won` INT(12) NOT NULL , `damage_taken` FLOAT NOT NULL , `damage_done` FLOAT NOT NULL , `time_played` FLOAT NOT NULL , `weaponcrates` INT(12) NOT NULL , `weaponspurchased` INT(12) NOT NULL , `machinespurchased` INT(12) NOT NULL , `powerups` INT(12) NOT NULL , `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP , `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP , PRIMARY KEY (`id`), UNIQUE (`steamid`)) ENGINE = InnoDB;", sTable_Statistics);
	SQL_VoidQuery(g_Database, sQuery);

	if (g_blate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}

		g_blate = false;
	}
}

public Action Command_Statistics(int client, int args)
{
	if (!GetConVarBool(convar_Status) || !IsPlayerIndex(client))
	{
		return Plugin_Handled;
	}

	if (args > 0)
	{
		char sTarget[MAX_TARGET_LENGTH];
		GetCmdArgString(sTarget, sizeof(sTarget));

		int target = FindTarget(client, sTarget, true, false);

		if (!IsPlayerIndex(target))
		{
			CPrintToChat(client, "%s Error displaying statistics, invalid search result.", sGlobalTag);
			return Plugin_Handled;
		}

		ShowClientStats(client, target);
		return Plugin_Handled;
	}

	ShowStatisticsMenu(client);
	return Plugin_Handled;
}

void ShowStatisticsMenu(int client)
{
	if (!GetConVarBool(convar_Status) || !IsClientInGame(client))
	{
		return;
	}

	Menu menu = CreateMenu(MenuHandler_StatisticsMenu);
	SetMenuTitle(menu, "TF2 Undead - Statistics\nLevel: 1 - Experience: [0/3000]\n \n");

	AddMenuItem(menu, "statistics", "Show your Statistics");
	AddMenuItem(menu, "top10_waves", "Show top 10 players via waves");
	AddMenuItem(menu, "top10_games", "Show top 10 players via games won");
	AddMenuItem(menu, "top10_zombies", "Show top 10 players via zombies killed");
	AddMenuItem(menu, "top10_played", "Show top 10 players via time played");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_StatisticsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "statistics"))
			{
				ShowClientStats(param1, param1);
			}
			else if (StrEqual(sInfo, "top10_waves"))
			{

			}
			else if (StrEqual(sInfo, "top10_games"))
			{

			}
			else if (StrEqual(sInfo, "top10_zombies"))
			{

			}
			else if (StrEqual(sInfo, "top10_played"))
			{

			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void ShowClientStats(int client, int target)
{
	if (!GetConVarBool(convar_Status) || !IsPlayerIndex(client) || !IsPlayerIndex(target))
	{
		return;
	}

	Panel panel = new Panel();

	char sTitle[256];
	FormatEx(sTitle, sizeof(sTitle), client == target ? "Your Statistics:\n \n" : "%N's Statistics:\n \n", target);
	panel.SetTitle(sTitle);

	char sTime[32];
	FormatSeconds(g_iStatistics[target][time_played] + GetClientTime(target), sTime, sizeof(sTime), "%M/%D/%M - %S seconds");

	char sItem[64];

	FormatEx(sItem, sizeof(sItem), "First Joined: %s", g_sFirstJoin[target]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Time Played: %s", sTime);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Zombies Killed: %i", g_iStatistics[target][zombie_kills]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Damage Done: %.2f", g_iStatistics[target][damage_done]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Damage Taken: %.2f", g_iStatistics[target][damage_taken]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Waves Won: %i", g_iStatistics[target][waves_completed]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Games Won: %i", g_iStatistics[target][games_won]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Total Games: %i", g_iStatistics[target][games_total]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Weapon Boxes Opened: %i", g_iStatistics[target][weaponcrates]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Weapons Purchased: %i", g_iStatistics[target][weaponspurchased]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Machines Used: %i", g_iStatistics[target][machinespurchased]);
	panel.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Powerups Obtained: %i\n \n", g_iStatistics[target][powerups]);
	panel.DrawText(sItem);

	panel.DrawItem("Back");

	panel.Send(client, PanelHandler_ClientStatistics, 60);
}

public int PanelHandler_ClientStatistics(Menu menu, MenuAction action, int param1, int param2)
{
	ShowStatisticsMenu(param1);
}

//Waves Completed
public Action TF2Undead_OnWaveEnd(int wave, int next_wave)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Continue;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			g_iStatistics[i][waves_completed]++;
		}
	}

	return Plugin_Continue;
}

//Games Completed
public Action TF2Undead_OnEndGame(bool won)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Continue;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			if (won)
			{
				g_iStatistics[i][games_won]++;
			}
		}
	}

	return Plugin_Continue;
}

//Damage Done
public Action TF2Undead_OnZombieTakeDamage(int zombie, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (GetConVarBool(convar_Status) && IsPlayerIndex(attacker) && !IsFakeClient(attacker))
	{
		g_iStatistics[attacker][damage_done] += damage;
	}
}

//Damage Taken
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Continue;
	}

	if (IsPlayerIndex(victim) && attacker > MaxClients && !IsFakeClient(victim))
	{
		char sClass[32];
		GetEntityClassname(attacker, sClass, sizeof(sClass));

		if (StrEqual(sClass, "tf_zombie"))
		{
			g_iStatistics[victim][damage_taken] += damage;
		}
	}

	if (IsPlayerIndex(attacker) && victim > MaxClients && !IsFakeClient(attacker))
	{
		char sClass[32];
		GetEntityClassname(victim, sClass, sizeof(sClass));

		if (StrEqual(sClass, "tf_zombie") && RoundFloat(damage) >= GetEntProp(victim, Prop_Data, "m_iHealth"))
		{
			g_iStatistics[victim][zombie_kills]++;
		}
	}

	return Plugin_Continue;
}

//Total Games
public Action TF2Undead_OnStartGame(char[] wave_config)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Continue;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			g_iStatistics[i][games_total]++;
		}
	}

	return Plugin_Continue;
}

//Weapons Purchased
public Action TF2Undead_OnWeaponPurchased(int client, const char[] weapon_name)
{
	if (GetConVarBool(convar_Status) && IsPlayerIndex(client) && !IsFakeClient(client))
	{
		g_iStatistics[client][weaponspurchased]++;
	}
}

//WeaponBox Used
public Action TF2Undead_OnWeaponBoxUsed(int client)
{
	if (GetConVarBool(convar_Status) && IsPlayerIndex(client) && !IsFakeClient(client))
	{
		g_iStatistics[client][weaponcrates]++;
	}
}

//Machines Used
public void TF2Undead_OnMachinePerkGiven_Post(int client, const char[] machine)
{
	if (GetConVarBool(convar_Status) && IsPlayerIndex(client) && !IsFakeClient(client))
	{
		g_iStatistics[client][machinespurchased]++;
	}
}

//Perks PickedUp
public Action TF2Undead_OnPowerupPickup(int& powerup, int client)
{
	if (GetConVarBool(convar_Status) && IsPlayerIndex(client) && !IsFakeClient(client))
	{
		g_iStatistics[client][powerups]++;
	}
}

////////////////////////////////////
//Natives

public int Native_ShowStatisticsMenu(Handle plugin, int numParams)
{
	ShowStatisticsMenu(GetNativeCell(1));
}
