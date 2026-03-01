--!native
--!optimize 2
--!nonstrict
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

function ActorPool.Populate(self: ActorPool, worker: Script | LocalScript, actorCount: number)
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

function ActorPool.WaitForReplication(self: self)
	for _, actor in self.actors do
		if not actor:GetAttribute(constants.readyAttribute) then
			actor:GetAttributeChangedSignal(constants.readyAttribute):Wait()
		end
	end
end

function ActorPool.DispatchAll(self: self, message: string, ...)
	for _, actor in self.actors do
		actor:SendMessage(message, ...)
	end
end

function ActorPool.DispatchBatched(self: self, message: string, threadCount: number, batchSize: number, ...)
	local totalBatches = math.ceil(threadCount / batchSize)
	local actorCount = #self.actors
	if totalBatches == 0 or actorCount == 0 then
		return 0
	end

	local actors = self.actors
	local tb = totalBatches
	local ac = actorCount
	local bs = batchSize

	local base = math.floor(tb / ac)
	local rem = tb - base * ac

	local usedActors = 0
	local batchCursor = 1

	for actorIndex = 1, ac do
		local myBatches = base + (actorIndex <= rem and 1 or 0)
		if myBatches > 0 then
			usedActors += 1
			local startIndex = (batchCursor - 1) * bs + 1

			-- number of items  this actor should process, cap at threadCount to be safe
			local items = myBatches * bs
			local remaining = threadCount - startIndex + 1
			if items > remaining then
				items = remaining
			end

			local actor = actors[actorIndex]
			-- send ONE message for the whole contiguous range; mark isLast=true so actor flushes
			actor:SendMessage(message, startIndex, threadCount, items, true, ...)
			batchCursor += myBatches
			if batchCursor > tb then
				break
			end
		end
	end

	return usedActors
end

function ActorPool.Destroy(self: self)
	for _, actor in self.actors do
		actor:Destroy()
	end
	table.clear(self.actors)
end

type self = typeof(Static.new(...))

return Static
