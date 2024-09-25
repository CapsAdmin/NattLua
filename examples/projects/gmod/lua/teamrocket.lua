if SERVER then
	--[[#type EventCallbacks.PhysgunThrowPlayer = function=(attacker: IEntity, victim: IEntity)>(nil)]]
end

--[[#type jrpg = {}]]
--[[#type jrpg.GetGender = function=(IEntity)>("male" | "female")]]

if CLIENT then
	net.Receive("teamrocket", function(len)
		if not LocalPlayer():IsValid() then return end

		local origin = net.ReadVector()
		local mat = Material("sprites/light_ignorez")
		local mat2 = CreateMaterial(
			"teamrocket_" .. os.clock(),
			"UnlitGeneric",
			{
				["$BaseTexture"] = "particle/particle_glow_09",
				["$VertexColor"] = 1,
				["$VertexAlpha"] = 1,
				["$Additive"] = 1,
			}
		)
		local duration = 1
		local delay = 3.75
		local max_speed = 5000
		local sound_played = false
		local start = RealTime()
		LocalPlayer():EmitSound("pac_server/throw/twinkle.ogg", 75, math.random(95, 105), 0.3)
		local id = "teamrocket_" .. tostring({})

		hook.Add("RenderScreenspaceEffects", id, function()
			local time = RealTime()
			local delta = time - start

			if delta > duration then
				hook.Remove("RenderScreenspaceEffects", id)
				return
			end

			local size = math.sin((delta / duration) * math.pi) * 0.7
			local rotation = time * 100
			rotation = rotation ^ ((-(delta / duration) + 1) * 0.5)
			local pos = origin:ToScreen()

			if pos.visible then
				surface.SetMaterial(mat2)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRectRotated(pos.x, pos.y, size * 128, size * 128, rotation)
				size = size * 6
				surface.SetMaterial(mat)
				surface.SetDrawColor(255, 255, 255, 255)
				local max = 8

				for i = 1, max do
					surface.DrawTexturedRectRotated(
						pos.x,
						pos.y,
						10,
						size * 50 * math.sin(i),
						rotation + ((i / max) * math.pi * 2) * 360
					)
				end

				local max = 2

				for i = 1, max do
					surface.DrawTexturedRectRotated(pos.x, pos.y, 10, size * 50, -rotation - ((i / max) * math.pi * 2) * 360 - 45)
				end

				DrawSunbeams(0.3, math.abs(size) * 0.025, 0.06, pos.x / ScrW(), pos.y / ScrH())
			end
		end)
	end)
end

if SERVER then
	util.AddNetworkString("teamrocket")

	local function team_rocket_death(victim--[[#: IEntity]], attacker--[[#: IEntity]], dir--[[#: IVector]])
		if not IsValid(victim) or not IsValid(attacker) then return end

		local info = DamageInfo()
		info:SetDamagePosition(victim:GetPos())
		info:SetDamage(victim:Health())
		info:SetDamageType(DMG_FALL)
		info:SetAttacker(attacker)
		info:SetInflictor(game.GetWorld())
		info:SetDamageForce(Vector(0, 0, 0))
		victim:TakeDamageInfo(info)
		local rag = victim:GetNWEntity("serverside_ragdoll")--[[# as IEntity]]

		if rag:IsValid() then
			local path

			if jrpg.GetGender(victim) == "female" then
				path = "pac_server/throw/female/" .. math.random(1, 9) .. ".ogg"
			else
				path = "pac_server/throw/male/" .. math.random(1, 19) .. ".ogg"
			end

			local snd = CreateSound(victim, path)
			snd:SetSoundLevel(150)
			snd:SetDSP(20)
			snd:Play()
			local phys = rag:GetPhysicsObject()

			if phys:IsValid() then
				rag:AddCallback("PhysicsCollide", function(ent--[[#: IEntity]], data--[[#: Struct_CollisionData]])
					if data.HitEntity == Entity(0) then
						net.Start("teamrocket")
						net.WriteVector(data.HitPos)
						net.Broadcast()
						rag:Remove()
					end
				end)

				for i = 1, rag:GetPhysicsObjectCount() - 1 do
					local phys = rag:GetPhysicsObjectNum(i)
					phys:SetDamping(0, 0)
					phys:EnableGravity(false)
				end

				phys:SetDamping(0, 0)
				phys:EnableGravity(false)
				local id = "team_rocket_" .. rag:EntIndex()

				hook.Add("Think", id, function()
					if phys:IsValid() then
						victim:SetMoveType(MOVETYPE_NONE)
						victim:SetPos(phys:GetPos())
						phys:AddAngleVelocity(Vector(0, 0, 300))
						phys:AddVelocity(dir * 400)
						phys:AddVelocity(phys:GetAngles():Right() * 150)
					else
						hook.Remove("Think", id)
					end
				end)
			end
		end
	end

	local suppress = false

	hook.Add("EntityTakeDamage", "teamrocket", function(victim, info)
		if suppress or not victim:IsPlayer() then return false end

		local force = info:GetDamageForce()
		local res = util.TraceLine({start = victim:GetPos(), endpos = victim:GetPos() + force, filter = victim})

		if res.Hit and res.HitSky and victim:GetPos():Distance(res.HitPos) > 1000 then
			suppress = true
			force.z = math.abs(force.z) + 0.5
			team_rocket_death(victim, info:GetAttacker(), force:GetNormalized())
			suppress = false
		end

		return true
	end)

	hook.Add("PhysgunThrowPlayer", "teamrocket", function(attacker, victim)
		local res = util.TraceLine(
			{
				start = victim:GetPos(),
				endpos = victim:GetPos() + victim:GetVelocity() * 10,
				filter = victim,
			}
		)

		if
			(
				res.HitSky or
				util.GetSurfacePropName(res.SurfaceProps) == "no_decal"
			)
			and
			victim:GetPos():Distance(res.HitPos) > 1000
		then
			team_rocket_death(victim, attacker, victim:GetVelocity():GetNormalized())
		end
	end)
end
