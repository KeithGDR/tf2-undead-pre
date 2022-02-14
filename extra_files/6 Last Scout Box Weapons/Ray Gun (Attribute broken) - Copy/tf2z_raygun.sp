/**
 * Sourcemod 1.7 Plugin Template
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools>
#include <sdkhooks>

#include <tf2_stocks>

#include <cw3-attributes>
#include <tf2attributes>

#pragma newdecls required
#include <stocksoup/log_server>

#define PLUGIN_VERSION "0.0.0"
public Plugin myinfo = {
	name = "[TF2] Custom Weapon Attribute:  Ray Gun",
	author = "nosoop",
	description = "Replaces a weapon's projectile with a Cow Mangler shot.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/"
}

#define CW3_PLUGIN_NAME "tf2z_raygun"
#define ATTR_IS_RAY_GUN "is ray gun"

ArrayList g_AppliedWeapons;

Handle g_hSDKWeaponGetDamage, g_hSDKRocketSetDamage;

public void OnPluginStart() {
	Handle hConf = LoadGameConfigFile("tf2z.raygun");
	
	if (!hConf) {
		SetFailState("Missing required gamedata.  "
				... "Did you remember to install gamedata/tf2z.raygun.txt?");
	} else {
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFWeaponBaseGun::GetProjectileDamage");
		PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
		g_hSDKWeaponGetDamage = EndPrepSDKCall();
		
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFBaseRocket::SetDamage");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hSDKRocketSetDamage = EndPrepSDKCall();
		
		delete hConf;
	}
	
	g_AppliedWeapons = new ArrayList(2);
}

public Action CW3_OnAddAttribute(int slot, int client, const char[] attrib,
		const char[] plugin, const char[] value) {
	if (StrEqual(plugin, CW3_PLUGIN_NAME, false)
			&& StrEqual(attrib, ATTR_IS_RAY_GUN)) {
		int weapon = GetPlayerWeaponSlot(client, slot);
		
		int ind = g_AppliedWeapons.Push(weapon);
		g_AppliedWeapons.Set(ind, slot, 1);
		
		// we use syringe instead of cow mangler to deal with client misprediction
		TF2Attrib_SetByName(weapon, "override projectile type", 8.0);
		
		LogServer("%N got a beepity boop", client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// good old entity override shenanigans, oh how I miss thee

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "tf_projectile_arrow")) {
		SDKHook(entity, SDKHook_Spawn, TestArrowProjectile);
	}
}

void TestArrowProjectile(int entref) {
	int entity = EntRefToEntIndex(entref);
	if (entity && ShouldReplaceArrowProjectile(entity)) {
		ReplaceArrowProjectile(entity);
	}
	SDKUnhook(entity, SDKHook_Spawn, TestArrowProjectile);
}

/**
 * Checks if the owner has the appropriate secondary weapon.
 */
bool ShouldReplaceArrowProjectile(int entity) {
	// spawn hook has data properties set
	int hOwnerEntity = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	return ClientRayGunSlot(hOwnerEntity) != -1;
}

