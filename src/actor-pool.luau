--!native
--!optimize 2
--!nonstrict
local constants = require("./constants")

--[=[
	@class ActorPool
	@private

	Manages a collection of worker Actors and is responsible
	for distributing work across them.

	It handles:
	- Actor creation and lifecycle
	- Worker script cloning and startup
	- Batch-to-actor assignment
	- Message dispatch (tracked and detached)

	ActorPool does **not** collect results or track completion; it is a
	low-level scheduling and dispatch component used by [Bridge].
]=]
local Static = {}
local ActorPool = {}

function Static.new(actorStorage: Instance?)
	return setmetatable({
		actors = {} :: {Actor},
		count = 0,
		actorStorage = actorStorage or script,
	}, { __index = ActorPool })
end

--[=[
	@method Populate
	@within ActorPool
	@param worker Script | LocalScript
	@param actorCount number

	Populates the pool with worker Actors

	Each actor:
	- Is created
	- Receives a cloned worker script
	- Starts the worker script immediately
]=]
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

--[=[
	@method WaitForReplication
	@within ActorPool
	@yields
	
	Waits until all workers report readiness.

	This blocks until each Actor sets the ready attribute, which is
	typically done by calling `Kernel:Ready()` inside the worker.

	This is used to ensure workers are fully initialized before
	dispatching jobs.
]=]
function ActorPool.WaitForReplication(self: self)
	for _, actor in self.actors do
		if not actor:GetAttribute(constants.readyAttribute) then
			actor:GetAttributeChangedSignal(constants.readyAttribute):Wait()
		end
	end
end

--[=[
	@method DispatchAll
	@within ActorPool
	@param message string -- Message name
	@param ... any -- Arguments forwarded to all actors

	Sends a message to all actors.

	This is used for setup or control signals rather than
	work distribution.

]=]
function ActorPool.DispatchAll(self: self, message: string, ...)
	for _, actor in self.actors do
		actor:SendMessage(message, ...)
	end
end

--[=[
	@method DispatchBatched
	@within ActorPool
	@param message string -- Job name
	@param threadCount number -- Total logical work items
	@param batchSize number -- Items per batch
	@param ... any -- Extra arguments forwarded to workers
	@return number -- Number of actors used

	Dispatches a **tracked job** in batches across actors.

	Work is divided into contiguous ranges and assigned to actors.
	Each actor receives at most one message containing a contiguous
	segment of work and is responsible for flushing results.

	Returns the number of actors that were assigned work.
]=]
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

--[=[
	@method DispatchBatchedDetached
	@within ActorPool
	@param message string
	@param threadCount number -- Total logical work items
	@param batchSize number -- Items per batch
	@param ... any -- Extra arguments forwarded to workers

	Pretty much the same as [ActorPool:DispatchBatched] but doesn't return anything
]=]
function ActorPool.DispatchBatchedDetached(self: self, message: string, threadCount: number, batchSize: number, ...)
	local totalBatches = math.ceil(threadCount / batchSize)
	local actorCount = #self.actors
	if totalBatches == 0 or actorCount == 0 then
		return
	end

	local actors = self.actors
	local base = math.floor(totalBatches / actorCount)
	local rem = totalBatches - base * actorCount
	local batchCursor = 1

	for actorIndex = 1, actorCount do
		local myBatches = base + (actorIndex <= rem and 1 or 0)
		if myBatches > 0 then
			local startIndex = (batchCursor - 1) * batchSize + 1
			local items = math.min(myBatches * batchSize, threadCount - startIndex + 1)

			actors[actorIndex]:SendMessage(message, startIndex, threadCount, items, ...)
			batchCursor += myBatches
			if batchCursor > totalBatches then
				break
			end
		end
	end
end

--[=[
	@method Destroy
	@within ActorPool

	Destroys all actors
]=]
function ActorPool.Destroy(self: self)
	for _, actor in self.actors do
		actor:Destroy()
	end
	table.clear(self.actors)
end

type self = typeof(Static.new(...))

return Static
