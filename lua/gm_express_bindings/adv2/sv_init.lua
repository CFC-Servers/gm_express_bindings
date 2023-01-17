ExpressBindings.Adv2 = ExpressBindings.Adv2 or {}
local ExpressAdv2 = ExpressBindings.Adv2

local enabled = CreateConVar( "express_enable_adv2", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable AdvDupe2 Bindings" )

local function enable()
    if not AdvDupe2 then return end

    ExpressAdv2.ogSendToClient = ExpressAdv2.ogSendToClient or AdvDupe2.SendToClient
    function AdvDupe2.SendToClient( ply, data, autoSave )
        if not IsValid( ply ) then return end
        ply.AdvDupe2.Downloading = true
        AdvDupe2.InitProgressBar( ply, "Saving:" )

        local sendData  = {
            autoSave = autoSave,
            data = data
        }

        print( SysTime(), "Running SendToClient, sending advdupe2_receivefile" )
        express.Send( "advdupe2_receivefile", sendData, ply, function( cbPly )
            print( SysTime(), "advdupe2_receivefile callback for", cbPly )
            cbPly.AdvDupe2.Downloading = false
        end )
    end

    express.Receive( "advdupe2_receivefile", function( ply, data )
        print( SysTime(), "Received advdupe2_receivefile from", ply )
        if not IsValid( ply ) then return end
        ply.AdvDupe2.Uploading = true
        AdvDupe2.InitProgressBar( ply, "Opening: " )

        local name = data.name
        local fileData = data.data

        if not ply.AdvDupe2 then ply.AdvDupe2 = {} end

        local _1, _2, _3 = string.find( name, "([%w_]+)" )
        if _3 then
            ply.AdvDupe2.Name = string.sub( _3, 1, 32 )
        else
            ply.AdvDupe2.Name = "Advanced Duplication"
        end

        AdvDupe2.LoadDupe( ply, AdvDupe2.Decode( fileData ) )
        ply.AdvDupe2.Uploading = false
        AdvDupe2.RemoveProgressBar( ply )
    end )
end

local function disable()
    AdvDupe2.SendToClient = ExpressAdv2.ogSendToClient
    express.ClearReceiver( "advdupe2_receivefile" )
end

cvars.AddChangeCallback( "express_enable_adv2", function( _, _, new )
    if new == "0" then return disable() end
    if new == "0" then return enable() end
end, "setup_teardown" )

ExpressBindings.waitForExpress( "Express_Adv2Bindings", function()
    if enabled:GetBool() then enable() end
end )
