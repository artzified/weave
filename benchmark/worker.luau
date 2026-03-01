--!native 
--!optimize 2
local actor = script:GetActor()

assert(actor)

local celeris = require(game.ReplicatedStorage.weave)
local kernel = celeris.kernel.new(actor)

kernel:On('ray', function(id)
	local res = workspace:Raycast(Vector3.one, Vector3.yAxis * -1000)
	return res
end)

return true