--!native
--!optimize 2
local actor_pool = require("./actor-pool")
local job = require("./job")
local types = require("./types")

local Static = {}
local Cluster = {}

type self = types.Cluster

function Static.new(
	worker: Script | LocalScript,
	actorCount: number,
	actorStorage: Instance?,
	populateCallback: ((Actor) -> ())?
)
	local pool = actor_pool.new(actorStorage)

	pool:Populate(worker, actorCount)

	local self = setmetatable({
		pool = pool,
		registeredJobs = {},
		handshakeBindable = Instance.new("BindableEvent"),
	}, { __index = Cluster }) :: self

	return self
end

--[[ 
	Creates a new instruction object, yields until all actors have acknowledged it
]]
function Cluster.DefineJob(self: self, name: string)
	local existingInstruction = self.registeredJobs[name]
	if existingInstruction then
		warn(`Instruction "{name}" already exists under this cluster`)
		return existingInstruction
	end

	local job = job.new(name, self.pool)
	self.registeredJobs[name] = job

	return job
end

--[[
	A deferred proxy to `:DispatchImmediate`. Recommended for intensive rapid tasks to avoid frame drops
]]
-- function Cluster.DispatchDeferred(
-- 	self: self,
-- 	job: types.Job,
-- 	threadCount: number,
-- 	callback: ((data: { any }) -> ...any)?,
-- 	...
-- )
-- 	task.defer(self.DispatchImmediate, self, job, threadCount, callback, ...)
-- end

--[[
	Destroys the actor pool and subsequently the Cluster.
]]
function Cluster.Destroy(self: self)
	self.pool:Destroy()

	table.clear(self :: never) -- type checker wont shut up
end

return Static
