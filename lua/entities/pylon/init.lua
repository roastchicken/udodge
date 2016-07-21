AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

local TARGET_OFFSET = Vector( 0, 0, 36 )

ENT.fire_rate = 1.5
ENT.fire_rate_stddev = 0.3
ENT.fire_radius = 2000
ENT.fire_speed = 850
ENT.cball_lifetime = 3
ENT.should_target_closest = false

function ENT:SpawnFunction( ply, tr )
	if not tr.Hit then return end

	local spawn = tr.HitPos + tr.HitNormal * 16

	local ent = ents.Create( "pylon" )
	ent:SetPos( spawn )
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:Initialize()
	self:SetModel( "models/props_c17/oildrum001.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetName( "Pylon" .. self:EntIndex() )

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:Wake()
	end

	self.fire_offset = Vector( 0, 0, self:BoundingRadius() / 2 )

	local upright = ents.Create( "phys_keepupright" )
	upright:SetKeyValue( "attach1", self:GetName() )
	upright:SetKeyValue( "angularlimit", "100" )
	upright:SetKeyValue( "angles", "0 0 0" )
	upright:Spawn()
	upright:Activate()
end

function ENT:SetRate( val )
	self.fire_rate = val
end

function ENT:SetRateDev( val )
	self.fire_rate_stddev = val
end

function ENT:SetRadius( val )
	self.fire_radius = val
end

function ENT:SetSpeed( val )
	self.fire_speed = val
end

function ENT:SetLifeTime( val )
	self.cball_lifetime = val
end

function ENT:SetShouldTargetClosest( target_closest )
	self.should_target_closest = target_closest
end

local deviate
local function gaussRandom() -- Returns a gaussian random number, mean 0, stddev 1
	if deviate then
		local y2 = deviate
		deviate = nil
		return y2
	else
		local x1, x2, w, y1, y2

		repeat
			 x1 = 2.0 * math.random() - 1.0
			 x2 = 2.0 * math.random() - 1.0
			 w = x1 * x1 + x2 * x2
			 --print( x1, x2, w )
		until ( w < 1.0 )

		w = math.sqrt( (-2.0 * math.log( w ) ) / w )
		y1 = x1 * w
		y2 = x2 * w

		deviate = y2
		return y1
	end
end

local function removeCball( cball )
	if cball and cball:IsValid() then cball:Fire( "Explode" ) end
end

local pylons_firing = {}
local hook_name = "PylonCBallCheck"
local function onEntityCreated( ent )
	if #pylons_firing == 0 then
		hook.Remove( "OnEntityCreated", hook_name )
		return
	end

	if ent:GetClass() ~= "prop_combine_ball" or ent:GetOwner():IsValid() then return end -- our cballs have no owners

	-- Find the owner
	local pylon
	for i=#pylons_firing, 1, -1 do
		local data = pylons_firing[ i ]
		if data.expire < CurTime() then
			table.remove( pylons_firing, i )
		elseif (ent:GetPos() - data.pylon:GetPos()):LengthSqr() < data.pylon.fire_offset:LengthSqr() * 8 then
			pylon = data.pylon
			table.remove( pylons_firing, i )
			break
		end
	end

	if pylon then
		timer.Simple( pylon.cball_lifetime, removeCball, ent )
	end
end

function ENT:Think()
	local closest_target, closest_target_distance
	local targets = ents.FindInSphere( self:GetPos(), self.fire_radius ) -- Filter on radius
	for i=#targets, 1, -1 do -- Now filter on correct type and visibility
		local target = targets[ i ]
		if not ((target:IsPlayer() and target:Alive()) or (target:IsVehicle() and target:GetDriver():IsValid())) then -- Either player or occupied vehicle
			table.remove( targets, i )
		else
			local tracedata = {}
			tracedata.start =  self:GetPos() + self.fire_offset
			tracedata.endpos = tracedata.start + (target:GetPos() + TARGET_OFFSET - tracedata.start):GetNormalized() * self.fire_radius -- Make the trace go past
			tracedata.filter = { self }
			while true do -- Break inside
				local trace = util.TraceLine( tracedata )
				if trace.Entity and trace.Entity:IsValid() and trace.Entity:GetClass() == "prop_combine_ball" then
					table.insert( tracedata.filter, trace.Entity ) -- Trace again, ignoring this cball.
				else
					if trace.Entity ~= target then
						table.remove( targets, i )
					elseif not closest_target or closest_target_distance > trace.Fraction * self.fire_radius then
						closest_target = targets[ i ]
						closest_target_distance = trace.Fraction * self.fire_radius
					end
					break
				end
			end
		end
	end

	if #targets > 0 then
		local target
		if self.should_target_closest then
			target = closest_target
		else
			target = targets[ math.random( #targets ) ] -- Pick one at random
		end

		local start = self:GetPos() + self.fire_offset
		local targetpos = target:GetPos() + TARGET_OFFSET
		start = start + (targetpos - start):GetNormalized() * self:BoundingRadius() -- Get the spawn point out of the barrel

		local endpos = targetpos
		for pass=1, 4 do -- Make a few passes to approximate future position. There's a closed-form solution to this but it's nasty!
			local time_to_target = (endpos - start):Length() / self.fire_speed
			endpos = targetpos + target:GetVelocity() * time_to_target
		end
		local dir = (endpos - start):Normalize()

		local launcher = ents.Create( "point_combine_ball_launcher" )
		launcher:SetKeyValue( "minspeed", tostring( self.fire_speed ) )
		launcher:SetKeyValue( "maxspeed", tostring( self.fire_speed ) )
		launcher:SetKeyValue( "ballradius", "15" )
		launcher:SetKeyValue( "ballcount", "1" )

		launcher:SetAngles( dir:Angle() )
		launcher:SetPos( start )
		launcher:Spawn()
		launcher:Activate()
		launcher:Fire( "LaunchBall" )
		launcher:Remove()

		self:EmitSound( "weapons/irifle/irifle_fire2.wav" )

		table.insert( pylons_firing, 1, { pylon=self, expire=CurTime() + 0.25 } ) -- 0.25 is the expected time to spawn within
		hook.Add( "OnEntityCreated", hook_name, onEntityCreated )
	end

	if #targets == 0 or self.fire_rate_stddev == 0 then
		self:NextThink( CurTime() + self.fire_rate )
	else
		self:NextThink( CurTime() + gaussRandom() * self.fire_rate_stddev + self.fire_rate )
	end
	return true
end
