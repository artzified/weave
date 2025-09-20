--!native
--!optimize 2
local Celeris = {}
local Utils = require(script.utils)

local b, e = Utils.profiling()

local create = table.create
local insert = table.insert

--[[
	Binds to the specified instruction name
]]
function Celeris.ListenToInstruction(
	actor: Actor,
	name: string,
	callback: (id: number, localMemory: { any }?, ...any) -> any
)
	local localMemory
	local bindable
	local function bindableFire(...)
		bindable:Fire(...)
	end

	actor:BindToMessageParallel(`{name}-localmemory`, function(_localMemory)
		localMemory = _localMemory
	end)

	actor:BindToMessageParallel(`{name}-bindable`, function(_bindable: BindableEvent)
		bindable = _bindable
	end)

	actor:BindToMessageParallel(
		name,
		function(
			startIndex: number,
			threadCount: number,
			batchSize: number,
			...
		)
			b(`run instruction {name}`)

			b("instruction callbacks")
			local responses = create(batchSize)
			for i = startIndex, math.min(startIndex + (batchSize - 1), threadCount) do
				local res = callback(i, localMemory, ...)
				insert(responses, if res == nil then true else res)
			end
			e()

			b("send result")

			bindableFire(startIndex, responses)

			e()
			e()
		end
	)
end

Celeris.Coordinator = require(script.coordinator)
Celeris.Pipeline = require(script.pipeline)

return Celeris
