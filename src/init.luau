--!native
--!optimize 2
local Celeris = {}
local Utils = require(script.utils)

local b: (string) -> (), e = Utils.profiling()

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
	local ptr = 1
	local bindable = nil

	actor:BindToMessageParallel(`{name}-bindable`, function(_bindable: BindableEvent)
		bindable = _bindable
	end)

	actor:BindToMessageParallel(name, function(startIndex, threadCount, batchSize, isLastBatch, ...)
		assert(bindable, "Haven't received bindable yet!")
		
		b(`run instruction {name}`)

		b("instruction callbacks")
		local lastIndex = min(startIndex + (batchSize - 1), threadCount)

		for i = startIndex, lastIndex do
			local res = callback(i, ...)
			responsesBuf[ptr] = res == nil or res -- if res is nil, set as true
			ptr += 1
		end
		e()

		if isLastBatch then
			b("instruction flush")
			bindable:Fire(startIndex, responsesBuf)
			clear(responsesBuf)
			ptr = 1
			e()
		end

		e()
	end)
end

Celeris.Coordinator = require(script.coordinator)

return Celeris