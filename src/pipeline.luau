--!native
--!optimize 2
local Coordinator = require(script.Parent.coordinator)

local Static = {}
local Pipeline = {}

type Stage = {
	deferred: boolean?,
	instruction: Coordinator.Instruction,
	threadCount: number,
	batchSize: number?,
}

function Static.new(coordinator: Coordinator.Coordinator, stages: { Stage })
	return setmetatable({
		coordinator = coordinator,
		stages = stages,
	}, { __index = Pipeline })
end

function Pipeline.run(self: Pipeline, callback: () -> any)
	local coordinator = self.coordinator
	local stages = self.stages

	local data = {}
	local function inner(stageIndex: number?, passData: {any}?)
		local _stageIndex = stageIndex or 1

		if _stageIndex > #stages then
			return callback(unpack(data))
		end

		local stage = stages[_stageIndex]
		local method = if stage.deferred then 'DispatchDeferred' else 'DispatchImmediate'
		coordinator[method](coordinator, stage.instruction, stage.threadCount, function(stageData)
			table.insert(data, stageData)
			inner(_stageIndex + 1, stageData)
		end, stage.batchSize, passData)

		return
	end
	
	inner()
end

export type Pipeline = typeof(Static.new(...))

return Static
