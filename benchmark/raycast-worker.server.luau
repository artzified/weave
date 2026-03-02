--!native
--!optimize 2
local actor = script:GetActor()
if not actor then
	return
end

local weave = require(game.ReplicatedStorage.weave)
local kernel = weave.kernel.new(actor)

kernel:On("sensor-sweep", function(id)
	local origin = Vector3.new(id * 0.1, 10, 0)
	local hits = 0

	for angle = 0, 7 do
		local radians = (angle / 8) * math.pi * 2
		local direction = Vector3.new(math.cos(radians), -0.5, math.sin(radians)) * 500
		local result = workspace:Raycast(origin, direction)
		if result then
			hits += 1
		end
	end

	return hits
end)

kernel:OnDetached("sensor-sweep-detached", function(id)
	local origin = Vector3.new(id * 0.1, 10, 0)
	for angle = 0, 7 do
		local radians = (angle / 8) * math.pi * 2
		local direction = Vector3.new(math.cos(radians), -0.5, math.sin(radians)) * 500
		workspace:Raycast(origin, direction)
	end
end)

kernel:Ready()
