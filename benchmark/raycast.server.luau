local ReplicatedStorage = game:GetService("ReplicatedStorage")
print("requiring celeris")
local celeris = require(ReplicatedStorage.weave)

local dispatcher = celeris.dispatcher.new(8, script.Parent.worker)

while task.wait() do
	local start = os.clock()
	dispatcher:DispatchDeferred("ray", 200 * 200, function(buf)
		print(os.clock()-start)
	end)
end