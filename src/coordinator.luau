--!native
--!optimize 2
local actor_pool = require("./actor-pool")
local instruction = require("./instruction")
local utils = require("./utils")

local b, e = utils.profiling()

local Static = {}
local Coordinator = {}

local instructionId = 0

export type Instruction = instruction.Instruction

function Static.new(worker: Script & LocalScript, actorCount: number, actorStorage: Instance?, populateCallback: ((Actor) -> ())?)
	local pool = actor_pool.new(actorStorage)

	pool:Populate(worker, actorCount)

	return setmetatable({
		pool = pool,
		registeredInstructions = {},
	}, { __index = Coordinator })
end

--[[ 
	Creates a new instruction object. An instruction may have the same name under different coordinators without collisions, but not under the same coordinator
]]
function Coordinator.CreateInstruction(self: Coordinator, name: string)
	local existingInstruction = self.registeredInstructions[name]
	if existingInstruction then
		warn(`Instruction "{name}" already exists under this coordinator`)
		return existingInstruction
	end

	local instruction = instruction.new(self :: never, name)
	self.registeredInstructions[name] = instruction

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
	instructionId += 1
	local _batchSize = batchSize or math.max(threadCount // #self.pool.actors, 1)

	local size = (threadCount + _batchSize - 1) // _batchSize
	local data = table.create(size)

	local count = 0
	local connection
	connection = instruction.bindable.Event:Connect(function(startIndex: number, responses: { { any } })
		count += 1

		data[(startIndex - 1) // _batchSize + 1] = responses -- flatten spaced out index

		if count == #self.pool.actors then
			connection:Disconnect()

			b("flatten data")

			-- relatively isn't really a problem
			local flat = table.create(threadCount)
			for batchId, batch in data do
				local offset = (batchId - 1) * _batchSize
				table.move(batch, 1, #batch, offset + 1, flat)
			end

			e()

			if callback then
				callback(flat)
			end
		end
	end)

	self.pool:DispatchBatched(instruction.name, threadCount, _batchSize, ...)
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
