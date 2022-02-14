//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <tf2-undead/tf2-undead-core>
#include <tf2-undead/tf2-undead-talents>

//ConVars
ConVar cvar_Status;

//Plugin Info
public Plugin myinfo =
{
	name = "TF2 Undead - Talents",
	author = "Keith Warren (Shaders Allen)",
	description = "Talents module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-talents");

	CreateNative("TF2Undead_Talents_ShowMenu", Native_ShowMenu);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	cvar_Status = CreateConVar("sm_undead_talents_status", "1");

	RegConsoleCmd("sm_talentsmenu", Command_TalentsMenu, "Show the talents menu.");
}

public void OnConfigsExecuted()
{

}

public Action Command_TalentsMenu(int client, int args)
{
	if (!GetConVarBool(cvar_Status))
	{
		return Plugin_Handled;
	}

	ShowTalentsMenu(client);
	return Plugin_Handled;
}

public int Native_ShowMenu(Handle plugin, int numParams)
{
	ShowTalentsMenu(GetNativeCell(1), GetNativeCell(2));
}

void ShowTalentsMenu(int client, bool require_lobby = true)
{
	if (require_lobby && !TF2Undead_IsInLobby())
	{
		CPrintToChat(client, "%s Must be in lobby to use this menu.", sGlobalTag);
		return;
	}

	Menu menu = CreateMenu(MenuAction_TalentsMenu);
	SetMenuTitle(menu, "Set your talents:");

	AddMenuItem(menu, "", "[In Progress]", ITEMDRAW_DISABLED);
	AddMenuItem(menu, "", "[In Progress]", ITEMDRAW_DISABLED);
	AddMenuItem(menu, "", "[In Progress]", ITEMDRAW_DISABLED);


	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuAction_TalentsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public void OnPluginEnd()
{

}
