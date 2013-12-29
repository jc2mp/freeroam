class 'Freeroam'

function Freeroam:__init()
    self.vehicles               = {}
    self.player_spawns          = {}
    self.teleports              = {}
    self.hotspots               = {}

    -- Weapons to use
    self.one_handed             = { Weapon.Handgun, Weapon.Revolver, Weapon.SMG, 
                                    Weapon.SawnOffShotgun }

    self.two_handed             = { Weapon.Assault, Weapon.Shotgun, 
                                    Weapon.Sniper, Weapon.MachineGun }

    self.ammo_counts            = {
        [2] = { 12, 60 }, [4] = { 7, 35 }, [5] = { 30, 90 },
        [6] = { 3, 18 }, [11] = { 20, 100 }, [13] = { 6, 36 },
        [14] = { 4, 32 }, [16] = { 3, 12 }, [17] = { 5, 5 },
        [28] = { 26, 130 }
    }

    -- Load spawns
    self:LoadSpawns( "spawns.txt" )

    -- Subscribe to events
    Events:Subscribe( "ClientModuleLoad",   self, self.ClientModuleLoad )
    Events:Subscribe( "ModuleUnload",       self, self.ModuleUnload )
    Events:Subscribe( "ModulesLoad",        self, self.ModulesLoad )
    Events:Subscribe( "PlayerSpawn",        self, self.PlayerSpawn )
    Events:Subscribe( "PlayerChat",         self, self.PlayerChat )
    Events:Subscribe( "PlayerDeath",         self, self.PlayerDeath )
end

-- Functions to parse the spawns
function Freeroam:LoadSpawns( filename )
    -- Open up the spawns
    print("Opening " .. filename)
    local file = io.open( filename, "r" )

    if file == nil then
        print( "No spawns.txt, aborting loading of spawns" )
        return
    end

    -- Start a timer to measure load time
    local timer = Timer()

    -- For each line, handle appropriately
    for line in file:lines() do
        if line:sub(1,1) == "V" then
            self:ParseVehicleSpawn( line )
        elseif line:sub(1,1) == "P" then
            self:ParsePlayerSpawn( line )
        elseif line:sub(1,1) == "T" then
            self:ParseTeleport( line )
        end
    end
    
    for k, v in pairs(self.teleports) do
        table.insert( self.hotspots, { k, v } )
    end

    print( string.format( "Loaded spawns, %.02f seconds", 
                            timer:GetSeconds() ) )

    file:close()
end

function Freeroam:ParseVehicleSpawn( line )
    -- Remove start, end and spaces from line
    line = line:gsub( "VehicleSpawn%(", "" )
    line = line:gsub( "%)", "" )
    line = line:gsub( " ", "" )

    -- Split line into tokens
    local tokens = line:split( "," )   

    -- Model ID string
    local model_id_str  = tokens[1]

    -- Create tables containing appropriate strings
    local pos_str       = { tokens[2], tokens[3], tokens[4] }
    local ang_str       = { tokens[5], tokens[6], tokens[7], tokens[8] }

    -- Create vehicle args table
    local args = {}

    -- Fill in args table
    args.model_id       = tonumber( model_id_str )
    args.position       = Vector3(   tonumber( pos_str[1] ), 
                                    tonumber( pos_str[2] ),
                                    tonumber( pos_str[3] ) )

    args.angle          = Angle(    tonumber( ang_str[1] ),
                                    tonumber( ang_str[2] ),
                                    tonumber( ang_str[3] ),
                                    tonumber( ang_str[4] ) )

    if #tokens > 8 then
        if tokens[9] ~= "NULL" then
            -- If there's a template, set it
            args.template = tokens[9]
        end

        if #tokens > 9 then
            if tokens[10] ~= "NULL" then
                -- If there's a decal, set it
                args.decal = tokens[10]
            end
        end
    end

    -- Create the vehicle
    args.enabled = true
    local v = Vehicle.Create( args )

    -- Save to table
    self.vehicles[ v:GetId() ] = v
end

function Freeroam:ParsePlayerSpawn( line )
    -- Remove start, spaces
    line = line:gsub( "P", "" )
    line = line:gsub( " ", "" )

    -- Split into tokens
    local tokens        = line:split( "," )
    -- Create table containing appropriate strings
    local pos_str       = { tokens[1], tokens[2], tokens[3] }
    -- Create vector
    local vector        = Vector3(   tonumber( pos_str[1] ), 
                                    tonumber( pos_str[2] ),
                                    tonumber( pos_str[3] ) )

    -- Save to table
    table.insert( self.player_spawns, vector )
end

