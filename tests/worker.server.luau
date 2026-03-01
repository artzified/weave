--!native
--!optimize 2
local actor = script:GetActor()

if not actor then
	return
end

local weave = require(game.ReplicatedStorage.weave)
local kernel = weave.kernel.new(actor)

kernel:On("ray", function(id)
	local res = workspace:Raycast(Vector3.one, Vector3.yAxis * -1000)
	return {id, res}
end)

kernel:Ready()
