local actor = script:GetActor()

if not actor then
	return
end

local celeris = require(game.ReplicatedStorage.celeris)

celeris.ListenToInstruction(actor, "ray", function(id: number)
	local res = workspace:Raycast(Vector3.zero, -Vector3.yAxis * 1000)
	return res
end)
