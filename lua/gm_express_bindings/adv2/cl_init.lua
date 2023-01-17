ExpressBindings.Adv2 = ExpressBindings.Adv2 or {}
local ExpressAdv2 = ExpressBindings.Adv2

local enabled = CreateConVar( "express_enable_adv2", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable AdvDupe2 Bindings" )

local function envOn( data )
    setfenv( ExpressAdv2.originalReceiver, {
        net = {
            ReadUInt = function()
                return data.autoSave
            end,

            ReadStream = function( _, cb )
                cb( data.data )
            end
        },
        file = file,
        string = string,
        AdvDupe2 = AdvDupe2,
        NOTIFY_ERROR = NOTIFY_ERROR,
        LocalPlayer = LocalPlayer,
    } )
end

local function envOff()
    setfenv( ExpressAdv2.originalReceiver, getfenv( 0 ) )
end

local function enable()
    if not AdvDupe2 then return end

    ExpressAdv2.originalReceiver = ExpressAdv2.originalReceiver or net.Receivers["advdupe2_receivefile"]

    express.Receive( "advdupe2_receivefile", function( data )
        envOn( data )
        ExpressAdv2.originalReceiver()
        envOff()
    end )

    ExpressAdv2.originalUploadFile = ExpressAdv2.originalUploadFile or AdvDupe2.UploadFile
    AdvDupe2.UploadFile = function( ... )
        local name
        local stub = function() end

        local start = net.Start
        local sendToServer = net.SendToServer
        local writeString = net.WriteString
        local writeStream = net.WriteStream

        net.Start = stub
        net.SendToServer = stub

        net.WriteString = function( str )
            name = str
        end

        net.WriteStream = function( fileData, cb )
            express.Send( "advdupe2_receivefile", {
                name = name,
                data = fileData
            }, cb )
        end

        local ok, err = pcall( ExpressAdv2.originalUploadFile, ... )
        if not ok then
            print( "Error uploading file:", err )
        end

        net.Start = start
        net.SendToServer = sendToServer
        net.WriteString = writeString
        net.WriteStream = writeStream
    end
end

local function disable()
    envOff()
    AdvDupe2.UploadFile = ExpressAdv2.originalUploadFile
    express.ClearReceiver( "advdupe2_receivefile" )
end

cvars.AddChangeCallback( "express_enable_adv2", function( _, _, new )
    if new == "0" then return disable() end
    if new == "1" then return enable() end
end, "setup_teardown" )

ExpressBindings.waitForExpress( "Express_Adv2Bindings", function()
    if enabled:GetBool() then enable() end
end )

