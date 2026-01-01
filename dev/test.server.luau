local ReplicatedStorage = game:GetService("ReplicatedStorage")
local celeris = require(ReplicatedStorage.celeris)

local coordinator = celeris.Coordinator.new(script.Parent.worker, 8)
print("created coordinator")

local inst = coordinator:DefineInstruction("ray")
print("instruction defined")

while task.wait() do
	local a = os.clock()
	coordinator:DispatchDeferred(inst, 200*200, function(data: { any })
		print(os.clock() - a)
	end)
end
