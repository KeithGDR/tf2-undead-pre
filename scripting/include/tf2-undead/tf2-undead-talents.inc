#if defined _tf2_undead_talents_included
  #endinput
#endif
#define _tf2_undead_talents_included

//////////////////////////////////////////////
//Natives

native void TF2Undead_Talents_ShowMenu(int client, bool requirelobby = true);

//////////////////////////////////////////////
//Forwards

//forward void TF2Undead_Talents_();

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_talents_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Undead_Talents_ShowMenu");
}
#endif

public SharedPlugin __pl_tf2_undead_talents =
{
	name = "tf2-undead-talents",
	file = "tf2-undead-talents.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