void ReplaceArrowProjectile(int entity) {
	int hOwner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	int slot = ClientRayGunSlot(hOwner);
	
	int hLauncher = GetPlayerWeaponSlot(hOwner, slot);
	
	// TODO trace player eye to find endpoint
	float vecEyePosition[3], vecEyeAngles[3], vecProjectileSource[3];
	GetClientEyePosition(hOwner, vecEyePosition);
	GetClientEyeAngles(hOwner, vecEyeAngles);
	
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecEyePosition);
	
	// trace from player eye to where crosshair would be to get the end position
	// remember to MASK_SHOT so the player's face isn't included in the trace
	float vecEndPosition[3];
	Handle trace = TR_TraceRayFilterEx(vecEyePosition, vecEyeAngles, MASK_SHOT,
			RayType_Infinite, TraceFilterSelf, hOwner);
	TR_GetEndPosition(vecEndPosition, trace);
	delete trace;
	
	// for now we'll just set the projectile origin to the eyeballs
	
	float vecProjectileOffset[3];
	float vecMagic[3];
	vecMagic = vecEyeAngles;
	vecMagic[1] -= 45.0;
	
	GetAngleVectors(vecMagic, vecProjectileOffset, NULL_VECTOR, NULL_VECTOR);
	
	ScaleVector(vecProjectileOffset, 25.0);
	
	AddVectors(vecEyePosition, vecProjectileOffset, vecProjectileSource);
	
	// hacky fix if at close range to prevent projectile from clipping through windows
	// if the end point is within 30HU the mangler is fired from the eyes instead
	bool bCloseRange = GetVectorDistance(vecEyePosition, vecEndPosition, true) < 900.0;
	if (bCloseRange) {
		vecProjectileSource = vecEyePosition;
	}
	
	// make projectile go towards end position
	float vecVelocity[3];
	if (bCloseRange) {
		// close range, shoot where we're looking
		GetAngleVectors(vecEyeAngles, vecVelocity, NULL_VECTOR, NULL_VECTOR);
	} else {
		MakeVectorFromPoints(vecProjectileSource, vecEndPosition, vecVelocity);
	}
	NormalizeVector(vecVelocity, vecVelocity);
	
	float flVelocityScalar = 1.0;
	Address pAttrib;
	if ((pAttrib = TF2Attrib_GetByName(hLauncher, "Projectile speed increased"))
			|| (pAttrib = TF2Attrib_GetByName(hLauncher, "Projectile speed decreased"))) {
		flVelocityScalar = TF2Attrib_GetValue(pAttrib);
	}
	
	ScaleVector(vecVelocity, 1000.0 * flVelocityScalar);
	
	int manglerShot = CreateEntityByName("tf_projectile_energy_ball");
	
	if (slot != -1 && IsValidEntity(manglerShot)) {
		
		SetEntPropEnt(manglerShot, Prop_Send, "m_hLauncher", hLauncher);
		SetEntPropEnt(manglerShot, Prop_Send, "m_hOriginalLauncher", hLauncher);
		SetEntPropEnt(manglerShot, Prop_Send, "m_hOwnerEntity", hOwner);
		
		SetEntProp(manglerShot, Prop_Send, "m_fEffects", 16);
		
		float damage = WeaponGetDamage(hLauncher);
		
		RocketSetDamage(manglerShot, damage);
		
		// CopyEntPropEnt(entity, manglerShot, Prop_Data, "m_hOwnerEntity");
		
		// set team color
		SetEntProp(manglerShot, Prop_Send, "m_iTeamNum", TF2_GetClientTeam(hOwner));
		
		AcceptEntityInput(entity, "Kill");
		
		DispatchSpawn(manglerShot);
		
		TeleportEntity(manglerShot, vecProjectileSource, NULL_VECTOR, vecVelocity);
		
		SDKHook(manglerShot, SDKHook_StartTouch, RocketTouch);
	}
}

/**
 * Returns the actual damage output of the weapon, taking base weapon attributes into account.
 */
float WeaponGetDamage(int entity) {
	// CTFWeaponBaseGun::GetProjectileDamage
	return SDKCall(g_hSDKWeaponGetDamage, entity);
}

void RocketSetDamage(int rocket, float damage) {
	// CTFBaseRocket::SetDamage(float)
	SDKCall(g_hSDKRocketSetDamage, rocket, damage);
}

#define FSOLID_TRIGGER 0x8
#define FSOLID_VOLUME_CONTENTS 0x20

void RocketTouch(int rocket, int other) {
	int solidFlags = GetEntProp(other, Prop_Send, "m_usSolidFlags");
	
	if (solidFlags & (FSOLID_TRIGGER | FSOLID_VOLUME_CONTENTS)) {
		return;
	}
	EmitGameSoundToAll("Weapon_CowMangler.Explode", rocket);
}

int ClientRayGunSlot(int client) {
	for (int i = 0; i < 3; i++) {
		int weapon = GetPlayerWeaponSlot(client, 1);
		
		int ind = g_AppliedWeapons.FindValue(weapon);
		
		if (ind != -1 && g_AppliedWeapons.Get(ind, 1) == i) {
			return i;
		}
	}
	return -1;
}

public bool TraceFilterSelf(int entity, int contentsMask, int client) {
	return entity != client;
}

stock void CopyEntPropEnt(int source, int destination, PropType type, const char[] prop) {
	int data = GetEntPropEnt(source, type, prop);
	SetEntPropEnt(destination, type, prop, data);
}

stock void CopyEntPropFloat(int source, int destination, PropType type, const char[] prop) {
	int data = GetEntPropFloat(source, type, prop);
	SetEntPropFloat(destination, type, prop, data);
}

stock void CopyEntProp(int source, int destination, PropType type, const char[] prop) {
	int data = GetEntProp(source, type, prop);
	SetEntProp(destination, type, prop, data);
}
