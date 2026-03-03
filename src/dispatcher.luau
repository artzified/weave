local bridge = require("./bridge")

--[=[
	@class Dispatcher

	The public interface used to execute parallel jobs.

	It provides multiple dispatch modes:
	- **Tracked**: collect results and invoke a callback
	- **Detached**: fire-and-forget execution with no results

	And these dispatch modes may be immediate or deferred.

	The Dispatcher itself is serial; parallelism is handled 
	by the [Kernel]
]=]
local Static = {}
local Dispatcher = {}

--[=[
	@function new
	@within Dispatcher
	@param actorCount number -- Number of worker actors
	@param workerScript Script | LocalScript -- Worker entry script
	@return Dispatcher

	Creates a new Dispatcher.

	This spawns a pool of worker actors using the provided worker script
	and initializes the internal bridge.
]=]
function Static.new(actorCount: number, workerScript: LocalScript | Script)
	return setmetatable({ _bridge = bridge.new(actorCount, workerScript) }, { __index = Dispatcher })
end

--[=[
	@method Dispatch
	@within Dispatcher
	@param name string -- Job name
	@param threadCount number -- Total logical work items
	@param callback function -- `(buf: { any }) -> ()`
	@param batchSize number? -- Optional batch size override
	@param ... any -- Extra arguments forwarded to workers

	Dispatches a **tracked job**.

	The job:
	- Is split into batches
	- Executed in parallel
	- Returns results into a contiguous table buffer
	- Invokes the callback once all work completes

	This is the standard for intensive computation jobs with no side-effects.
]=]
function Dispatcher.Dispatch(self: self, name: string, threadCount: number, callback: (buf: {any}) -> (), _batchSize: number?, ...)
	local batchSize = _batchSize or math.ceil(threadCount / self._bridge._pool.count)
	local buf = table.create(threadCount) -- might have to pool buffers to avoid table allocation

	self._bridge:Send(name, threadCount, batchSize, buf, function()
		callback(buf)
	end)
end

--[=[
	@method DispatchDeferred
	@within Dispatcher
	@param name string -- Job name
	@param threadCount number -- Total logical work items
	@param callback function -- `(buf: { any }) -> ()`
	@param batchSize number? -- Optional batch size override
	@param ... any -- Extra arguments forwarded to workers

	Deferred proxy to [Dispatcher:Dispatch]
]=]
function Dispatcher.DispatchDeferred(
	self: self,
	name: string,
	threadCount: number,
	callback: (buf: { any }) -> (),
	_batchSize: number?,
	...
)
	task.defer(self.Dispatch, self, name, threadCount, callback, _batchSize, ...)
end

--[=[
	@method DispatchDetached
	@within Dispatcher
	@param name string -- Job name
	@param threadCount number -- Total logical work items
	@param _batchSize number? -- Optional batch size override
	@param ... any

	Dispatches a **detached job**.

	The job:
	- Is split into batches
	- Executed in parallel
	
	This is the lowest-overhead mode and is suitable for pure side-effect jobs 
	such as raycasts, writes, or simulation steps.
]=]
function Dispatcher.DispatchDetached(
	self: self, 
	name: string, 
	threadCount: number, 
	_batchSize: number?, 
	...
)
	local batchSize = _batchSize or math.ceil(threadCount / self._bridge._pool.count)
	self._bridge:SendDetached(name, threadCount, batchSize, ...)
end

--[=[
	@method DispatchDetachedDeferred
	@within Dispatcher
	@param name string -- Job name
	@param threadCount number -- Total logical work items
	@param _batchSize number? -- Optional batch size override
	@param ... any

	Deferred proxy to [Dispatcher:DispatchDetached]
]=]
function Dispatcher.DispatchDetachedDeferred(
	self: self,
	name: string,
	threadCount: number,
	_batchSize: number?,
	...
)
	task.defer(self.DispatchDetached, self, name, threadCount, _batchSize, ...)
end

--[=[
	@method Destroy
	@within Dispatcher
	
]=]
function Dispatcher.Destroy(self: self)
	self._bridge:Destroy()
end

export type self = typeof(Static.new(...))

return Static
