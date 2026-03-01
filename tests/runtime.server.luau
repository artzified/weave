local ReplicatedStorage = game:GetService("ReplicatedStorage")
local weave = require(ReplicatedStorage.weave)

local cluster = weave.dispatcher.new(8, script.Parent.worker)

while task.wait() do
	local start = os.clock()
	cluster:DispatchDeferred("ray", 200 * 200, function(buf)
		print(os.clock()-start)
	end)
end
