local enabled = CreateConVar( "express_enable_p2m", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable Prop2Mesh Bindings" )

local function enable()
    if not prop2mesh then return end

    express.Receive( "prop2mesh_download", function( objects )
        prop2mesh.downloads = prop2mesh.downloads + #objects

        for _, obj in ipairs( objects ) do
            local crc = obj.crc
            local partData = obj.partData
            prop2mesh.handleDownload( crc, partData )
        end
    end )
end

local function disable()
    if not prop2mesh then return end
    express.Receive( "prop2mesh_download", nil )
end

cvars.AddChangeCallback( "express_enable_p2m", function( _, new )
    if new == 0 then return disable() end
    if new ~= 0 then return enable() end
end, "setup_teardown" )

hook.Add( "PostGamemodeLoaded", "Express_P2MBindings", function()
    if enabled:GetBool() then enable() end
end )
