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
