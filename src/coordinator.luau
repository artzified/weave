--!native
--!optimize 2
local actor_pool = require("./actor-pool")
local utils = require("./utils")

local b, e = utils.profiling()

local HANDSHAKE_MAX_TRIES = 10
local HANDSHAKE_INTERVAL = 0.1
local HANDSHAKE_TIMEOUT = 1

local Static = {}
local Coordinator = {}

type Instruction = {
	name: string,
	bindable: BindableEvent,
}

function Static.new(
	worker: Script & LocalScript,
	actorCount: number,
	actorStorage: Instance?,
	populateCallback: ((Actor) -> ())?
)
	local pool = actor_pool.new(actorStorage)

	pool:Populate(worker, actorCount)

	local self = setmetatable({
		pool = pool,
		registeredInstructions = {},
		handshakeBindable = Instance.new("BindableEvent"),
	}, { __index = Coordinator });

	(self :: Coordinator):DoHandshake("$actor-handshake")

	return self
end

function Coordinator.DoHandshake(self: Coordinator, message: string, ...)
	local readyCount = 0
	local conn
	conn = self.handshakeBindable.Event:Connect(function()
		readyCount += 1
		if readyCount == self.pool.count then
			conn:Disconnect()
		end
	end)

	for _ = 1, HANDSHAKE_MAX_TRIES do
		if readyCount == self.pool.count then
			return
		end
		self.pool:DispatchAll(message, self.handshakeBindable, ...)
		print("dispatched")
		task.wait(HANDSHAKE_INTERVAL)
	end

	local start = os.clock()
	while readyCount < self.pool.count and (os.clock() - start) < HANDSHAKE_TIMEOUT do
		task.wait()
	end

	if readyCount < self.pool.count then
		error(`[Celeris::Coordinator] Handshake '{message}' timeout`)
	end
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
	self.registeredInstructions[name] = instruction
	self:DoHandshake(`{name}-handshake`, instruction.bindable)

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
	local _batchSize = batchSize or math.max(threadCount // self.pool.count, 1)
	local totalBatches = math.ceil(threadCount / _batchSize)

	local data = table.create(threadCount)
	local expectedSignals = math.min(self.pool.count, totalBatches)
	local count = 0

	local connection
	connection = instruction.bindable.Event:Connect(function(responses: { any }, startIndices: { number })
		count += 1

		b("move responses")
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

	b("dispatch")
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
