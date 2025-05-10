local SharedTableRegistry = game:GetService("SharedTableRegistry")

local Static = {}
local Coordinator = {}

local InstructionId = 0

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
	}, { __index = Coordinator })
end

function Coordinator.CreateInstruction(self: Coordinator, name: string, localMemory: {any}?)
	if localMemory then
		self:SetInstructionLocalMemory(name, localMemory)
	end

	return {
		name = name,
		bindable = Instance.new("BindableEvent"),
	}
end

function Coordinator.SetInstructionLocalMemory(self: Coordinator, name: string, localMemory: { any })
	for _, actor in self.actors do
		actor:SendMessage(`{name}-localmemory`, localMemory)
	end
end

type Instruction = typeof(Coordinator.CreateInstruction(...))

@native
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
	local data = SharedTable.new(table.create(size, 0))

	local currentInstId = InstructionId
	local stId = `clrs-{currentInstId}`
	SharedTableRegistry:SetSharedTable(stId, data)

	local count = 0
	local connection
	connection = instruction.bindable.Event:Connect(function()
		count += 1

		if count == threadCount // _batchSize then
			connection:Disconnect()
			SharedTableRegistry:SetSharedTable(stId, nil)

			print(data)

			debug.profilebegin('flatten data')

			local flat = table.create(threadCount)
			for batchId, batch in data do
				for lThreadId, thread in batch do
					table.insert(flat, thread)
				end
			end

			debug.profileend()

			if callback then
				callback(flat)
			end
		end
	end)

	debug.profilebegin('dispatch actors')
	local actorIndex = 1
	for i = 1, threadCount, _batchSize do
		self.actors[actorIndex]:SendMessage(
			instruction.name,
			currentInstId,
			i,
			threadCount,
			_batchSize,
			instruction.bindable,
			...
		)
		actorIndex = (actorIndex % #self.actors) + 1
	end
	debug.profileend()
end

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

type Coordinator = typeof(Static.new(...))

return Static
