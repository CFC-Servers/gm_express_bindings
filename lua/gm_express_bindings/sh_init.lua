AddCSLuaFile()

ExpressBindings = {}
function ExpressBindings.waitForExpress( name, cb )
    hook.Add( "ExpressLoaded", name, function()
        hook.Add( "Think", name, function()
            hook.Remove( "Think", name )
            cb()
        end )
    end )
end

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
