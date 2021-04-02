do
	return
end

local x = 1 + 2
local y = draw_type(1, 2, 3, 4, 5)
local x = self.OnDraw and
	(
		draw_type == "viewmodel" or
		draw_type == "hands" or
		((self.Translucent == true or self.force_translucent == true) and draw_type == "translucent") or
		((self.Translucent == false or self.force_translucent == false) and draw_type == "opaque")
	)

pos, ang = LocalToWorld(
	self.Position or Vector(),
	self.Angles or Angle(),
	pos or owner:GetPos(),
	ang or owner:GetAngles()
)

if not ply.pac_cameras then
	return
end

local cond = key ~= "ParentUID" and
	key ~= "ParentName" and
	key ~= "UniqueID" and
	(
		key ~= "AimPartName" and
		not (pac.PartNameKeysToIgnore and pac.PartNameKeysToIgnore[key]) or
		key == "AimPartName" and
		table.HasValue(pac.AimPartNames, value)
	)

ent = pac.HandleOwnerName(self:GetPlayerOwner(),
	self.OwnerName,
	ent,
	self,
	function(e)
		return e.pac_duplicate_attach_uid ~= self.UniqueID
	end) or
	NULL

render.OverrideBlendFunc(true, self.blend_override[1], self.blend_override[2], self.blend_override[3], self.blend_override[4])
foo(function() end) -- space here
foo(function() end)
pac.AimPartNames = {
		["local eyes"] = "LOCALEYES", 
		["player eyes"] = "PLAYEREYES", 
		["local eyes yaw"] = "LOCALEYES_YAW", 
		["local eyes pitch"] = "LOCALEYES_PITCH", 
	}


if not outfit.self then
	return self:AttachPACSession(outfit, owner)
end
if 
	(outfit.self.OwnerName == "viewmodel" or outfit.self.OwnerName == "hands") and
	self:IsWeapon() and
	self.Owner:IsValid() and
	self.Owner:IsPlayer() and
	self.Owner ~= LocalPlayer()
 then
	return
end