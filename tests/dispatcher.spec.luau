local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function()
	local weave = require(ReplicatedStorage.weave)
	local dispatcher: weave.Dispatcher
	beforeAll(function()
		dispatcher = weave.dispatcher.new(8, script.Parent.worker)
	end)

	afterAll(function()
		dispatcher:Destroy()
	end)
	
	describe("dispatcher", function()
		it("should dispatch a job under normal conditions", function()
			expect(dispatcher).to.be.ok()
			local res = {}
			dispatcher:DispatchDeferred("ray", 200, function(buf)
				res = buf
			end)
			task.wait(1)
			expect(res).to.be.ok()
			expect(#res).to.equal(200)
			for i = 1, #res do
				local data = res[i]
				expect(data[1]).to.equal(i)
			end
		end)

		it("should handle batch size of 1", function()
			expect(dispatcher).to.be.ok()
			local res = {}
			dispatcher:DispatchDeferred("ray", 200, function(buf)
				res = buf
			end, 1)
			task.wait(1)
			expect(res).to.be.ok()
			expect(#res).to.equal(200)
			for i = 1, #res do
				local data = res[i]
				expect(data[1]).to.equal(i)
			end
		end)

		it("should handle threadCount < actorCount", function()
			local res = {}
			dispatcher:DispatchDeferred("ray", 5, function(buf)
				res = buf
			end)
			task.wait(0.5)

			expect(#res).to.equal(5)
			for i = 1, 5 do
				expect(res[i][1]).to.equal(i)
			end
		end)

		it("should handle threadCount == actorCount", function()
			local res = {}
			dispatcher:DispatchDeferred("ray", 8, function(buf)
				res = buf
			end)
			task.wait(0.5)

			expect(#res).to.equal(8)
			for i = 1, 8 do
				expect(res[i][1]).to.equal(i)
			end
		end)

		it("should handle prime threadCount with batchSize = 1", function()
			local count = 997
			local res = {}
			dispatcher:DispatchDeferred("ray", count, function(buf)
				res = buf
			end, 1)
			task.wait(1)

			expect(#res).to.equal(count)
			for i = 1, count do
				expect(res[i][1]).to.equal(i)
			end
		end)

		it("should handle non-divisible batch sizes", function()
			local res = {}
			dispatcher:DispatchDeferred("ray", 1234, function(buf)
				res = buf
			end, 7)
			task.wait(1)

			expect(#res).to.equal(1234)
			for i = 1, 1234 do
				expect(res[i][1]).to.equal(i)
			end
		end)

		it("should handle very small workloads", function()
			for n = 1, 10 do
				local res = {}
				dispatcher:DispatchDeferred("ray", n, function(buf)
					res = buf
				end)
				task.wait(0.2)

				expect(#res).to.equal(n)
				for i = 1, n do
					expect(res[i][1]).to.equal(i)
				end
			end
		end)

		it("should handle batchSize larger than threadCount", function()
			local res = {}
			dispatcher:DispatchDeferred("ray", 50, function(buf)
				res = buf
			end, 100)
			task.wait(0.5)

			expect(#res).to.equal(50)
			for i = 1, 50 do
				expect(res[i][1]).to.equal(i)
			end
		end)

		it("should handle multiple sequential dispatches", function()
			for iter = 1, 5 do
				local res = {}
				dispatcher:DispatchDeferred("ray", 500, function(buf)
					res = buf
				end)
				task.wait(0.5)

				expect(#res).to.equal(500)
				for i = 1, 500 do
					expect(res[i][1]).to.equal(i)
				end
			end
		end)

		it("should isolate buffers across dispatch names", function()
			local resA = {}
			local resB = {}

			dispatcher:DispatchDeferred("ray", 100, function(buf)
				resA = buf
			end)

			dispatcher:DispatchDeferred("ray2", 200, function(buf)
				resB = buf
			end)

			task.wait(1)

			expect(#resA).to.equal(100)
			expect(#resB).to.equal(200)

			for i = 1, 100 do
				expect(resA[i][1]).to.equal(i)
			end
			for i = 1, 200 do
				expect(resB[i][1]).to.equal(i)
			end
		end)

		it("should handle randomized batch sizes", function()
			for _ = 1, 20 do
				local count = math.random(1, 5000)
				local batch = math.random(1, 32)
				local res = {}

				dispatcher:DispatchDeferred("ray", count, function(buf)
					res = buf
				end, batch)

				task.wait(0.5)

				expect(#res).to.equal(count)
				for i = 1, count do
					expect(res[i][1]).to.equal(i)
				end
			end
		end)

		it("should handle overlapping dispatches", function()
			local res1, res2 = {}, {}

			dispatcher:DispatchDeferred("ray", 1000, function(buf)
				res1 = buf
				print("one", #buf)
			end)

			dispatcher:DispatchDeferred("ray", 1500, function(buf)
				res2 = buf
				print("two", #buf)

			end)

			task.wait(1)

			expect(res1).never.to.equal(res2)
			expect(#res1).to.equal(1000)
			expect(#res2).to.equal(1500)
		end)
	end)
end