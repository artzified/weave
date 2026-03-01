--!native
--!optimize 2
local actor_pool = require("./actor-pool")
local constants = require("./constants")
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

	self._pool:DispatchAll(constants.messengerBindableSignal, self._messenger)

	self._messenger.Event:Connect(
		function(reqId: number, responses: { any }, startIndex: number, totalItems: number)
			local req = self._registry[reqId]
			if not req then
				return
			end

			b('put responses to buffer')

			table.move(responses, 1, totalItems, startIndex, req.buf)

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
	self._ptr = (self._ptr + 1) % 0xFFFFF

	local reqId = self._ptr
	local totalBatches = math.ceil(threadCount / batchSize)
	local expectedSignals = math.min(self._pool.count, totalBatches)

	self._registry[reqId] = { callback = callback, buf = buf, received = 0, expected = expectedSignals }

	self._pool:DispatchBatched(name, threadCount, batchSize, reqId, ...)
end

type self = typeof(Static.new(...))

return Static
