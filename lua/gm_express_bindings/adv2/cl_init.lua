return function( Module )
    function Module.Enable()
        express.Receive( "AdvDupe2.ReceiveFile", function( data )
            local autoSave = data.autoSave == 1
            AdvDupe2.ReceiveFile( data.data, autoSave )
        end )

        Module.originalSendFile = Module.originalSendFile or AdvDupe2.SendFile
        AdvDupe2.SendFile = function( name, data )
            if net.Stream.SendSize > #data then
                Module.originalSendFile( name, data )
                return
            end

            express.Send( "AdvDupe2.SendFile", { name = name, data = data }, function()
                AdvDupe2.Uploading = nil
                AdvDupe2.File = nil
                AdvDupe2.RemoveProgressBar()
            end )
        end
    end

    function Module.Disable()
        AdvDupe2.SendFile = Module.originalSendFile
        express.ClearReceiver( "AdvDupe2.ReceiveFile" )
    end
end
