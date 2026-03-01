local dispatcher = require("@self/dispatcher")
local kernel = require("@self/kernel")

export type Dispatcher = dispatcher.self
export type Kernel = kernel.self

return {
	dispatcher = dispatcher,
	kernel = kernel,
}
