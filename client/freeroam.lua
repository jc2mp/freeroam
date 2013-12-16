class 'Freeroam'

function Freeroam:__init()
	self.hotspots = {}

	Network:Subscribe( "Hotspots", self, self.Hotspots )
	Events:Subscribe( "Render", self, self.Render )
end

function Freeroam:Hotspots( args )
	self.hotspots = args
end

function Freeroam:DrawShadowedText( pos, text, colour, size, scale )
    if scale == nil then scale = 1.0 end
    if size == nil then size = TextSize.Default end

    local shadow_colour = Color( 0, 0, 0, colour.a )
    shadow_colour = shadow_colour * 0.4

    Render:DrawText( pos + Vector3( 1, 1, 0 ), text, shadow_colour, size, scale )
    Render:DrawText( pos, text, colour, size, scale )
end

function Freeroam:DrawHotspot( v, dist )
	local pos = v[2] + Vector3( 0, 200, 0 )
	local angle = Angle( Camera:GetAngle().yaw, 0, math.pi ) * Angle( math.pi, 0, 0 )

	local text = "/tp " .. v[1]
	local text_size = Render:GetTextSize( text, TextSize.VeryLarge )

	local t = Transform3()
	t:Translate( pos )
	t:Scale( 1.0 )
    t:Rotate( angle )
    t:Translate( -Vector3( text_size.x, text_size.y, 0 )/2 )

    Render:SetTransform( t )

	local alpha_factor = 255

	if dist <= 1024 then
		alpha_factor = ((math.clamp( dist, 512, 1024 ) - 512)/512) * 255
	elseif dist >= 3072 then
		alpha_factor = (1 - (math.clamp( dist, 3072, 3584 ) - 512)/512) * 255
	end

	self:DrawShadowedText( Vector3( 0, 0, 0 ), text, Color( 255, 255, 255, alpha_factor ), TextSize.VeryLarge )
end

function Freeroam:Render()
	if Game:GetState() ~= GUIState.Game then return end
	if LocalPlayer:GetWorld() ~= DefaultWorld then return end

	for _, v in ipairs(self.hotspots) do
		local dist = v[2]:Distance2D( Camera:GetPosition() )
		if dist < 3584 and dist > 512 then
			self:DrawHotspot( v, dist )
		end
	end
end

freeroam = Freeroam()