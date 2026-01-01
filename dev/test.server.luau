local ReplicatedStorage = game:GetService("ReplicatedStorage")
local celeris = require(ReplicatedStorage.celeris)

local cluster = celeris.Cluster.new(script.Parent.worker, 8)
print("created cluster")

local job = cluster:DefineJob("ray"):Linear():SetReadonlyData(1, 10)
print("job defined")

while task.wait() do
	local a = os.clock()
	job:Dispatch(1024, function(data: { any })
		print(os.clock() - a)
	end)
end
