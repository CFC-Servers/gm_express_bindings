-- Experimental, mileage may vary
-- It seemed to work in my testing (with downloading the SF docs, and using SF read/write stream methods).
-- No clue how well disabling/re-enabling the module works though
AddCSLuaFile()

local HOOKNAME = "Express_NetstreamBindings"

-- Queue class and iterator
local QueueIterator = function(Queue, Index)
    Index = Index + 1
    local Available, Value = Queue:Peek(Index)
    if Available then
        return Index, Value
    end
end
local Queue = setmetatable({}, {
    __index = {
        Enqueue = function(self, item)
            self.__writePtr = self.__writePtr + 1
            self.__items[self.__writePtr] = item
        end,
        Peek = function(self, forwards)
            local idx = self.__readPtr + (forwards or 1)
            return (self.__readPtr < self.__writePtr) and (idx <= self.__writePtr), self.__items[idx]
        end,
        Dequeue = function(self)
            local available, item = self:Peek()
            if not available then return end

            self.__readPtr = self.__readPtr + 1
            self.__items[self.__readPtr] = nil
            return item
        end,
        Count = function(self)
            return self.__writePtr - self.__readPtr
        end,
        Clear = function(self)
            table.Empty(self.__items)
            self.__readPtr  = 0
            self.__writePtr = 0
        end,
        Iterate = function(self)
            return QueueIterator, self, 0
        end
    },
    __call = function(class)
        local instance = {
            __items  = {},
            __readPtr  = 0,
            __writePtr = 0
        }
        return setmetatable(instance, getmetatable(class))
    end
})

local Module = { default = true }

