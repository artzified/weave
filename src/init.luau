--!native
--!optimize 2
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local Celeris = {}

local insert = table.insert

function Celeris.ListenToInstruction(
	actor: Actor,
	name: string,
	callback: (id: number, localMemory: { any }?, ...any) -> any
)
	local st, stId
	local localMemory

	actor:BindToMessageParallel(`{name}-localmemory`, function(_localMemory)
		localMemory = _localMemory
	end)

	actor:BindToMessageParallel(
		name,
		function(
			instId: string,
			startIndex: number,
			threadCount: number,
			batchSize: number,
			bindable: BindableEvent,
			...
		)
			debug.profilebegin(`run instruction {name}`)

			-- Cache invalidation
			if not st or stId ~= instId then
				debug.profilebegin("get shared table")

				st = SharedTableRegistry:GetSharedTable(`clrs-{instId}`)
				stId = instId

				debug.profileend()
			end

			debug.profilebegin("instruction callbacks")
			local responses = table.create(batchSize)
			for i = startIndex, math.min(startIndex + (batchSize - 1), threadCount) do
				local res = callback(i, localMemory, ...)
				insert(responses, if res == nil then true else res)
			end
			debug.profileend()

			debug.profilebegin("send result")

			st[startIndex // batchSize] = responses

			bindable:Fire()

			debug.profileend()
			debug.profileend()
		end
	)
end

Celeris.Coordinator = require(script.coordinator)

return Celeris
