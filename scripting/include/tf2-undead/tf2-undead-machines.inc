#if defined _tf2_undead_machines_included
  #endinput
#endif
#define _tf2_undead_machines_included

//////////////////////////////////////////////
//Natives

native bool TF2Undead_Machines_HasPerk(int client, const char[] machine);

//////////////////////////////////////////////
//Forwards

forward void TF2Undead_OnMachineSpawn_Post(int entity, const char[] name, const float origin[3], const float angle[3], const char[] model);
forward void TF2Undead_OnMachinePurchased_Post(int client, const char[] machine);
forward void TF2Undead_OnMachinePerkGiven_Post(int client, const char[] machine);
forward void TF2Undead_OnMachinePerkRemoved_Post(int client, const char[] machine);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_machines_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Undead_Machines_HasPerk");
}
#endif

public SharedPlugin __pl_tf2_undead_machines =
{
	name = "tf2-undead-machines",
	file = "tf2-undead-machines.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
