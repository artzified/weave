--!native
--!optimize 2
local actor_pool = require("./actor-pool")
local utils = require("./utils")

local Static = {}
local Bridge = {}

local b, e = utils.profiling()

function Static.new(actorCount: number, workerScript: Script | LocalScript)
	local self = setmetatable({
		_pool = actor_pool.new(),
		_messenger = Instance.new("BindableEvent"),
		_registry = {} :: { { callback: () -> (), buf: { any }, received: number, expected: number } },
		_ptr = 0,
	}, { __index = Bridge })

	self._pool:Populate(workerScript, actorCount)
	self._pool:WaitForReplication()

	self._pool:DispatchAll("$bridge-messenger", self._messenger)

	self._messenger.Event:Connect(
		function(reqId: number, responses: { any }, startIndices: { number }, batchSize: number)
			local req = self._registry[reqId]
			if not req then
				return
			end

			b('put responses to buffer')

			for i, startIndex in startIndices do
				local sourceStart = (i - 1) * batchSize + 1
				local stride = math.min(batchSize, #responses - (sourceStart - 1))
				table.move(responses, sourceStart, sourceStart + stride - 1, startIndex, req.buf)
			end

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

function Bridge.Send(
	self: self,
	name: string,
	threadCount: number,
	batchSize: number,
	buf: { any },
	callback: () -> (),
	...
)
	self._ptr = (self._ptr + 1) % 0xFFFF

	local reqId = self._ptr
	local totalBatches = math.ceil(threadCount / batchSize)
	local expectedSignals = math.min(self._pool.count, totalBatches)

	self._registry[reqId] = { callback = callback, buf = buf, received = 0, expected = expectedSignals }

	self._pool:DispatchBatched(name, threadCount, batchSize, reqId, ...)
end

type self = typeof(Static.new(...))

return Static
