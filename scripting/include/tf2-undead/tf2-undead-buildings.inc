#if defined _tf2_undead_buildings_included
  #endinput
#endif
#define _tf2_undead_buildings_included

//////////////////////////////////////////////
//Natives


//////////////////////////////////////////////
//Forwards


//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_buildings_SetNTVOptional()
{
	//MarkNativeAsOptional("TF2Undead_Machines_HasPerk");
}
#endif

public SharedPlugin __pl_tf2_undead_buildings =
{
	name = "tf2-undead-buildings",
	file = "tf2-undead-buildings.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
