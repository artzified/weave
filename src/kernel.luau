--!native
--!optimize 2
local constants = require("./constants")
local utils = require("./utils")

--[=[
	@class Kernel

	The parallel worker interface used to execute jobs.

	It allows registering parallel job handlers that are dispatched
	from a [Dispatcher]. Jobs can either be:
	
	- **Tracked**: send and synchronize data back to the dispatcher
	- **Detached**: fire-and-forget dispatch with no synchronization and no data sent back to the dispatcher

	Each kernel instance should be bound to exactly one actor.
]=]
local Static = {}
local Kernel = {}

local b, e = utils.profiling()

--[=[
	@function new
	@within Kernel
	@param actor Actor
	@return Kernel
	@tag Parallel
	
	Creates a new Kernel bound to an Actor
]=]
function Static.new(actor: Actor)
	local self = setmetatable({
		actor = actor,
		_resBuf = table.create(2048),
		_messenger = nil :: BindableEvent?,
	}, { __index = Kernel })
	
	actor:BindToMessage(constants.messengerBindableSignal, function(bindable: BindableEvent)
		self._messenger = bindable
	end)
	
	return self
end

--[=[
	@method On
	@within Kernel
	@param name string -- Job name
	@param process (id: number, ...any) -> any
	@tag Parallel

	Registers a **tracked parallel job**

	The job will:
	- Execute in parallel across actors
	- Return results to the dispatcher
	- Be synchronized and ordered into the output

	This is the standard for computation jobs with no side-effects.
]=]
function Kernel.On(self: self, name: string, process: (id: number, ...any) -> any)
	local resBuf = self._resBuf
	local resPtr = 1
	local firstStartIndex = 0

	self.actor:BindToMessageParallel(
		name,
		function(startIndex: number, threadCount: number, batchSize: number, isLast: boolean, reqId: number, ...)
			assert(self._messenger, "Haven't gotten messenger bindable yet!")

			if resPtr == 1 then
				firstStartIndex = startIndex
			end

			local lastIndex = math.min(startIndex + (batchSize - 1), threadCount)

			for i = startIndex, lastIndex do
				resBuf[resPtr] = process(i, ...)
				task.desynchronize()
				resPtr += 1
			end

			if isLast then -- flush
				b("flush")

				self._messenger:Fire(reqId, resBuf, firstStartIndex, resPtr - 1)

				resPtr = 1

				e()
			end
		end
	)
end

--[=[
	@method OnDetached
	@within Kernel
	@param name string -- Job name
	@param process (id: number, ...any) -> any
	@tag Parallel

	Registers a **detached parallel job**

	Detached jobs:
	- Do not send any data back to the dispatcher
	- Do not synchronize or flush
	- Do not allocate tables
	- Are fire-and-forget

	This is the lowest-overhead execution mode and is suitable for 
	pure side-effect jobs such as raycasts, writes, or simulation steps.
]=]
function Kernel.OnDetached(self: self, name: string, process: (id: number, ...any) -> ())
	self.actor:BindToMessageParallel(
		name,
		function(startIndex: number, threadCount: number, batchSize: number, ...)
			local lastIndex = math.min(startIndex + (batchSize - 1), threadCount)
						
			for i = startIndex, lastIndex do
				process(i, ...)
				task.desynchronize()
			end
		end
	)
end

--[=[
	@method Ready
	@within Kernel

	Marks this kernel as ready

	This sets the internal ready attribute used by the dispatcher
	to determine whether the actor is ready to receive jobs.
]=]
function Kernel.Ready(self: self)
	self.actor:SetAttribute(constants.readyAttribute, true)
end

export type self = typeof(Static.new(...))

return Static
