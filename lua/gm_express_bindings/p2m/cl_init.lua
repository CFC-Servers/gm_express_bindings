local enabled = CreateConVar( "express_enable_p2m", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable Prop2Mesh Bindings" )

local GREEN = Color( 50, 200, 50 )
local GREY = Color( 100, 100, 100 )
local ORANGE = Color( 225, 100, 50 )
local BLUE = Color( 93, 145, 240 )

local function enable()
    if not prop2mesh then return end
    local downloadStart

    express.Receive( "prop2mesh_download", function( objects )
        if downloadStart then
            local diff = math.Round( SysTime() - downloadStart, 2 )
            MsgC(
                GREEN, "Completed download of ",
                GREY, #objects,
                GREEN, " P2M objects in ",
                GREY, diff,
                GREEN, " seconds ",
                GREY, "(",
                BLUE, "Accelerated by Express",
                GREY, ")",
                "\n"
            )
        end
        prop2mesh.downloads = prop2mesh.downloads + #objects

        for _, obj in ipairs( objects ) do
            local crc = obj.crc
            local partData = obj.partData
            if partData then
                prop2mesh.handleDownload( crc, partData )
            end
        end
    end )

    express.ReceivePreDl( "prop2mesh_download", function( _, _, size )
        downloadStart = SysTime()
        size = string.NiceSize( size )
        MsgC( GREEN, "Starting Accelerated P2M download ", GREY, "(", ORANGE, size, GREY, ")", "\n" )
    end )
end

local function disable()
    if not prop2mesh then return end
    express.ClearReceiver( "prop2mesh_download" )
end

cvars.AddChangeCallback( "express_enable_p2m", function( _, new )
    if new == "0" then return disable() end
    if new == "1" then return enable() end
end, "setup_teardown" )

ExpressBindings.waitForExpress( "Express_P2MBindings", function()
    if enabled:GetBool() then enable() end
end )