function Freeroam:ParseTeleport( line )
    -- Remove start, spaces
    line = line:sub( 3 )
    line = line:gsub( " ", "" )

    -- Split into tokens
    local tokens        = line:split( "," )
    -- Create table containing appropriate strings
    local pos_str       = { tokens[2], tokens[3], tokens[4] }
    -- Create vector
    local vector        = Vector3(   tonumber( pos_str[1] ), 
                                    tonumber( pos_str[2] ),
                                    tonumber( pos_str[3] ) )

    -- Save to teleports table
    self.teleports[ tokens[1] ] = vector
end

-- Functions for utility use
function Freeroam:GiveNewWeapons( p )
    -- Give random weapons from the predefined list
    p:ClearInventory()

    local one_id = table.randomvalue( self.one_handed )
    local two_id = table.randomvalue( self.two_handed )

    p:GiveWeapon( WeaponSlot.Right, 
        Weapon( one_id, 
            self.ammo_counts[one_id][1],
            self.ammo_counts[one_id][2] * 6 ) )
    p:GiveWeapon( WeaponSlot.Primary, 
        Weapon( two_id, 
            self.ammo_counts[two_id][1],
            self.ammo_counts[two_id][2] * 6 ) )
end

function Freeroam:RandomizePosition( pos, magnitude, offset )
    if magnitude == nil then
        magnitude = 10
    end

    if offset == nil then
        offset = 250
    end

    return pos + Vector3(    math.random( -magnitude, magnitude ), 
                            math.random( -magnitude, 0 ) + offset, 
                            math.random( -magnitude, magnitude ) )
end

-- Chat handlers
-- Create table containing chat handlers
ChatHandlers = {}

function ChatHandlers:teleport( args )
    local dest = args[1]

    -- Handle user help
    if dest == "" or dest == nil or dest == "help" then
        args.player:SendChatMessage( "Teleport locations: ", 
                                        Color( 0, 255, 0 ) )

        local i = 0
        local str = ""

        for k,v in pairs(self.teleports) do
            -- Send message every 4 teleports
            i = i + 1
            str = str .. k

            if i % 4 ~= 0 then
                -- If it's not the last teleport of the line, add a comma
                str = str .. ", "
            else
                args.player:SendChatMessage( "    " .. str, Color( 255, 255, 255 ) )
                str = ""
            end
        end
    elseif self.teleports[dest] ~= nil then
        -- If they're not in the main world, refuse them
        if args.player:GetWorld() ~= DefaultWorld then
            args.player:SendChatMessage( 
                "You are not in the main world! Exit any gamemodes and try again.",
                Color( 255, 0, 0 ) )

            return
        end

        -- If the teleport is valid, teleport them there
        args.player:SetPosition( 
            self:RandomizePosition( self.teleports[dest] ) )
    else
        -- Notify of invalid teleport
        args.player:SendChatMessage( "Invalid teleport destination!", 
                                        Color( 255, 0, 0 ) )
    end
end

-- Alias tp to teleport
ChatHandlers.tp = ChatHandlers.teleport

-- Events
function Freeroam:ClientModuleLoad( args )
    Network:Send( args.player, "Hotspots", self.hotspots )
end

function Freeroam:ModuleUnload( args )
    -- On unload, remove all valid vehicles
    for k,v in pairs(self.vehicles) do
        if IsValid(v) then
            v:Remove()
        end
    end
end

function Freeroam:ModulesLoad()
    for _, v in ipairs(self.player_spawns) do
        Events:Fire( "SpawnPoint", v )
    end

    for _, v in pairs(self.teleports) do
        Events:Fire( "TeleportPoint", v )
    end
end

function Freeroam:PlayerSpawn( args )
    local default_spawn = true

    if args.player:GetWorld() == DefaultWorld then
        -- If there are any player spawns, then teleport them
        if #self.player_spawns > 0 then
            local position = table.randomvalue( self.player_spawns )            

            args.player:SetPosition( self:RandomizePosition( position ) )
            default_spawn = false
        end

        self:GiveNewWeapons( args.player )
    end

    return default_spawn
end

function Freeroam:PlayerChat( args )
    local msg = args.text

    if msg:sub(1, 1) ~= "/" then
        return true
    end

    -- Truncate the starting character
    msg = msg:sub(2)

    -- Split the message
    local cmd_args = msg:split(" ")
    local cmd_name = cmd_args[1]

    -- Remove the command name
    table.remove( cmd_args, 1 )
    cmd_args.player = args.player

    -- Grab the function
    local func = ChatHandlers[string.lower(cmd_name)]
    if func ~= nil then
        -- If it's valid, call it
        func( self, cmd_args )
    end

    return false
end

function Freeroam:PlayerDeath( args )
	if args.killer and args.killer:GetSteamId() ~= args.player:GetSteamId() then
		args.killer:SetMoney(args.killer:GetMoney() + 100)
	end
end

-- Create our class, and start the script proper
freeroam = Freeroam()