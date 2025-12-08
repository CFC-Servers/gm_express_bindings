return function( Module )
    local IsValid = IsValid

    function Module.Enable()
        Module.ogSendToClient = Module.ogSendToClient or AdvDupe2.SendToClient
        function AdvDupe2.SendToClient( ply, data, autoSave )
            if net.Stream.SendSize > #data then
                Module.ogSendToClient( ply, data, autoSave )
                return
            end

            if not IsValid( ply ) then return end
            if #data > AdvDupe2.MaxDupeSize then
                AdvDupe2.Notify( ply, "Copied duplicator filesize is too big!", NOTIFY_ERROR )
                return
            end

            ply.AdvDupe2.Downloading = true
            AdvDupe2.InitProgressBar( ply, "Saving:" )

            local sendData = {
                autoSave = autoSave,
                data = data
            }

            express.Send( "AdvDupe2.ReceiveFile", sendData, ply, function( cbPly )
                cbPly.AdvDupe2.Downloading = false
            end )
        end

        express.Receive( "AdvDupe2.SendFile", function( ply, data )
            if not IsValid( ply ) then return end
            if not ply.AdvDupe2 then ply.AdvDupe2 = {} end

            ply.AdvDupe2.Uploading = true
            AdvDupe2.InitProgressBar( ply, "Uploading: " )

            local name = data.name
            local fileData = data.data

            ply.AdvDupe2.Name = string.match( name, "([%w_ ]+)" ) or "Advanced Duplication"
            AdvDupe2.LoadDupe( ply, AdvDupe2.Decode( fileData ) )
            ply.AdvDupe2.Uploading = false
        end )
    end

    function Module.Disable()
        AdvDupe2.SendToClient = Module.ogSendToClient
        express.ClearReceiver( "AdvDupe2.SendFile" )
    end
end
