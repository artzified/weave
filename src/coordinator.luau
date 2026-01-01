--!native
--!optimize 2
local actor_pool = require("./actor-pool")
local utils = require("./utils")

local b, e = utils.profiling()

local Static = {}
local Coordinator = {}

type Instruction = {
	name: string,
	bindable: BindableEvent,
}

function Static.new(worker: Script & LocalScript, actorCount: number, actorStorage: Instance?, populateCallback: ((Actor) -> ())?)
	local pool = actor_pool.new(actorStorage)

	pool:Populate(worker, actorCount)

	return setmetatable({
		pool = pool,
		registeredInstructions = {},
	}, { __index = Coordinator })
end

--[[ 
	Creates a new instruction object, yields until all actors have acknowledged it
]]
function Coordinator.DefineInstruction(self: Coordinator, name: string): Instruction
	local existingInstruction = self.registeredInstructions[name]
	if existingInstruction then
		warn(`Instruction "{name}" already exists under this coordinator`)
		return existingInstruction
	end

	local instruction = {
		name = name,
		bindable = Instance.new("BindableEvent"),
	}

	local readyCount = 0
	local conn;
	conn = instruction.bindable.Event:Connect(function()
		readyCount += 1
		if readyCount == #self.pool.actors then
			conn:Disconnect()
		end
	end)

	self.pool:DispatchAll(`{name}-handshake`, instruction.bindable)
	self.registeredInstructions[name] = instruction

	repeat
		task.wait()
	until readyCount == #self.pool.actors

	return instruction
end

--[[
	Immediately asynchronously dispatches the instruction to the actors
]]
function Coordinator.DispatchImmediate(
	self: Coordinator,
	instruction: Instruction,
	threadCount: number,
	callback: ((data: { any }) -> ...any)?,
	batchSize: number?,
	...
)
	local _batchSize = batchSize or math.max(threadCount // #self.pool.actors, 1)
	local totalBatches = math.ceil(threadCount / _batchSize)

	local data = table.create(threadCount)
	local expectedSignals = math.min(#self.pool.actors, totalBatches)
	local count = 0

	local connection
	connection = instruction.bindable.Event:Connect(function(responses: { any }, startIndices: { number })
		count += 1

		b('move responses')
		for i, startIndex in startIndices do
			local sourceStart = (i - 1) * _batchSize + 1
			local stride = math.min(_batchSize, #responses - (sourceStart - 1))

			table.move(responses, sourceStart, sourceStart + stride - 1, startIndex, data)
		end
		e()

		if count == expectedSignals then
			connection:Disconnect()
			if callback then
				callback(data)
			end
		end
	end)

	b('dispatch')
	self.pool:DispatchBatched(instruction.name, threadCount, _batchSize, ...)
	e()
end

--[[
	A deferred proxy to `:DispatchImmediate`. Recommended for intensive rapid tasks to avoid frame drops
]]
function Coordinator.DispatchDeferred(
	self: Coordinator,
	instruction: Instruction,
	threadCount: number,
	callback: ((data: { any }) -> ...any)?,
	batchSize: number?,
	...
)
	task.defer(self.DispatchImmediate, self, instruction, threadCount, callback, batchSize, ...)
end

--[[
	Destroys the actor pool and subsequently the coordinator.
]]
function Coordinator.Destroy(self: Coordinator)
	self.pool:Destroy()

	table.clear(self :: never) -- type checker wont shut up
end

export type Coordinator = typeof(Static.new(...))

return Static
