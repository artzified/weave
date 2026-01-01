--!native
--!optimize 2
local types = require("./types")
local ActorPool = {}
local Static = {}

local HANDSHAKE_MAX_TRIES = 10
local HANDSHAKE_INTERVAL = 0.1
local HANDSHAKE_TIMEOUT = 1

type self = types.ActorPool

function Static.new(actorStorage: Instance?): self
	return setmetatable({
		actors = {},
		count = 0,
		actorStorage = actorStorage or script,
		populateCallback = nil,
		handshakeBindable = Instance.new('BindableEvent')
	}, { __index = ActorPool }) :: self
end

function ActorPool.DoHandshake(self: self, handshakeName: string, ...)
	local readyCount = 0
	local conn: RBXScriptConnection
	conn = self.handshakeBindable.Event:Connect(function()
		readyCount += 1
		if readyCount == self.count then
			conn:Disconnect()
		end
	end)

	for _ = 1, HANDSHAKE_MAX_TRIES do
		if readyCount == self.count then
			return
		end
		self:DispatchAll(`{handshakeName}-handshake`, self.handshakeBindable, ...)
		task.wait(HANDSHAKE_INTERVAL)
	end

	local start = os.clock()
	while readyCount < self.count and (os.clock() - start) < HANDSHAKE_TIMEOUT do
		task.wait()
	end

	if readyCount < self.count then
		error(`[Celeris::ActorPool] Handshake '{handshakeName}' timeout`)
	end
end

function ActorPool.Populate(self: self, worker: Script | LocalScript, actorCount: number)
	for _ = 1, actorCount do
		local actor = Instance.new("Actor")
		local clone = worker:Clone()
		clone.Enabled = false
		clone.Parent = actor
		clone.Enabled = true
		actor.Parent = self.actorStorage

		if self.populateCallback then
			self.populateCallback(actor)
		end

		table.insert(self.actors, actor)
	end

	self.count = actorCount
	self:DoHandshake("$actor")
end

function ActorPool.DispatchAll(self: self, message: string, ...)
	for _, actor in self.actors do
		actor:SendMessage(message, ...)
	end
end

function ActorPool.DispatchBatched(self: self, message: string, threadCount: number, batchSize: number, ...)
	local actorCount = #self.actors
	local actorIndex = 1

	for startIndex = 1, threadCount, batchSize do
		local isLastForThisActor = (startIndex + (actorCount * batchSize)) > threadCount

		self.actors[actorIndex]:SendMessage(message, startIndex, threadCount, batchSize, isLastForThisActor, ...)
		actorIndex = (actorIndex % actorCount) + 1
	end
end

function ActorPool.OnPopulate(self: self, callback: ((Actor) -> ())?)
	self.populateCallback = callback
end

function ActorPool.Destroy(self: self)
	for _, actor in self.actors do
		actor:Destroy()
	end
	self.actors = {}
	self.populateCallback = nil
end

return Static
