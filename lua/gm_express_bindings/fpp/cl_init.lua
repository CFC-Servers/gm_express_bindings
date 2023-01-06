local rawget = rawget
local rawset = rawset
local enabled = CreateConVar( "express_enable_fpp", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable FPP Bindings" )

local function enable()
    local entOwners = FPP.entOwners
    local entTouchability = FPP.entTouchability
    local entTouchReasons = FPP.entTouchReasons

    express.Receive( "fpp_touchability_data", function( data )
        local dataCount = #data
        for i = 1, dataCount, 4 do
            local ent = rawget( data, i )
            local owner = rawget( data, i + 1 )
            local touchability = rawget( data, i + 2 )
            local reason = rawget( data, i + 3 )

            rawset( entOwners, ent, owner )
            if touchability ~= "" then
                rawset( entTouchability, ent, touchability )
            end

            if reason ~= "" then
                rawset( entTouchReasons, ent, reason )
            end
        end
    end )
end

local function disable()
    express.Receive( "fpp_touchability_data", nil )
end

cvars.AddChangeCallback( "express_enable_fpp", function( _, old, new )
    if new == 0 and old ~= 0 then
        return disable()
    end

    if new ~= 0 then
        return enable()
    end
end, "setup_teardown" )

hook.Add( "PostGamemodeLoaded", "Express_FPPBindings", function()
    if enabled:GetBool() then enable() end
end )

