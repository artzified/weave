local Static = {}

type Coordinator = {
	actors: {Actor}
}

function Static.new(coordinator: Coordinator, name: string)
	local bindable = Instance.new("BindableEvent")

	local self = {
		name = name;
		bindable = bindable;
	}

	for _, actor in coordinator.actors do
		actor:SendMessage(`{name}-bindable`, bindable)
	end

	return self
end

export type Instruction = typeof(Static.new(...))

return Static