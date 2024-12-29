return function( Module )
    local IsValid = IsValid

    function Module.Enable()
        Module.ogSendToClient = Module.ogSendToClient or AdvDupe2.SendToClient
        function AdvDupe2.SendToClient( ply, data, autoSave )
            if not IsValid( ply ) then return end
            ply.AdvDupe2.Downloading = true
            AdvDupe2.InitProgressBar( ply, "Saving:" )

            local sendData = {
                autoSave = autoSave,
                data = data
            }

            express.Send( "advdupe2_receivefile", sendData, ply, function( cbPly )
                cbPly.AdvDupe2.Downloading = false
                AdvDupe2.RemoveProgressBar( ply )
            end )
        end

        express.Receive( "advdupe2_receivefile", function( ply, data )
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

    function Module.Disable()
        AdvDupe2.SendToClient = Module.ogSendToClient
        express.ClearReceiver( "advdupe2_receivefile" )
    end
end
