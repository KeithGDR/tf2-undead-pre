#if defined _CBaseAnimatingOverlay_included
 #endinput
#endif
#define _CBaseAnimatingOverlay_included

#include <sourcemod>
#include <sdktools>

#define ANIM_LAYER_ACTIVE		0x0001
#define ANIM_LAYER_AUTOKILL		0x0002
#define ANIM_LAYER_KILLME		0x0004
#define ANIM_LAYER_DONTRESTORE	0x0008
#define ANIM_LAYER_CHECKACCESS	0x0010
#define ANIM_LAYER_DYING		0x0020

enum //CAnimationLayer
{
	m_fFlags = 0,               //0x0000 
	m_bSequenceFinished = 4,    //0x0004 
	m_bLooping = 6,             //0x0006 
	m_nSequence = 8,            //0x0008 
	m_flCycle = 12,             //0x000C 
	m_flPrevCycle = 16,         //0x0010 
	m_flWeight = 20,            //0x0014 
	m_flPlaybackRate = 24,      //0x0018 
	m_flBlendIn = 28,           //0x001C 
	m_flBlendOut = 32,          //0x0020 
	m_flKillRate = 36,          //0x0024 
	m_flKillDelay = 40,         //0x0028 
	m_flLayerAnimtime = 44,     //0x002C 
	m_flLayerFadeOuttime = 48,  //0x0030 
	m_nActivity = 52,           //0x0034 
	m_nPriority = 56,           //0x0038 
	m_nOrder = 60,              //0x003C 
	m_flLastEventCheck = 64,    //0x0040 
	m_flLastEventAccess = 68,   //0x0044 
	m_pOwnerEntity = 72,        //0x0048 
	
	CAnimationLayer_Size = 76   //0x004C
}; //Size=0x004C

//int CBaseAnimatingOverlay_Size = CAnimationLayer_Size * 15

methodmap CAnimationLayer 
{
	property Address Address 
	{
		public get() 
		{
			return view_as<Address>(this);
		}
	}

	public any Get(int offset)
	{
		return LoadFromAddress(this.Address + view_as<Address>(offset), NumberType_Int32);
	}
	
	public void Set(int offset, any value)
	{
		StoreToAddress(this.Address + view_as<Address>(offset), value, NumberType_Int32);
	}
	
	public bool IsActive()   { return ((this.Get(m_fFlags) & ANIM_LAYER_ACTIVE)   != 0); }
	public bool IsAutokill() { return ((this.Get(m_fFlags) & ANIM_LAYER_AUTOKILL) != 0); }
	public bool IsKillMe()   { return ((this.Get(m_fFlags) & ANIM_LAYER_KILLME)   != 0); }
	public bool IsDying()    { return ((this.Get(m_fFlags) & ANIM_LAYER_DYING)    != 0); }
	public bool IsAutoramp() { return ((this.Get(m_flBlendIn) != 0.0) || (this.Get(m_flBlendOut) != 0.0)); }
	public void KillMe()	 { int fFlags = this.Get(m_fFlags); this.Set(m_fFlags, (fFlags |= ANIM_LAYER_KILLME)); }
	public void Dying()      { int fFlags = this.Get(m_fFlags); this.Set(m_fFlags, (fFlags |= ANIM_LAYER_DYING));  }
	public void Dead()       { int fFlags = this.Get(m_fFlags); this.Set(m_fFlags, (fFlags &= ~ANIM_LAYER_DYING)); }
}

methodmap CBaseAnimatingOverlay < CAnimationLayer
{
	public CBaseAnimatingOverlay(int entity) 
	{
		int iOffset = (view_as<int>(GetEntityAddress(entity)) + FindDataMapInfo(entity, "m_AnimOverlay")) + view_as<int>(0x10);
		Address Overlay = view_as<Address>(LoadFromAddress(view_as<Address>(iOffset), NumberType_Int32));
	
		return view_as<CBaseAnimatingOverlay>(Overlay);
	}
	
	public CAnimationLayer GetLayer(int iLayer)
	{
		return view_as<CAnimationLayer>(this.Address + view_as<Address>(iLayer * CAnimationLayer_Size));
	}
}

stock int FindGestureLayer(int entity, int activity)
{
	CBaseAnimatingOverlay overlay = CBaseAnimatingOverlay(entity);
	
	for (int i = 0; i < 15; i++)
	{
		CAnimationLayer layer = overlay.GetLayer(i);
		
		if(!(layer.IsActive()))
			continue;				
		
		if(layer.IsKillMe())
			continue;
		
		if(layer.Get(m_nActivity) == activity || layer.Get(m_nSequence) == activity)
			return i;
	}
	
	return -1;
}

//-----------------------------------------------------------------------------
// Purpose: 
// Input  : activity - 
// Output : Returns true on success, false on failure.
//-----------------------------------------------------------------------------
stock bool IsPlayingGesture(int entity, int activity)
{
	return FindGestureLayer( entity, activity ) != -1 ? true : false;
}