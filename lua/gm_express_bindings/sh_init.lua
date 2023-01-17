AddCSLuaFile()

local loaded = false
ExpressBindings = {}
ExpressBindings.waiting = {}

function ExpressBindings.waitForExpress( name, cb )
    if loaded then
        ErrorNoHalt( "ExpressBindings.waitForExpress called after Express was loaded!" )
        return cb()
    end

    ExpressBindings.waiting[name] = cb
end

hook.Add( "ExpressLoaded", "ExpressBindings_Loader", function()
    hook.Add( "Think", "ExpressBindings_Loader", function()
        hook.Remove( "Think", "ExpressBindings_Loader" )

        for name, cb in pairs( ExpressBindings.waiting ) do
            local success, err = pcall( cb )
            if not success then
                ErrorNoHalt( "ExpressBindings Loader (" .. name .. ") : " .. err )
            end
        end
    end )
end )

-- TODO: Make a proper loader
if SERVER then
    require( "playerload" )
    include( "fpp/sv_init.lua" )
    AddCSLuaFile( "fpp/cl_init.lua" )

    include( "adv2/sv_init.lua" )
    AddCSLuaFile( "adv2/cl_init.lua" )

    include( "p2m/sv_init.lua" )
    AddCSLuaFile( "p2m/cl_init.lua" )
else
    include( "fpp/cl_init.lua" )
    include( "adv2/cl_init.lua" )
    include( "p2m/cl_init.lua" )
end
