--!native
--!optimize 2
local actor_pool = require("./actor-pool")
local constants = require("./constants")
local utils = require("./utils")

--[=[
	@class Bridge
	@private

	The intermediary between the serial [Dispatcher] and the
	parallel [Kernel].

	It is responsible for:
	- Dispatching jobs to actors
	- Tracking job completion
	- Collecting and merging results
	- Invoking completion callbacks
]=]
local Static = {}
local Bridge = {}

local b, e = utils.profiling()

--[=[
	@function new
	@within Bridge
	@param actorCount number -- Number of worker actors
	@param workerScript Script | LocalScript -- Worker entry script
	@return Bridge

	Creates a new Bridge.

	This creates an [ActorPool], spawns workers, and establishes
	the [BindableEvent] internal messaging channel used to receive job results.
]=]
function Static.new(actorCount: number, workerScript: Script | LocalScript)
	local self = setmetatable({
		_pool = actor_pool.new(),
		_messenger = Instance.new("BindableEvent"),
		_registry = {} :: { { callback: () -> (), buf: { any }, received: number, expected: number } },
		_ptr = 0,
	}, { __index = Bridge })

	self._pool:Populate(workerScript, actorCount)
	self._pool:WaitForReplication()

	self._pool:DispatchAll(constants.messengerBindableSignal, self._messenger)

	self._messenger.Event:Connect(
		function(reqId: number, responses: { any }, startIndex: number, totalItems: number)
			local req = self._registry[reqId]
			if not req then
				return
			end

			assert(req.received <= req.expected)

			b('put responses to buffer')

			table.move(responses, 1, totalItems, startIndex, req.buf)

			e()

			req.received += 1
			if req.received == req.expected then
				self._registry[reqId] = nil
				req.callback()
			end
		end
	)

	return self
end

--[=[
	@method Send
	@within Bridge
	@param name string -- Job name
	@param threadCount number -- Total logical work items
	@param batchSize number -- Items per batch
	@param buf { any } -- Output buffer
	@param callback function -- Invoked once all batches complete
	@param ... any -- Extra arguments forwarded to workers
	@error "reqId collision" -- Too much jobs registered

	Dispatches a **tracked job** to the [ActorPool].

	The job:
	- Is split into batches
	- Executed in parallel
	- Sends results back to the bridge
	- Invokes the callback once all batches complete

	This is the tracked dispatch used by
	`Dispatcher:Dispatch` and `Dispatcher:DispatchDeferred`.
]=]
function Bridge.Send(
	self: self,
	name: string,
	threadCount: number,
	batchSize: number,
	buf: { any },
	callback: () -> (),
	...
)
	self._ptr = (self._ptr + 1) % 0xFFFFF

	local reqId = self._ptr
	assert(not self._registry[reqId], "reqId collision")

	local totalBatches = math.ceil(threadCount / batchSize)
	local usedActors = self._pool:DispatchBatched(name, threadCount, batchSize, reqId, ...)

	local expectedSignals = math.min(usedActors, totalBatches)

	self._registry[reqId] = { callback = callback, buf = buf, received = 0, expected = expectedSignals }
end

--[=[
	@method SendDetached
	@within Bridge
	@param name string -- Job name
	@param threadCount number -- Total logical work items
	@param batchSize number -- Items per batch
	@param ... any -- Extra arguments forwarded to workers

	Dispatches a **detached job** to the [ActorPool].

	The job:
	- Is split into batches
	- Executed in parallel

	This is the detached dispatch used by
	`Dispatcher:DispatchDetached` and `Dispatcher:DispatchDetachedDeferred`.
]=]
function Bridge.SendDetached(self: self, name: string, threadCount: number, batchSize: number, ...)
	self._pool:DispatchBatchedDetached(name, threadCount, batchSize, ...)
end

--[=[
	@method Destroy
	@within Bridge

	Destroys the messenger bindable, the [ActorPool], and clears the registry
]=]
function Bridge.Destroy(self: self)
	self._messenger:Destroy()
	self._pool:Destroy()
	table.clear(self._registry)
end

type self = typeof(Static.new(...))

return Static
