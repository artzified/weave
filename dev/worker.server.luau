--!native 
--!optimize 2
local actor = script:GetActor()

if not actor then
	return
end

local celeris = require(game.ReplicatedStorage.celeris)
local data = celeris.GetReadonly("ray")

celeris.ListenToJob(actor, "ray", function(id: number)
	local res = workspace:Raycast(Vector3.zero, -Vector3.yAxis * data[1])
	return res
end)
