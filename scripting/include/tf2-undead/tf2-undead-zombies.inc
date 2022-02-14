#if defined _tf2_undead_zombies_included
  #endinput
#endif
#define _tf2_undead_zombies_included

//////////////////////////////////////////////
//Natives

native int TF2Undead_Zombies_Spawn(const float coordinates[3], const float angles[3] = NULL_VECTOR, int class = -1, int health = -1, float speed = -1.0, float size = -1.0, float damage = -1.0, int color[4] = {255, 255, 255, 255}, const char[] spawn_sound = "", const char[] death_sound = "", const char[] particle = "");
native void TF2Undead_Zombies_KillAllZombies();
native void TF2Undead_Zombies_FreezeZombie(int zombie, bool freeze);
native bool TF2Undead_Zombies_IsZombieFrozen(int zombie);

//////////////////////////////////////////////
//Forwards

forward Action TF2Undead_OnZombieSpawn(int zombie);
forward void TF2Undead_OnZombieSpawn_Post(int zombie, int skeleton);
forward Action TF2Undead_OnZombieDeath(int zombie);
forward void TF2Undead_OnZombieDeath_Post(int zombie);
forward Action TF2Undead_OnZombieTraceAttack(int zombie, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup);
forward Action TF2Undead_OnZombieTakeDamage(int zombie, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom);
forward void TF2Undead_OnZombieGnomeSpawn_Post(int zombie);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_zombies_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Undead_Zombies_Spawn");
	MarkNativeAsOptional("TF2Undead_Zombies_KillAllZombies");
	MarkNativeAsOptional("TF2Undead_Zombies_FreezeZombie");
	MarkNativeAsOptional("TF2Undead_Zombies_IsZombieFrozen");
}
#endif

public SharedPlugin __pl_tf2_undead_zombies =
{
	name = "tf2-undead-zombies",
	file = "tf2-undead-zombies.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
