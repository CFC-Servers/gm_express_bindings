return function( Module )
    function Module.Enable()
        express.Receive( "advdupe2_receivefile", function( data )
            AdvDupe2.ReceiveFile( data.data, data.autoSave )
        end )

        Module.originalSendFile = Module.originalSendFile or AdvDupe2.SendFile
        AdvDupe2.SendFile = function( name, data )
            express.Send( "advdupe2_receivefile", { name = name, data = data }, function()
                AdvDupe2.Uploading = nil
                AdvDupe2.File = nil
                AdvDupe2.RemoveProgressBar()
            end )
        end
    end

    function Module.Disable()
        AdvDupe2.SendFile = Module.originalSendFile
        express.ClearReceiver( "advdupe2_receivefile" )
    end
end
