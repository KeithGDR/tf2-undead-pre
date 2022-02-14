#if defined _tf2_undead_weapons_included
  #endinput
#endif
#define _tf2_undead_weapons_included

//////////////////////////////////////////////
//Natives

//native bool TF2Undead_Weapons_();

//////////////////////////////////////////////
//Forwards

forward Action TF2Undead_OnWeaponPurchased(int client, const char[] weapon_name);
forward void TF2Undead_OnWeaponPurchased_Post(int client, const char[] weapon_name);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_weapons_SetNTVOptional()
{
	//MarkNativeAsOptional("TF2Undead_Weapons_");
}
#endif

public SharedPlugin __pl_tf2_undead_weapons =
{
	name = "tf2-undead-weapons",
	file = "tf2-undead-weapons.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
