#if defined _tf2_undead_weaponbox_included
  #endinput
#endif
#define _tf2_undead_weaponbox_included

//////////////////////////////////////////////
//Natives

//native bool TF2Undead_weaponbox_HasPerk(int client, const char[] machine);

//////////////////////////////////////////////
//Forwards

forward Action TF2Undead_OnWeaponBoxUsed(int client);
forward void TF2Undead_OnWeaponBoxUsed_Post(int client, const char[] weapon_won);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_weaponbox_SetNTVOptional()
{
	//MarkNativeAsOptional("TF2Undead_weaponbox_HasPerk");
}
#endif

public SharedPlugin __pl_tf2_undead_weaponbox =
{
	name = "tf2-undead-weaponbox",
	file = "tf2-undead-weaponbox.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