function Module.Enable()
    if not net.WriteStream then return end
    if not net.ReadStream then return end

    -- Store the original netstream functions for Module.Disable
    Module.WriteStream_Over_NetChan = Module.WriteStream_Over_NetChan or net.WriteStream
    Module.ReadStream_Over_NetChan  = Module.ReadStream_Over_NetChan  or net.ReadStream

    -- Store the original receivers
    Module.RecvWriteStream_Over_NetChan = Module.RecvWriteStream_Over_NetChan or net.Receivers["NetStreamWrite"]
    Module.RecvReadStream_Over_NetChan  = Module.RecvReadStream_Over_NetChan  or net.Receivers["NetStreamRead"]

    -- A unique stream identifier
    Module.StreamIdx            = 0
    -- The write and read streams currently in the queue
    Module.EnqueuedWriteStreams = Queue()
    Module.EnqueuedReadStorage  = {}
    local EnqueuedWriteStreams  = Module.EnqueuedWriteStreams
    local EnqueuedReadStorage   = Module.EnqueuedReadStorage
    local DidWriteOneStream          = false

    -- First step: when net messages start, we need to clear any potential write streams being enqueued.
    -- Otherwise if something fails before the send functions, we'd have a bunch of junk/potentially unwanted/
    -- sensitive-to-specific-player data get networked.
    hook.Add("Express_PostNetStart", HOOKNAME, function(_, Unreliable)
        EnqueuedWriteStreams:Clear()
        DidWriteOneStream = false
    end)

    -- Second step; the ability to write Netstreams, without calling Express's methods yet - because we're still
    -- in a networking context, and sending via Express this early will end the net message.
    function net.WriteStream(Data, Callback, DontCompress)
        DidWriteOneStream = true
        assert(isstring(Data), string.format("bad argument #1 to 'WriteStream' (string expected, got %s)", type(Data)))
        if Callback ~= nil then assert(isfunction(Callback), string.format("bad argument #2 to 'WriteStream' (function expected, got %s)", type(Callback))) end

        local Compressed = not DontCompress
        if Compressed then Data = util.Compress(Data) end

        -- Data will be nil if util.Compress fails
        -- But otherwise it would always be a string (the first guard + util.Compress only returns string or nil)
        if Data == nil or #Data == 0 then
            net.WriteBool(false) -- Empty stream (ie. compression failure or just nothing provided)
        else
            net.WriteBool(true)  -- Non-empty stream

            -- Write a unique identifier for the stream over NetChan
            Module.StreamIdx = Module.StreamIdx + 1
            local StreamIdx = Module.StreamIdx
            net.WriteUInt(StreamIdx, 32)
            -- We have to enqueue the express call for after a send function, since
            -- express will do its own stuff + we don't know what to do with the message
            -- until then.
            EnqueuedWriteStreams:Enqueue {
                StreamIdx  = StreamIdx,
                Data       = Data,
                Compressed = Compressed,
                Callback   = Callback
            }
        end
    end

    -- Third step; intercepting every possible way for the net message to end, so we can write out our enqueued streams.
    local function FlushWriteStreams(Players)
        if not DidWriteOneStream then return end

        for _, WriteStream in EnqueuedWriteStreams:Iterate() do
            local Callback = WriteStream.Callback
            -- Modify the WriteStream directly, since it should not be used after this point, and it's not worth making a new table
            WriteStream.Callback = nil
            if CLIENT then
                express.Send(HOOKNAME, WriteStream, Callback)
            else
                if not Players then
                    express.Broadcast(HOOKNAME, WriteStream, Callback)
                else
                    express.Send(HOOKNAME, WriteStream, Players, Callback)
                end
                print("Sending stream to ", istable(Players) and nil or Players)
                if istable(Players) then PrintTable(Players) end
            end
        end
        EnqueuedWriteStreams:Clear()
    end

    if SERVER then
        hook.Add("Express_PostNetBroadcast", HOOKNAME, function()
            FlushWriteStreams()
        end)

        hook.Add("Express_PostNetSend", HOOKNAME, function(Target)
            if type(Target) == "CRecipientFilter" then
                Target = Target:GetPlayers()
            end

            FlushWriteStreams(Target)
        end)

        hook.Add("Express_PostNetSendOmit", HOOKNAME, function(Players)
            FlushWriteStreams(Players)
        end)

        hook.Add("Express_PostNetSendPAS", HOOKNAME, function(Position, Players)
            FlushWriteStreams(Players)
        end)

        hook.Add("Express_PostNetSendPVS", HOOKNAME, function(Position, Players)
            FlushWriteStreams(Players)
        end)
    else
        hook.Add("Express_PostNetSendToServer", HOOKNAME, function()
            FlushWriteStreams()
        end)
    end

    -- Fourth and final step; reading the streams from the read storage.
    -- Express may, or may not, have already given us the data by this point. So we check if we've gotten the data,
    -- provided the StreamIdx, and if we have, we immediately call the callback. Otherwise, we're placed in the waiting
    -- queue for when Express sends the data.

    local function TryCallback(Callback, Data)
        local OK, Err = xpcall(Callback, debug.traceback, Data.Compressed and util.Decompress(Data.Data) or Data.Data)
        if not OK then ErrorNoHalt(Err) end
    end

    local NO_DATA = {Data = "", Compressed = false}

    function net.ReadStream(Player, Callback)
        if CLIENT then
            Player = NULL
        else
            assert(type(Player) == "Player", string.format("bad argument #1 to 'ReadStream' (Player expected, got %s)", type(Player)))
            assert(Player:IsValid(), string.format("bad argument #1 to 'ReadStream' (Tried to use a NULL entity!)"))
        end

        local Contents  = net.ReadBool()
        if not Contents then
            TryCallback(Callback, NO_DATA)
            return
        end

        local StreamIdx = net.ReadUInt(32)

        local PotentiallyAvailableStream = EnqueuedReadStorage[StreamIdx]
        if PotentiallyAvailableStream ~= nil then -- A callback is available now!
            TryCallback(Callback, PotentiallyAvailableStream)
            EnqueuedReadStorage[StreamIdx] = nil
        else -- We need to wait... when Express gets the data, the callback will be called
            print("No callback available, waiting...")
            EnqueuedReadStorage[StreamIdx] = {
                Player = Player,
                Callback = Callback
            }
        end
    end

    if CLIENT then
        express.Receive(HOOKNAME, function(Data)
            local PotentiallyAvailableCallback = EnqueuedReadStorage[Data.StreamIdx]
            if PotentiallyAvailableCallback then
                print("Streamidx had callback, calling...")
                TryCallback(PotentiallyAvailableCallback.Callback, Data)
                EnqueuedReadStorage[Data.StreamIdx] = nil
            else
                EnqueuedReadStorage[Data.StreamIdx] = Data
                print("Enqueued streamidx, no callback available.")
            end
        end)
    else
        express.Receive(HOOKNAME, function(Player, Data)
            local PotentiallyAvailableCallback = EnqueuedReadStorage[Data.StreamIdx]
            if PotentiallyAvailableCallback then
                if not IsValid(PotentiallyAvailableCallback.Player) then print("Express bindings: potentially available callback had no valid player sender...") return end
                if PotentiallyAvailableCallback.Player ~= Player then print("Express bindings: potentially available callback had mismatching valid player sender...") return end

                TryCallback(PotentiallyAvailableCallback.Callback, Data)
                EnqueuedReadStorage[Data.StreamIdx] = nil
            else
                EnqueuedReadStorage[Data.StreamIdx] = Data
            end
        end)
    end

    -- Stub out the previous netstream receivers.
    net.Receive("NetStreamWrite", function() end)
    net.Receive("NetStreamRead", function() end)
end

function Module.Disable()
    -- Restore original netstream functions
    net.WriteStream = Module.WriteStream_Over_NetChan
    net.ReadStream  = Module.ReadStream_Over_NetChan
    -- Restore original netstream receivers
    if Module.RecvWriteStream_Over_NetChan then net.Receive("NetStreamWrite", Module.RecvWriteStream_Over_NetChan) end
    if Module.RecvReadStream_Over_NetChan  then net.Receive("NetStreamRead",  Module.RecvReadStream_Over_NetChan)  end
    -- Remove the networking hooks
    hook.Remove("Express_PostNetStart", HOOKNAME)
    if SERVER then
        hook.Remove("Express_PostNetBroadcast",    HOOKNAME)
        hook.Remove("Express_PostNetSend",         HOOKNAME)
        hook.Remove("Express_PostNetSendOmit",     HOOKNAME)
        hook.Remove("Express_PostNetSendPAS",      HOOKNAME)
        hook.Remove("Express_PostNetSendPVS",      HOOKNAME)
    else
        hook.Remove("Express_PostNetSendToServer", HOOKNAME)
    end
    -- Remove express receiver
    express.ClearReceiver(HOOKNAME)
end

function Module:IsValid()
    return true -- What should be here instead... will figure that out later
end

ExpressBindings.RegisterModule("netstream", Module)