--!native
--!optimize 2
local utils = require("@self/utils")

local Celeris = {}

local b, e = utils.profiling()

local clear = table.clear
local min = math.min

local jobsReadonlyData = {}

local function BindToHandshake(actor: Actor, prefix: string, callback: (...any) -> ())
	return actor:BindToMessage(`{prefix}-handshake`, function(handshakeBindable: BindableEvent, ...)
		callback(...)
		handshakeBindable:Fire()
	end)
end

function Celeris.GetReadonly(name: string)
	local data = jobsReadonlyData[name]
	if not data then
		data = {} :: {[number | string]: any}
		jobsReadonlyData[name] = data
	end
	return data
end

--[[ 
	Binds to the specified instruction name
]]
function Celeris.ListenToJob(actor: Actor, name: string, callback: (id: number) -> any)
	local responsesBuf = {}
	local startIndicesBuf = {}
	local startindicesPtr = 1
	local responsesPtr = 1
	local bindable = nil

	if not jobsReadonlyData[name] then
		jobsReadonlyData[name] = {}
	end

	if not actor:GetAttribute("boundActorHandshake") then
		actor:SetAttribute("boundActorHandshake", true)
		BindToHandshake(actor, "$actor", function() end)
	end

	BindToHandshake(actor, `$readonly-{name}`, function(k: string | number, v: any)
		jobsReadonlyData[name][k] = v
	end)

	BindToHandshake(actor, name, function(responseBindable: BindableEvent)
		bindable = responseBindable
	end)

	actor:BindToMessageParallel(
		name,
		function(startIndex: number, threadCount: number, batchSize: number, isLastBatch: boolean, ...)
			assert(bindable, "Haven't received bindable yet!")

			b(`run instruction {name}`)

			startIndicesBuf[startindicesPtr] = startIndex
			startindicesPtr += 1

			b("instruction callbacks")
			local lastIndex = min(startIndex + (batchSize - 1), threadCount)

			for i = startIndex, lastIndex do
				local res = callback(i, ...)
				responsesBuf[responsesPtr] = res
				responsesPtr += 1
			end
			e()

			if isLastBatch then
				b("instruction flush")
				bindable:Fire(responsesBuf, startIndicesBuf)
				clear(responsesBuf)
				clear(startIndicesBuf)
				responsesPtr = 1
				startindicesPtr = 1
				e()
			end

			e()
		end
	)
end

Celeris.Cluster = require("@self/cluster")

return Celeris
