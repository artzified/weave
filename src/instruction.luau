--!nonstrict
local Static = {}
local Instruction = {}

type Coordinator = {
	actors: {Actor}
}

function Static.new(coordinator: Coordinator, name: string, localMemory: {any}?)
	local bindable = Instance.new("BindableEvent")

	local self = setmetatable({
		coordinator = coordinator;
		name = name;
		bindable = bindable;
	}, {
		__index = Instruction
	})

	if localMemory then
		self:SetLocalMemory(localMemory) -- type checker wont shut up here
	end

	for _, actor in self.coordinator.actors do
		actor:SendMessage(`{name}-bindable`, bindable)
	end

	return self
end

--[[
	Overrides the local memory of all the actors. Best used for changing constants
]]
function Instruction.SetLocalMemory(self: Instruction, localMemory: { any })
	for _, actor in self.coordinator.actors do
		actor:SendMessage(`{self.name}-localmemory`, localMemory)
	end
end

export type Instruction = typeof(Static.new(...))

return Static