#if defined _tf2_undead_core_included
#endinput
#endif
#define _tf2_undead_core_included

stock char sGlobalTag[] = "{orange}[Undead]{gray}";

enum ePointsModifier
{
    Add,
    Subtract,
    Multiply,
    Divide,
    Set
}

//////////////////////////////////////////////
//Natives

native bool TF2Undead_IsInLobby();
native bool TF2Undead_IsWavePaused();
native int TF2Undead_GetClientPoints(int client);
native void TF2Undead_UpdateClientPoints(int client, ePointsModifier modifier, int value);
native void TF2Undead_AddClientPoints(int client, int value);
native void TF2Undead_SubtractClientPoints(int client, int value);
native void TF2Undead_MultiplyClientPoints(int client, int value);
native void TF2Undead_DivideClientPoints(int client, int value);
native void TF2Undead_SetClientPoints(int client, int value);

//////////////////////////////////////////////
//Forwards

forward Action TF2Undead_OnStartGame(char[] wave_config);
forward void TF2Undead_OnStartGame_Post(const char[] wave_config);
forward Action TF2Undead_OnWaveStart(int wave);
forward void TF2Undead_OnWaveStart_Post(int wave);
forward Action TF2Undead_OnWaveEnd(int wave, int next_wave);
forward void TF2Undead_OnWaveEnd_Post(int last_wave, int next_wave, bool clear_zombies, bool clear_specials);
forward Action TF2Undead_OnEndGame(bool won);
forward void TF2Undead_OnEndGame_Post(bool won);

//////////////////////////////////////////////
//Stocks

stock void PauseAllZombies(bool status)
{
    int iFlags = GetCommandFlags("nb_stop");
    SetCommandFlags("nb_stop", iFlags & ~FCVAR_CHEAT);
    ServerCommand("nb_stop %b", status);
    SetCommandFlags("nb_stop win", iFlags);
}

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_core_SetNTVOptional()
{
    MarkNativeAsOptional("TF2Undead_IsInLobby");
    MarkNativeAsOptional("TF2Undead_IsWavePaused");
    MarkNativeAsOptional("TF2Undead_GetClientPoints");
    MarkNativeAsOptional("TF2Undead_UpdateClientPoints");
    MarkNativeAsOptional("TF2Undead_AddClientPoints");
    MarkNativeAsOptional("TF2Undead_SubtractClientPoints");
    MarkNativeAsOptional("TF2Undead_MultiplyClientPoints");
    MarkNativeAsOptional("TF2Undead_DivideClientPoints");
    MarkNativeAsOptional("TF2Undead_SetClientPoints");
}
#endif

public SharedPlugin __pl_tf2_undead_core =
{
    name = "tf2-undead-core",
    file = "tf2-undead-core.smx",
    #if defined REQUIRE_PLUGIN
    required = 1,
    #else
    required = 0,
    #endif
};
