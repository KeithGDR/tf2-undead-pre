#if defined _tf2_undead_statistics_included
  #endinput
#endif
#define _tf2_undead_statistics_included

//////////////////////////////////////////////
//Natives

native void TF2Undead_Statistics_ShowStatisticsMenu(int client);

//////////////////////////////////////////////
//Forwards

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_statistics_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Undead_Statistics_ShowStatisticsMenu");
}
#endif

public SharedPlugin __pl_tf2_undead_statistics =
{
	name = "tf2-undead-statistics",
	file = "tf2-undead-statistics.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
