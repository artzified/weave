local ReplicatedStorage = game:GetService("ReplicatedStorage")
local celeris = require(ReplicatedStorage.weave)

local dispatcher = celeris.dispatcher.new(8, script.Parent["raycast-worker"])

local THREAD_COUNT = 100*100

-- Serial baseline
local serStart = os.clock()
for id = 1, THREAD_COUNT do
	local origin = Vector3.new(id * 0.1, 10, 0)
	for angle = 0, 7 do
		local radians = (angle / 8) * math.pi * 2
		local direction = Vector3.new(math.cos(radians), -0.5, math.sin(radians)) * 500
		workspace:Raycast(origin, direction)
	end
end
local serial = (os.clock() - serStart) * 1000
print(string.format("Serial (main thread): %.2f ms", serial))

while task.wait() do
	local s = os.clock()
	dispatcher:Dispatch("sensor-sweep", THREAD_COUNT, function()
		print(string.format("Total job time: %.2f ms", (os.clock() - s) * 1000))
	end)
	print(string.format("Main thread blocked for: %.2f ms", (os.clock() - s) * 1000))
end