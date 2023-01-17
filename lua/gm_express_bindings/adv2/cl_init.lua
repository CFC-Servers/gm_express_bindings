local originalReceiver
local originalUploadFile
local enabled = CreateConVar( "express_enable_adv2", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable AdvDupe2 Bindings" )

local function envOn( data )
    setfenv( originalReceiver, {
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
    setfenv( originalReceiver, getfenv( 0 ) )
end

local function enable()
    if not AdvDupe2 then return end

    originalReceiver = originalReceiver or net.Receivers["advdupe2_receivefile"]

    express.Receive( "advdupe2_receivefile", function( data )
        envOn( data )
        originalReceiver()
        envOff()
    end )

    originalUploadFile = originalUploadFile or AdvDupe2.UploadFile
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

        local ok, err = pcall( originalUploadFile, ... )
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
    AdvDupe2.UploadFile = originalUploadFile
    express.ClearReceiver( "advdupe2_receivefile" )
end

cvars.AddChangeCallback( "express_enable_adv2", function( _, old, new )
    if new == 0 and old ~= 0 then
        return disable()
    end

    if new ~= 0 then
        return enable()
    end
end, "setup_teardown" )

hook.Add( "PostGamemodeLoaded", "Express_Adv2Bindings", function()
    if enabled:GetBool() then enable() end
end )

