#if defined _tf2_undead_planks_included
  #endinput
#endif
#define _tf2_undead_planks_included

//////////////////////////////////////////////
//Natives

native any TF2Undead_Planks_GetDataValue(char[] key);
native void TF2Undead_Planks_SetDataValue(char[] key, any value);

//////////////////////////////////////////////
//Forwards

forward void TF2Undead_OnPlankRebuilt_Post(int client, int plank);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_planks_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Undead_Planks_GetDataValue");
	MarkNativeAsOptional("TF2Undead_Planks_SetDataValue");
}
#endif

public SharedPlugin __pl_tf2_undead_planks =
{
	name = "tf2-undead-planks",
	file = "tf2-undead-planks.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
