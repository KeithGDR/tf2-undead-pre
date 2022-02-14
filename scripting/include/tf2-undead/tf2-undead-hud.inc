#if defined _tf2_undead_hud_included
  #endinput
#endif
#define _tf2_undead_hud_included

//////////////////////////////////////////////
//Natives

native void TF2Undead_Hud_ShowPurchaseHud(int client, char[] text, int price = 0);
native void TF2Undead_Hud_ClearPurchaseHud(int client);

//////////////////////////////////////////////
//Forwards

//forward void TF2Undead_Talents_();

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_tf2_undead_hud_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Undead_Hud_ShowPurchaseHud");
	MarkNativeAsOptional("TF2Undead_Hud_ClearPurchaseHud");
}
#endif

public SharedPlugin __pl_tf2_undead_hud =
{
	name = "tf2-undead-hud",
	file = "tf2-undead-hud.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
