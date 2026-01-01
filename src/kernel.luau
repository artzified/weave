--!native
--!optimize 2
local utils = require("./utils")

local Static = {}
local Kernel = {}

local b, e = utils.profiling()

function Static.new(actor: Actor)
	local self = setmetatable({
		actor = actor,
		_resBuf = table.create(2048),
		_idxBuf = table.create(128),
		_messenger = nil :: BindableEvent?,
	}, { __index = Kernel })

	actor:BindToMessage("$bridge-messenger", function(bindable: BindableEvent)
		self._messenger = bindable
	end)

	return self
end

function Kernel.On(self: self, name: string, process: (id: number, ...any) -> any)
	local resBuf = self._resBuf
	local idxBuf = self._idxBuf

	local resPtr = 1
	local idxPtr = 1

	self.actor:BindToMessageParallel(
		name,
		function(startIndex: number, threadCount: number, batchSize: number, isLast: boolean, reqId: number, ...)
			assert(self._messenger, "Haven't gotten messenger bindable yet!")

			b(`run instruction {name}`)

			idxBuf[idxPtr] = startIndex
			idxPtr += 1

			local lastIndex = math.min(startIndex + (batchSize - 1), threadCount)

			b("run process")

			for i = startIndex, lastIndex do
				resBuf[resPtr] = process(i, ...)
				resPtr += 1
			end

			e()

			if isLast then -- flush
				b("flush")

				self._messenger:Fire(reqId, resBuf, idxBuf, batchSize)

				resPtr = 1
				idxPtr = 1

				e()
			end

			e()
		end
	)
end

function Kernel.Ready(self: self)
	self.actor:SetAttribute("celeris-ready", true)
end

type self = typeof(Static.new(...))

return Static
