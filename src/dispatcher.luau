local bridge = require("./bridge")
local Static = {}
local Dispatcher = {}

function Static.new(actorCount: number, workerScript: LocalScript | Script)
	return setmetatable({ _bridge = bridge.new(actorCount, workerScript) }, { __index = Dispatcher })
end

function Dispatcher.Dispatch(self: self, name: string, threadCount: number, callback: (buf: {any}) -> (), _batchSize: number?, ...)
	local batchSize = _batchSize or math.ceil(threadCount / self._bridge._pool.count)
	local buf = table.create(threadCount) -- might have to pool buffers to avoid table allocation

	self._bridge:Send(name, threadCount, batchSize, buf, function()
		callback(buf)
	end)
end

function Dispatcher.DispatchDeferred(
	self: self,
	name: string,
	threadCount: number,
	callback: (buf: { any }) -> (),
	_batchSize: number?,
	...
)
	task.defer(self.Dispatch, self, name, threadCount, callback, _batchSize, ...)
end

function Dispatcher.Destroy(self: self)
	self._bridge:Destroy()
end

export type self = typeof(Static.new(...))

return Static
