-- Adds hooks to the networking functions so we know when a message is starting and when a message has been sent out. We need
-- to know this information to properly insert ourselves into netstream
-- This file is named to run as soon as we can - any other addon might introduce localizing net.Send/etc which would cause us to have issues...

local Start, Send, SendToServer, Broadcast = net.Start, net.Send, net.SendToServer, net.Broadcast

function net.Start(messageName, unreliable)
    Start(messageName, unreliable)
    hook.Run("Express_PostNetStart", messageName, unreliable)
end

if SERVER then
    function net.Broadcast()
        Broadcast()
        hook.Run("Express_PostNetBroadcast")
    end

    function net.Send(target)
        Send(target)
        hook.Run("Express_PostNetSend", target)
    end

    -- For these next functions, we are directly going to change how they work,
    -- for the sake of getting who we should send the stream to. I don't believe this is
    -- a problem - I talked to Raphael about it and net.SendPVS/net.SendPAS internally 
    -- do the same thing with a CRecipientFilter
    local SharedRecipientFilter = RecipientFilter()

    -- The next checks should avoid an unnecessary GetPlayers() call when the netstream module isn't active
    -- (or anything else using it, for whatever reason)

    function net.SendOmit(dontsend)
        SharedRecipientFilter:RemoveAllPlayers()
        SharedRecipientFilter:AddAllPlayers()
        if type(dontsend) == "Player" then
            SharedRecipientFilter:RemovePlayer(dontsend)
        else
            SharedRecipientFilter:RemovePlayers(dontsend)
        end
        Send(SharedRecipientFilter)

        if not next(hook.GetTable()["Express_PostNetSendPAS"]) then return end
        hook.Run("Express_PostNetSendOmit", SharedRecipientFilter:GetPlayers())
    end

    function net.SendPAS(position)
        SharedRecipientFilter:RemoveAllPlayers()
        SharedRecipientFilter:AddPAS(position)
        Send(SharedRecipientFilter)

        if not next(hook.GetTable()["Express_PostNetSendPAS"]) then return end
        hook.Run("Express_PostNetSendPAS", position, SharedRecipientFilter:GetPlayers())
    end

    function net.SendPVS(position)
        SharedRecipientFilter:RemoveAllPlayers()
        SharedRecipientFilter:AddPVS(position)
        Send(SharedRecipientFilter)

        if not next(hook.GetTable()["Express_PostNetSendPVS"]) then return end
        hook.Run("Express_PostNetSendPVS", position, SharedRecipientFilter:GetPlayers())
    end
else
    function net.SendToServer()
        SendToServer()
        hook.Run("Express_PostNetSendToServer")
    end
end