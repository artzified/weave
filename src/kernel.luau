--!native
--!optimize 2
local constants = require("./constants")
local utils = require("./utils")

local Static = {}
local Kernel = {}

local b, e = utils.profiling()

function Static.new(actor: Actor)
	local self = setmetatable({
		actor = actor,
		_resBuf = table.create(2048),
		_messenger = nil :: BindableEvent?,
	}, { __index = Kernel })

	actor:BindToMessage(constants.messengerBindableSignal, function(bindable: BindableEvent)
		self._messenger = bindable
	end)

	return self
end

function Kernel.On(self: self, name: string, process: (id: number, ...any) -> any)
	local resBuf = self._resBuf
	local resPtr = 1
	local firstStartIndex = 0

	self.actor:BindToMessageParallel(
		name,
		function(startIndex: number, threadCount: number, batchSize: number, isLast: boolean, reqId: number, ...)
			assert(self._messenger, "Haven't gotten messenger bindable yet!")

			b(`run instruction {name}`)

			if resPtr == 1 then
				firstStartIndex = startIndex
			end

			local lastIndex = math.min(startIndex + (batchSize - 1), threadCount)

			b("run process")

			for i = startIndex, lastIndex do
				resBuf[resPtr] = process(i, ...)
				resPtr += 1
			end

			e()

			if isLast then -- flush
				b("flush")

				self._messenger:Fire(reqId, resBuf, firstStartIndex, resPtr - 1)

				resPtr = 1

				e()
			end

			e()
		end
	)
end

function Kernel.OnDetached(self: self, name: string, process: (id: number, ...any) -> ())
	self.actor:BindToMessageParallel(
		name,
		function(startIndex: number, threadCount: number, batchSize: number, ...)
			local lastIndex = math.min(startIndex + (batchSize - 1), threadCount)
			
			b("run detached process")

			for i = startIndex, lastIndex do
				process(i, ...)
			end

			e()
		end
	)
end

function Kernel.Ready(self: self)
	self.actor:SetAttribute(constants.readyAttribute, true)
end

export type self = typeof(Static.new(...))

return Static
