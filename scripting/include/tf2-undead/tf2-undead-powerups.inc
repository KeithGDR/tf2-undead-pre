#if defined _tf2_undead_powerups_included
  #endinput
#endif
#define _tf2_undead_powerups_included

//////////////////////////////////////////////
//Natives

native bool TF2Undead_Powerups_IsDoublePoints();
native bool TF2Undead_Powerups_IsInstantKill();

//////////////////////////////////////////////
//Forwards

forward void TF2Undead_OnPowerupSpawn_Post(int entity, int powerup);
forward Action TF2Undead_OnPowerupPickup(int& powerup, int& client);
forward void TF2Undead_OnPowerupPickup_Post(int powerup, int client);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_powerups_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Undead_Powerups_IsDoublePoints");
	MarkNativeAsOptional("TF2Undead_Powerups_IsInstantKill");
}
#endif

public SharedPlugin __pl_tf2_undead_powerups =
{
	name = "tf2-undead-powerups",
	file = "tf2-undead-powerups.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
