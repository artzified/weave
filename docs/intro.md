---
sidebar_position: 1
---

# Getting Started

Weave is a parallel execution framework for Roblox. It handles actor management, work distribution, and result aggregation so you can focus on the work itself rather than the plumbing.

## Installation

### Pesde

```bash
pesde add artzified/weave
```

Then require it from your project:

```lua
local weave = require("@pkg/weave")
```

### GitHub Releases

Download the latest `.rbxm` from the [releases page](https://github.com/artzified/weave/releases) and drop it into your Roblox project. Place it somewhere accessible to both server and client scripts, such as `ReplicatedStorage`.

---

## Core Concepts

Weave has two sides that work together:

- **Worker** — a Script or LocalScript that runs inside an Actor. It uses the [Kernel](/api/Kernel) to register handlers for named jobs.
- **Master** — the script that owns the [Dispatcher](/api/Dispatcher) and decides when to run jobs and how many threads to use.

The master never executes work directly. It dispatches a job by name, Weave splits the work across all available actors, and the results (if any) come back through a callback.

---

## Setting Up the Worker

Create a `Script` (or `LocalScript` for client-side work) that will be cloned into each actor. The worker should always guard against running outside an actor context.

```lua title="worker.server.luau"
local actor = script:GetActor()
if not actor then return end

local weave = require(game.ReplicatedStorage.weave)
local kernel = weave.kernel.new(actor)

-- Register a job that returns a result.
-- `id` is the thread index for this invocation (1-based).
kernel:On("myJob", function(id, ...)
    -- do work, return a result
    return id * 2
end)

-- Call :Ready when all handlers are registered.
-- The master will not dispatch until this is set.
kernel:Ready()
```

:::note
Always call [`kernel:Ready()`](/api/Kernel#Ready) **after** all your [`kernel:On`](/api/Kernel#On) and [`kernel:OnDetached`](/api/Kernel#OnDetached) calls. The master waits for every worker to report ready before dispatching anything, so registering a handler after `Ready()` creates a race condition.
:::

---

## Setting Up the Master

The master creates a `Dispatcher` pointed at your worker script and calls `Dispatch` to run jobs.

```lua title="master.server.luau"
local weave = require(game.ReplicatedStorage.weave)

-- First argument is the number of actors to spawn.
-- Second argument is the worker script to clone into each actor.
local dispatcher = weave.dispatcher.new(8, script.Parent.worker)
```

### Dispatching a Job

`Dispatch` runs a job across `threadCount` threads and calls `callback` with the result buffer once all workers have reported back.

```lua title="worker.server.luau"
-- Run "myJob" across 500 threads.
-- `buf` is a table where buf[i] is the return value from thread i.
dispatcher:Dispatch("myJob", 500, function(buf)
    for i, result in buf do
        print(i, result)
    end
end)
```

The optional fourth argument overrides the batch size (threads per actor per message). By default Weave calculates this automatically based on your actor count.

```lua title="master.server.luau"
-- Manual batch size of 64 threads per actor
dispatcher:Dispatch("myJob", 500, function(buf)
    -- ...
end, 64)
```

Any arguments after the batch size are forwarded to the worker handler as extra arguments.

```lua title="master.server.luau"
dispatcher:Dispatch("myJob", 500, function(buf)
	-- ...
end, nil, 'hey there!')
```
```lua title="worker.server.luau"
kernel:On("myJob", function(id, message) -- "hey there!" message from the dispatcher
	return id * #message
end)
```

## Detached Dispatch (Fire-and-Forget)

Sometimes, you don't want to send anything back to the dispatcher, the kernel just does their job, and the dispatcher forgets about it and moves on.

This is the lowest overhead dispatch there is and is used for pure side-effect jobs where the kernel does all the work.

To do a detached job, use the [`Kernel:OnDetached`](/api/Kernel#OnDetached) to declare a detached job.
```lua
kernel:OnDetached("myDetachedJob", function(id)
	doSomething()
	-- doesn't return anything
end)
```
To use the detached job, use the [`Dispatcher:DispatchDetached`](/api/Dispatcher#DispatchDetached) to dispatch it.
```lua
Dispatcher:DispatchDetached("myDetachedJob", 500)
```

:::info
See [Types of Job Dispatches](/docs/types-of-dispatches.md) for more information
:::
---

## Full Example

A simple parallelized chunked terrain generation example using Weave

```lua title="worker.client.luau"
--!native
--!optimize 2
local Workspace = game:GetService("Workspace")

local actor = script:GetActor()
if not actor then
	return
end

local weave = require(game.ReplicatedStorage.weave)
local kernel = weave.kernel.new(actor)

type VoxelData = {
	materials: { { { Enum.Material } } },
	occupancy: { { { number } } },
}

type ChunkCoord = { x: number, y: number, z: number }

local function makeNdArray(numDim: number, size: number, elemValue: any): any
	if numDim == 0 then
		return elemValue
	end
	local result = {}
	for i = 1, size do
		result[i] = makeNdArray(numDim - 1, size, elemValue)
	end
	return result
end

local function generateVoxels(xd: number, yd: number, zd: number): VoxelData
	local materials: { { { Enum.Material } } } = makeNdArray(3, 4, Enum.Material.Grass)
	local occupancy: { { { number } } } = makeNdArray(3, 4, 0)

	for x = 0, 3 do
		for y = 0, 3 do
			for z = 0, 3 do
				local wx = xd + 0.25 * x
				local wy = yd + 0.25 * y 
				local wz = zd + 0.25 * z

				local surfaceHeight = math.noise(wx * 0.05, wz * 0.05) * 20 + math.noise(wx * 0.15, wz * 0.15) * 8

				local depthBelowSurface = surfaceHeight - wy

				local caveNoise = math.noise(wx * 0.3, wy * 0.3, wz * 0.3) + depthBelowSurface * 0.3

				local density = caveNoise

				local mat: Enum.Material
				if depthBelowSurface < 1 then
					mat = Enum.Material.Grass
				elseif depthBelowSurface < 4 then
					mat = Enum.Material.Ground
				else
					mat = Enum.Material.Rock
				end

				occupancy[x + 1][y + 1][z + 1] = density > 0 and 1 or 0
				materials[x + 1][y + 1][z + 1] = mat
			end
		end
	end

	return { materials = materials, occupancy = occupancy }
end

kernel:OnDetached("GenerateChunk", function(id: number, chunks: { ChunkCoord })
	local chunk: ChunkCoord = chunks[id]

	local voxels: VoxelData = generateVoxels(chunk.x, chunk.y, chunk.z)
	local corner: Vector3 = Vector3.new(chunk.x * 16, chunk.y * 16, chunk.z * 16)

	task.synchronize()

	Workspace.Terrain:WriteVoxels(
		Region3.new(corner, corner + Vector3.new(16, 16, 16)),
		4,
		voxels.materials,
		voxels.occupancy
	)
end)

kernel:Ready()
```
```lua title="master.client.luau"
--!native
--!optimize 2
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local weave = require(ReplicatedStorage.weave)

-- How many chunks to generate in each horizontal direction from the camera.
-- Vertical range is intentionally smaller since terrain is mostly flat.
local RENDER_DISTANCE: number = 8
local VERTICAL_DISTANCE: number = 10
local CHUNK_SIZE: number = 16 -- studs per chunk side

type ChunkCoord = { x: number, y: number, z: number }

-- The registry tracks every chunk that has been dispatched for generation.
-- We mark a chunk the moment we dispatch it; not when it finishes writing
-- because WriteVoxels is fire-and-forget and we never want to dispatch twice.
type ChunkRegistry = { [string]: boolean }

local dispatcher = weave.dispatcher.new(16, script.Parent["terrain-worker"])
local registry: ChunkRegistry = {}

-- Tracks the chunk the camera occupied last scan.
-- We use this to avoid re-scanning when the camera hasn't crossed a boundary.
local lastCameraChunk: ChunkCoord? = nil

local function worldToChunk(pos: Vector3): ChunkCoord
	return {
		x = math.floor(pos.X / CHUNK_SIZE),
		y = math.floor(pos.Y / CHUNK_SIZE),
		z = math.floor(pos.Z / CHUNK_SIZE),
	}
end

local function chunkKey(x: number, y: number, z: number): string
	-- String keys are the simplest way to do set membership checks for 3D coords.
	-- For very large worlds you could use a hash, but this is fine for typical render distances.
	return x .. "," .. y .. "," .. z
end

local function chunksAreEqual(a: ChunkCoord, b: ChunkCoord): boolean
	return a.x == b.x and a.y == b.y and a.z == b.z
end

RunService.Heartbeat:Connect(function()
	local camera: Camera = Workspace.CurrentCamera
	local cameraChunk: ChunkCoord = worldToChunk(camera.CFrame.Position)

	if lastCameraChunk and chunksAreEqual(cameraChunk, lastCameraChunk) then
		return
	end
	lastCameraChunk = cameraChunk

	local pending: { ChunkCoord } = {}

	for dx = -RENDER_DISTANCE, RENDER_DISTANCE do
		-- Vertical range is always centered at 0, not at the camera's Y chunk.
		-- This ensures terrain generates where the heightmap puts it,
		-- not wherever the camera happens to be floating.
		for dy = -VERTICAL_DISTANCE, VERTICAL_DISTANCE do
			for dz = -RENDER_DISTANCE, RENDER_DISTANCE do
				local cx: number = cameraChunk.x + dx
				local cy: number = dy -- fixed to world origin, not camera Y
				local cz: number = cameraChunk.z + dz
				local key: string = chunkKey(cx, cy, cz)

				if not registry[key] then
					registry[key] = true
					table.insert(pending, { x = cx, y = cy, z = cz })
				end
			end
		end
	end

	if #pending == 0 then
		return
	end
	dispatcher:DispatchDetached("GenerateChunk", #pending, nil, pending)
end)
```