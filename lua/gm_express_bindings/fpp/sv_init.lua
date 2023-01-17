local rawget = rawget
local table_insert = table.insert

local originalPlySendTouchData
local originalRecalculateCanTouch
local empty = {}
local enabled = CreateConVar( "express_enable_fpp", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable FPP Bindings" )

local function enable()
    if not FPP then return end
    originalPlySendTouchData = originalPlySendTouchData or FPP.plySendTouchData
    originalRecalculateCanTouch = originalRecalculateCanTouch or FPP.recalculateCanTouch

    local function writeEntData( ply, ent, tbl )
        local cppiOwner = ent:CPPIGetOwner()
        local owner = IsValid( cppiOwner ) and cppiOwner:EntIndex() or -1

        local restrictConstraint = ent.FPPRestrictConstraint or ent.FPPCanTouch or empty
        local touchability = rawget( restrictConstraint, ply ) or ""

        local constraintReasons = ent.FPPConstraintReasons or ent.FPPCanTouchWhy or empty
        local reasons = rawget( constraintReasons, ply ) or ""

        table_insert( tbl, ent:EntIndex() )
        table_insert( tbl, owner )
        table_insert( tbl, touchability )
        table_insert( tbl, reasons )
    end

    FPP.recalculateCanTouch = function( plys, ents )
        if #plys == 1 and not plys[1].Express_CanReceiveFPP then
            return
        end

        return originalRecalculateCanTouch( plys, ents )
    end

    FPP.plySendTouchData = function( ply, ents )
        local entCount = #ents
        if entCount == 0 then return end

        -- If <300 ents, send this even if they're not ready for the Express message
        if entCount < 300 then
            return originalPlySendTouchData( ply, ents )
        end

        if not ply.Express_CanReceiveFPP then return end

        local tbl = {}
        for i = 1, entCount do
            writeEntData( ply, rawget( ents, i ), tbl )
        end

        express.Send( "fpp_touchability_data", tbl, ply )
    end

    hook.Add( "ExpressPlayerReceiver", "Express_FPPBindings", function( ply, message )
        if message ~= "fpp_touchability_data" then return end
        ply.Express_CanReceiveFPP = true
        FPP.recalculateCanTouch( { ply }, ents.GetAll() )
    end )
end

local function disable()
    FPP.plySendTouchData = originalPlySendTouchData
    FPP.recalculateCanTouch = originalRecalculateCanTouch
    hook.Remove( "ExpressPlayerReceiver", "Express_FPPBindings" )
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
