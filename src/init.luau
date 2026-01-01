--!native
--!optimize 2
local utils = require("@self/utils")

local Celeris = {}

local b: (string) -> (), e = utils.profiling()

local create = table.create
local clear = table.clear
local min = math.min

--[[ 
	Binds to the specified instruction name
]]
function Celeris.ListenToInstruction(
	actor: Actor,
	name: string,
	callback: (id: number) -> any
)
	local responsesBuf = create(1024)
	local startIndicesBuf = create(64)
	local startindicesPtr = 1
	local responsesPtr = 1
	local bindable = nil

	if not actor:GetAttribute('boundActorHandshake') then
		actor:SetAttribute('boundActorHandshake', true)
		actor:BindToMessage('$actor-handshake', function(handshakeBindable: BindableEvent)
			handshakeBindable:Fire()
		end)
	end

	actor:BindToMessage(`{name}-handshake`, function(handshakeBindable: BindableEvent, responseBindable: BindableEvent)
		bindable = responseBindable
		handshakeBindable:Fire()
	end)

	actor:BindToMessageParallel(name, function(startIndex, threadCount, batchSize, isLastBatch, ...)
		assert(bindable, "Haven't received bindable yet!")
		
		b(`run instruction {name}`)

		startIndicesBuf[startindicesPtr] = startIndex
		startindicesPtr += 1

		b("instruction callbacks")
		local lastIndex = min(startIndex + (batchSize - 1), threadCount)

		for i = startIndex, lastIndex do
			local res = callback(i, ...)
			responsesBuf[responsesPtr] = res == nil or res -- if res is nil, set as true
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
	end)


end

Celeris.Coordinator = require("@self/coordinator")

return Celeris