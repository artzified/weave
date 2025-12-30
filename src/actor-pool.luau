local ActorPool = {}
local Static = {}

function Static.new(actorStorage: Instance?)
    return setmetatable({
        actors = {} :: {Actor},
        actorStorage = actorStorage or script,
        populateCallback = nil :: ((Actor) -> ())?,
    }, { __index = ActorPool })
end

function ActorPool.Populate(self: ActorPool, worker: Script & LocalScript, actorCount: number)
    for _ = 1, actorCount do
        local actor = Instance.new("Actor")
        local clone = worker:Clone()
        clone.Enabled = false
        clone.Parent = actor
        clone.Enabled = true
        actor.Parent = self.actorStorage

        if self.populateCallback then self.populateCallback(actor) end

        table.insert(self.actors, actor)
    end
end

function ActorPool.DispatchAll(self: ActorPool, message: string, ...)
    for _, actor in self.actors do
        actor:SendMessage(message, ...)
    end
end

function ActorPool.DispatchBatched(
    self: ActorPool,
    message: string,
    threadCount: number,
    batchSize: number,
    ...
)
    local actorCount = #self.actors
    local totalBatches = math.ceil(threadCount / batchSize)

    for i = 1, totalBatches do
        local actorIndex = ((i - 1) % actorCount) + 1
        local startIndex = (i - 1) * batchSize + 1
        
        local isLastForThisActor = i + actorCount > totalBatches

        self.actors[actorIndex]:SendMessage(
            message,
            startIndex,
            threadCount,
            batchSize,
            isLastForThisActor,
            ...
        )
    end
end

function ActorPool.SetPopulateCallback(self: ActorPool, callback: (Actor) -> ())
    self.populateCallback = callback
end

function ActorPool.Destroy(self: ActorPool)
    for _, actor in self.actors do
        actor:Destroy()
    end
    self.actors = {}
    self.populateCallback = nil
end

type ActorPool = typeof(Static.new(...))

return Static