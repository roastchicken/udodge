TOOL.Category		= "Pylon"
TOOL.Name			= "Pylon Spawner"
TOOL.Command		= nil
TOOL.ConfigName		= ""

TOOL.ClientConVar[ "fire_rate" ] = "1.5"
TOOL.ClientConVar[ "fire_rate_stddev" ] = "0.3"
TOOL.ClientConVar[ "fire_radius" ] = "2000"
TOOL.ClientConVar[ "fire_speed" ] = "850"
TOOL.ClientConVar[ "cball_lifetime" ] = "3"
TOOL.ClientConVar[ "target_closest" ] = "0"

cleanup.Register( "Pylons" )

if CLIENT then
	language.Add( "Tool_pylon_name", "Pylon Spawner" )
	language.Add( "Tool_pylon_desc", "Spawns a pylon that will shoot combine balls at passersby!" )
	language.Add( "Tool_pylon_0", "Left click to place a pylon. Right click on a pylon to update it" )
	language.Add( "Undone_Pylon", "Undone Pylon" )
	language.Add( "SBoxLimit_pylons", "You've hit the Pylons limit!" )
else
	CreateConVar( "sbox_maxpylons", "8" )
end

function TOOL:LeftClick( trace )
	if ( trace.Entity and trace.Entity:IsPlayer() ) then return false end

	if CLIENT then return true end

	local ply = self:GetOwner()

	local fire_rate			= self:GetClientNumber( "fire_rate" )
	local fire_rate_stddev		= self:GetClientNumber( "fire_rate_stddev" )
	local fire_radius		= self:GetClientNumber( "fire_radius" )
	local fire_speed 		= self:GetClientNumber( "fire_speed" )
	local cball_lifetime 		= self:GetClientNumber( "cball_lifetime" )
	local target_closest		= self:GetClientNumber( "target_closest" )

	if not self:GetSWEP():CheckLimit( "pylons" ) then return false end

	local Ang = Angle(0)
	local spawn = trace.HitPos + trace.HitNormal * 8
	local pylon = MakePylon( ply, spawn, Ang, fire_rate, fire_rate_stddev, fire_radius, fire_speed, cball_lifetime, target_closest, false )

	undo.Create("Pylon")
	undo.AddEntity( pylon )
	undo.SetPlayer( ply )
	undo.Finish()

	ply:AddCleanup( "Pylons", pylon )

	return true

end

function TOOL:RightClick( trace )
	if ( trace.Entity:IsValid() and trace.Entity:GetClass() == "pylon" ) then
		if CLIENT then return true end

		local fire_rate			= self:GetClientNumber( "fire_rate" )
		local fire_rate_stddev	= self:GetClientNumber( "fire_rate_stddev" )
		local fire_radius		= self:GetClientNumber( "fire_radius" )
		local fire_speed 		= self:GetClientNumber( "fire_speed" )
		local cball_lifetime 	= self:GetClientNumber( "cball_lifetime" )
		local target_closest	= self:GetClientNumber( "target_closest" )

		--Update existing pylon settings
		SetPylonSettings( trace.Entity, fire_rate, fire_rate_stddev, fire_radius, fire_speed, cball_lifetime, target_closest )
		return true
	else
		return false
	end
end

if (SERVER) then
	function SetPylonSettings( pylon, fire_rate, fire_rate_stddev, fire_radius, fire_speed, cball_lifetime, target_closest )
		pylon:SetRate( fire_rate )
		pylon:SetRateDev( fire_rate_stddev )
		pylon:SetRadius( fire_radius )
		pylon:SetSpeed( fire_speed )
		pylon:SetLifeTime( cball_lifetime )
		pylon:SetShouldTargetClosest( tobool( target_closest ) )
	end

	function MakePylon( ply, Pos, Ang, fire_rate, fire_rate_stddev, fire_radius, fire_speed, cball_lifetime, target_closest )
		--if ( !ply:CheckLimit( "pylons" ) ) then return false end

		local pylon = ents.Create( "pylon" )
		DoPropSpawnedEffect( pylon )

		pylon:SetAngles( Ang )
		pylon:SetPos( Pos )

		SetPylonSettings( pylon, fire_rate, fire_rate_stddev, fire_radius, fire_speed, cball_lifetime, target_closest )

		pylon:Spawn()
		pylon:Activate()

		ply:AddCount( "pylons", pylon )

		return pylon

	end

	duplicator.RegisterEntityClass( "pylon", MakePylon, "Pos", "Ang", "fire_rate", "fire_rate_stddev", "fire_radius", "fire_speed", "cball_lifetime", "target_closest" )

end

function TOOL.BuildCPanel( CPanel )
	// HEADER
	CPanel:AddControl( "Header", { Text = "Pylon Spawner", Description	= "Spawns a Pylon that shoots combine balls." }  )

	CPanel:AddControl( "Slider", {	Label = "Rate of Fire",
									Description = "",
									Type = "Float",
									Min = 0.15,
									Max = 10,
									Command = "pylon_fire_rate" } )

	CPanel:AddControl( "Slider", {  Label = "Randomize Rate of Fire",
									Description = "",
									Type = "Float",
									Min = 0,
									Max = 10,
									Command = "pylon_fire_rate_stddev" } )

	CPanel:AddControl( "Slider", {  Label = "Search Radius",
									Description = "",
									Type = "Integer",
									Min = 10,
									Max = 100000,
									Command = "pylon_fire_radius" } )

	CPanel:AddControl( "Slider", {  Label = "Combine Ball Speed",
									Description = "",
									Type = "Integer",
									Min = 1,
									Max = 10000,
									Command = "pylon_fire_speed" } )

	CPanel:AddControl( "Slider", {  Label = "Combine Ball Lifetime",
									Description = "",
									Type = "Float",
									Min = 0,
									Max = 15,
									Command = "pylon_cball_lifetime" } )

	CPanel:AddControl( "Checkbox", {Label = "Target Closest Player (Otherwise Target Random)",
									Description = "",
									Command = "pylon_target_closest" } )

	local button = vgui.Create( "DButton", CPanel )
	button.DoClick = function( self )
		RunConsoleCommand( "pylon_fire_rate", "1.5" )
		RunConsoleCommand( "pylon_fire_rate_stddev", "0.3" )
		RunConsoleCommand( "pylon_fire_radius", "2000" )
		RunConsoleCommand( "pylon_fire_speed", "850" )
		RunConsoleCommand( "pylon_cball_lifetime", "3" )
		RunConsoleCommand( "pylon_target_closest", "0" )
	end
	button:SetText( "Reset to Defaults" )
	CPanel:AddItem( button )
end
