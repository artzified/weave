local ReplicatedStorage = game:GetService("ReplicatedStorage")
local celeris = require(ReplicatedStorage.celeris)

local cluster = celeris.cluster.new(8, script.Parent.worker)

while task.wait() do
	-- local start = os.clock()
	cluster:DispatchDeferred("ray", 200*200, function(buf)
		-- print(os.clock()-start)
	end)
end