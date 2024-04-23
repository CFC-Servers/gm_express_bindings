return function( Module )
    function Module.Enable()
        if not prop2mesh then return end
        Module.originalSendDownload = Module.originalSendDownload or prop2mesh.sendDownload

        local pendingSendDownloads = {}

        prop2mesh.sendDownload = function( ply, ent, crc )
            pendingSendDownloads[ply] = pendingSendDownloads[ply] or {}
            table.insert( pendingSendDownloads[ply], { ent, crc } )
            timer.Start( "express_p2m_send_download" )
        end

        timer.Create( "express_p2m_send_download", 0.25, 0, function()
            for ply, downloads in pairs( pendingSendDownloads ) do
                local downloadObjects = {}

                for _, download in ipairs( downloads ) do
                    local ent, crc = download[1], download[2]

                    if IsValid( ent ) then
                        local partLists = ent.prop2mesh_partlists

                        if partLists then
                            table.insert( downloadObjects, { crc = crc, partData = partLists[crc] } )
                        end
                    end
                end

                if #downloadObjects > 0 then
                    express.Send( "prop2mesh_download", downloadObjects, ply )
                end
            end

            pendingSendDownloads = {}
            timer.Stop( "express_p2m_send_download" )
        end )
        timer.Stop( "express_p2m_send_download" )
    end

    function Module.Disable()
        if not prop2mesh then return end
        prop2mesh.sendDownload = Module.originalSendDownload
    end
end
