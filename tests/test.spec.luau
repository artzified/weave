local ReplicatedStorage = game:GetService("ReplicatedStorage")
print('requiring celeris')
local celeris = require(ReplicatedStorage.weave)

print('creating')
local dispatcher = celeris.dispatcher.new(1, script.Parent["worker.spec"])
print('dispatcher created')

-- while task.wait() do
	dispatcher:DispatchDeferred("ray", 200*200, function(buf)
		print(buf)
	end)
