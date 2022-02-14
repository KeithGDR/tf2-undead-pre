/**********************************************************************************************************************/
//Headers

//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <tf2-undead/tf2-undead-hud>

#undef REQUIRE_PLUGIN
#include <tf2-undead/tf2-undead-core>
#define REQUIRE_PLUGIN

//ConVars
ConVar convar_Status;
ConVar convar_Hud_Purchase_Location;
ConVar convar_Hud_Purchase_Color;

//Globals
Handle g_hHud_Purchase;

/**********************************************************************************************************************/
//Plugin Information

public Plugin myinfo =
{
	name = "TF2 Undead - Hud",
	author = "Keith Warren (Shaders Allen)",
	description = "WeaponBox module for TF2 Undead.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

/**********************************************************************************************************************/
//Global Functions

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2-undead-weaponbox");

	CreateNative("TF2Undead_Hud_ShowPurchaseHud", Native_ShowPurchaseHud);
	CreateNative("TF2Undead_Hud_ClearPurchaseHud", Native_ClearPurchaseHud);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_undead_hud_status", "1");
	convar_Hud_Purchase_Location = CreateConVar("sm_undead_hud_purchase_location", "-1.0, 0.6");
	convar_Hud_Purchase_Color = CreateConVar("sm_undead_hud_purchase_color", "255, 255, 255, 255");

	g_hHud_Purchase = CreateHudSynchronizer();
}

public void OnPluginEnd()
{
	ClearAllHudSyncs();
}

/**********************************************************************************************************************/
//Undead Forwards

public void TF2Undead_OnEndGame_Post()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	ClearAllHudSyncs();
}

/**********************************************************************************************************************/
//Stock Functions

void ClearAllHudSyncs()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ClearSyncHud(i, g_hHud_Purchase);
		}
	}
}

/**********************************************************************************************************************/
//Natives

public int Native_ShowPurchaseHud(Handle plugin, int numParams)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	int client = GetNativeCell(1);

	if (client == 0 || IsFakeClient(client))
	{
		return;
	}

	int size;
	GetNativeStringLength(2, size);

	char[] sText = new char[size + 1];
	GetNativeString(2, sText, size + 1);

	if (strlen(sText) == 0)
	{
		return;
	}

	float vecLocation[2]; vecLocation = GetConVar2DVector(convar_Hud_Purchase_Location);
	int iColor[4]; iColor = GetConVarColor(convar_Hud_Purchase_Color);

	char sDisplay[255];
	FormatEx(sDisplay, sizeof(sDisplay), "%s: %i", sText, GetNativeCell(3));

	SetHudTextParams(vecLocation[0], vecLocation[1], 99999.0, iColor[0], iColor[1], iColor[2], iColor[3], 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, g_hHud_Purchase, sDisplay);
}

public int Native_ClearPurchaseHud(Handle plugin, int numParams)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	int client = GetNativeCell(1);

	if (client == 0 || IsFakeClient(client))
	{
		return;
	}

	ClearSyncHud(client, g_hHud_Purchase);
}
