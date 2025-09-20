--!native
--!optimize 2
local Instruction = require(script.Parent.instruction)
local Utils = require(script.Parent.utils)

local b, e = Utils.profiling()

local Static = {}
local Coordinator = {}

local InstructionId = 0

export type Instruction = Instruction.Instruction

function Static.new(worker: Script & LocalScript, actorCount: number, actorStorage: Instance?)
	local actors = {}

	for _ = 1, actorCount do
		local actor = Instance.new("Actor")
		local clone = worker:Clone()
		clone.Enabled = false
		clone.Parent = actor
		clone.Enabled = true
		actor.Parent = actorStorage or script

		table.insert(actors, actor)
	end

	return setmetatable({
		actors = actors,
		registeredInstructions = {}
	}, { __index = Coordinator })
end

--[[
	Creates a new instruction object. An instruction may have the same name under different coordinators without collisions, but not under the same coordinator
]]
function Coordinator.CreateInstruction(self: Coordinator, name: string, localMemory: {any}?)
	local existingInstruction = self.registeredInstructions[name]
	if existingInstruction then
		warn(`Instruction "{name}" already exists under this coordinator`)
		return existingInstruction
	end
	
	local instruction = Instruction.new(self :: never, name, localMemory)

	self.registeredInstructions[name] = instruction

	return instruction
end

--[[
	Immediately asynchronously dispatches the instruction to the actors, may cause **frame drops** if used heavily
]]
function Coordinator.DispatchImmediate(
	self: Coordinator,
	instruction: Instruction,
	threadCount: number,
	callback: ((data: {any}) -> ...any)?,
	batchSize: number?,
	...
)
	InstructionId += 1
	local _batchSize = batchSize or math.max(threadCount // #self.actors, 1)

	local size = threadCount // _batchSize
	local data = table.create(size)

	local count = 0
	local connection
	connection = instruction.bindable.Event:Connect(function(index: number, responses: {{any}})
		count += 1

		data[(index-1) // _batchSize + 1] = responses

		if count == size then
			connection:Disconnect()

			b('flatten data')

			local flat = table.create(threadCount)
			for batchId, batch in data do
				for lThreadId, thread in batch do
					table.insert(flat, thread)
				end
			end

			e()

			if callback then
				callback(flat)
			end
		end
	end)

	b('dispatch actors')
	local actorIndex = 1
	for i = 1, threadCount, _batchSize do
		self.actors[actorIndex]:SendMessage(
			instruction.name,
			i,
			threadCount,
			_batchSize,
			...
		)
		actorIndex = (actorIndex % #self.actors) + 1
	end
	e()
end

--[[
	A deferred proxy to `:DispatchImmediate`. Recommended for intensive rapid tasks to avoid frame drops
]]
function Coordinator.DispatchDeferred(
	self: Coordinator,
	instruction: Instruction,
	threadCount: number,
	callback: ((data: {any}) -> ...any)?,
	batchSize: number?,
	...
)
	task.defer(self.DispatchImmediate, self, instruction, threadCount, callback, batchSize, ...)
end

--[[
	**(ONLY)** Disposes all the actors for cleanup purposes. Each actor will be sent a **`$onDestroy`** message, subsequently deferring the destroying of the actor
]]
function Coordinator.Dispose(
	self: Coordinator
)
	for _, actor in self.actors do
		actor:SendMessage('$onDestroy')
		task.defer(actor.Destroy, actor)
	end
end

--[[
	Disposes all the actors and destroys the coordinator. Proxied to use `:Dispose`
]]
function Coordinator.Destroy(	
	self: Coordinator
)
	self:Dispose()

	table.clear(self :: never) 	-- type checker wont shut up
end

export type Coordinator = typeof(Static.new(...))

return Static
