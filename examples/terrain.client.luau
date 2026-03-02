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
