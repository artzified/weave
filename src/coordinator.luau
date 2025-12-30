--!native
--!optimize 2
local actor_pool = require("./actor-pool")
local utils = require("./utils")

local b, e = utils.profiling()

local Static = {}
local Coordinator = {}

function Static.new(worker: Script & LocalScript, actorCount: number, actorStorage: Instance?, populateCallback: ((Actor) -> ())?)
	local pool = actor_pool.new(actorStorage)

	pool:Populate(worker, actorCount)

	return setmetatable({
		pool = pool,
		registeredInstructions = {},
	}, { __index = Coordinator })
end

--[[
	Immediately asynchronously dispatches the instruction to the actors
]]
function Coordinator.DispatchImmediate(
	self: Coordinator,
	name: string,
	threadCount: number,
	callback: ((data: { any }) -> ...any)?,
	batchSize: number?,
	...
)
	local bindable = Instance.new("BindableEvent")
	local _batchSize = batchSize or math.max(threadCount // #self.pool.actors, 1)

	local size = (threadCount + _batchSize - 1) // _batchSize
	local data = table.create(size)

	local count = 0
	local connection
	connection = bindable.Event:Connect(function(startIndex: number, responses: { { any } })
		count += 1

		data[(startIndex - 1) // _batchSize + 1] = responses -- flatten spaced out index

		if count == #self.pool.actors then
			connection:Disconnect()
			bindable:Destroy()

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

	self.pool:DispatchBatched(name, threadCount, _batchSize, ...)
end

--[[
	A deferred proxy to `:DispatchImmediate`. Recommended for intensive rapid tasks to avoid frame drops
]]
function Coordinator.DispatchDeferred(
	self: Coordinator,
	name: string,
	threadCount: number,
	callback: ((data: { any }) -> ...any)?,
	batchSize: number?,
	...
)
	task.defer(self.DispatchImmediate, self, name, threadCount, callback, batchSize, ...)
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
