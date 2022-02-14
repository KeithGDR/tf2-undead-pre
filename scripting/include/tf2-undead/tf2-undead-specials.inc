#if defined _tf2_undead_specials_included
  #endinput
#endif
#define _tf2_undead_specials_included

//////////////////////////////////////////////
//Natives

native void TF2Undead_Specials_Spawn(const char[] name, const float vecCoordinates[3], const float vecAngles[3] = NULL_VECTOR);
native bool TF2Undead_Specials_IsSpecial(int entity);
native void TF2Undead_Specials_KillAllSpecials();
native void TF2Undead_Specials_GetSpecialName(int entity, char[] name, int size);
native void TF2Undead_Specials_ScheduleSpawn(const char[] name, const float vecCoordinates[3]);

//////////////////////////////////////////////
//Forwards

//forward void TF2Undead_OnSpecialSpawn_Post(int entity, const char[] type);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_specials_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Undead_Specials_Spawn");
	MarkNativeAsOptional("TF2Undead_Specials_IsSpecial");
	MarkNativeAsOptional("TF2Undead_Specials_KillAllSpecials");
	MarkNativeAsOptional("TF2Undead_Specials_GetSpecialName");
	MarkNativeAsOptional("TF2Undead_Specials_ScheduleSpawn");
}
#endif

public SharedPlugin __pl_tf2_undead_specials =
{
	name = "tf2-undead-specials",
	file = "tf2-undead-specials.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
