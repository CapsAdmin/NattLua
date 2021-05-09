do
	return
end

local x = 1 + 2
local y = draw_type(1, 2, 3, 4, 5)
local x = lexer.OnDraw and
	(
		draw_type == "viewmodel" or
		draw_type == "hands" or
		((lexer.Translucent == true or lexer.force_translucent == true) and draw_type == "translucent") or
		((lexer.Translucent == false or lexer.force_translucent == false) and draw_type == "opaque")
	)

pos, ang = LocalToWorld(
	lexer.Position or Vector(),
	lexer.Angles or Angle(),
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

ent = pac.HandleOwnerName(lexer:GetPlayerOwner(),
	lexer.OwnerName,
	ent,
	lexer,
	function(e)
		return e.pac_duplicate_attach_uid ~= lexer.UniqueID
	end) or
	NULL

render.OverrideBlendFunc(true, lexer.blend_override[1], lexer.blend_override[2], lexer.blend_override[3], lexer.blend_override[4])
foo(function() end) -- space here
foo(function() end)
pac.AimPartNames = {
		["local eyes"] = "LOCALEYES", 
		["player eyes"] = "PLAYEREYES", 
		["local eyes yaw"] = "LOCALEYES_YAW", 
		["local eyes pitch"] = "LOCALEYES_PITCH", 
	}


if not outfit.self then
	return lexer:AttachPACSession(outfit, owner)
end
if 
	(outfit.self.OwnerName == "viewmodel" or outfit.self.OwnerName == "hands") and
	lexer:IsWeapon() and
	lexer.Owner:IsValid() and
	lexer.Owner:IsPlayer() and
	lexer.Owner ~= LocalPlayer()
 then
	return
end