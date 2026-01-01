local types = require("./types")
local utils = require("./utils")
local Static = {}
local Job = {}

type self = types.Job

local b, e = utils.profiling()

function Static.new(name: string, pool: types.ActorPool)
	local self = setmetatable(
		{ name = name, bindable = Instance.new("BindableEvent"), batchSize = 0, pool = pool },
		{ __index = Job }
	) :: self

	self.pool:DoHandshake(name, self.bindable)

	return self
end

function Job.SetReadonlyData(self: self, key: string | number, value: any)
	self.pool:DoHandshake(`$readonly-{self.name}`, key, value)
	return self
end

function Job.Dispatch(self: self, threadCount: number, callback: ((data: { any }) -> ())?, ...)
	local batchSize = self.batchSize or math.max(threadCount // self.pool.count, 1)
	local totalBatches = math.ceil(threadCount / batchSize)

	local data = table.create(threadCount)
	local expectedSignals = math.min(self.pool.count, totalBatches)
	local count = 0

	local conn: RBXScriptConnection
	conn = self.bindable.Event:Connect(function(responses: { any }, startIndices: { number })
		count += 1

		b("move responses")
		for i, startIndex in startIndices do
			local sourceStart = (i - 1) * batchSize + 1
			local stride = math.min(batchSize, #responses - (sourceStart - 1))

			table.move(responses, sourceStart, sourceStart + stride - 1, startIndex, data)
		end
		e()

		if count == expectedSignals then
			conn:Disconnect()
			if callback then
				callback(data)
			end
		end
	end)

	b("dispatch")
	self.pool:DispatchBatched(self.name, threadCount, batchSize, ...)
	e()
end

function Job.DispatchDeferred(self: self, threadCount: number, callback: ((data: { any }) -> ())?, ...)
	task.defer(self.Dispatch, self, threadCount, callback, ...)
end

function Job.Linear(self: self)
	self.batchSize = nil
	return self
end

function Job.Batched(self: self, batchSize: number)
	self.batchSize = batchSize
	return self
end

return Static
