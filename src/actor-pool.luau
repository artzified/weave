--!native
--!optimize 2
local constants = require("./constants")
local ActorPool = {}
local Static = {}

function Static.new(actorStorage: Instance?)
	return setmetatable({
		actors = {} :: {Actor},
		count = 0,
		actorStorage = actorStorage or script,
	}, { __index = ActorPool })
end

function ActorPool.Populate(self: self, worker: Script | LocalScript, actorCount: number)
	for _ = 1, actorCount do
		local actor = Instance.new("Actor")
		local clone = worker:Clone()
		clone.Enabled = false
		clone.Parent = actor
		clone.Enabled = true
		actor.Parent = self.actorStorage

		table.insert(self.actors, actor)
	end

	self.count = actorCount
end

function ActorPool.DispatchAll(self: self, message: string, ...)
	for _, actor in self.actors do
		actor:SendMessage(message, ...)
	end
end

function ActorPool.DispatchBatched(self: self, message: string, threadCount: number, batchSize: number, ...)
	local actorCount = #self.actors
	local actorIndex = 1

	for startIndex = 1, threadCount, batchSize do
		local isLastForThisActor = (startIndex + (actorCount * batchSize)) > threadCount

		self.actors[actorIndex]:SendMessage(message, startIndex, threadCount, batchSize, isLastForThisActor, ...)
		actorIndex = (actorIndex % actorCount) + 1
	end
end

function ActorPool.WaitForReplication(self: self)
	for _, actor in self.actors do
		if not actor:GetAttribute(constants.readyAttribute) then
			actor:GetAttributeChangedSignal(constants.readyAttribute):Wait()
		end
	end
end

function ActorPool.Destroy(self: self)
	for _, actor in self.actors do
		actor:Destroy()
	end
	table.clear(self.actors)
end

type self = typeof(Static.new(...))

return Static
