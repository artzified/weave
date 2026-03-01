local bridge = require("./bridge")
local Static = {}
local Dispatcher = {}

function Static.new(actorCount: number, workerModule: ModuleScript)
	return setmetatable({ _bridge = bridge.new(actorCount, workerModule), _buffers = {} :: {[string]: {any}} }, { __index = Dispatcher })
end

function Dispatcher.Dispatch(self: self, name: string, threadCount: number, callback: (buf: {any}) -> (), _batchSize: number?, ...)
	local batchSize = _batchSize or math.ceil(threadCount / self._bridge._pool.count)
	local buf = self._buffers[name]
	if not buf then
		buf = {}
		self._buffers[name] = buf
	end

	table.clear(buf)

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
	table.clear(self._buffers)
end

export type self = typeof(Static.new(...))

return Static
