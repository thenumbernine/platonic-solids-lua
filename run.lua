#!/usr/bin/env luajit
local cmdline = require 'ext.cmdline'(...)
local table = require 'ext.table'
local range = require 'ext.range'
local assert = require 'ext.assert'
local class = require 'ext.class'
local math = require 'ext.math'
local op = require 'ext.op'
local vector = require 'ffi.cpp.vector-lua'
local vec3f = require 'vec-ffi.vec3f'
local vec4i = require 'vec-ffi.vec4i'
local vec4f = require 'vec-ffi.vec4f'
local quatf = require 'vec-ffi.quatf'
local vec3x3f = require 'vec-ffi.vec3x3f'
local vec4x4f = require 'vec-ffi.vec4x4f'
local gl = require 'gl.setup'(cmdline.gl)
local GLTex2D = require 'gl.tex2d'
local GLFramebuffer = require 'gl.framebuffer'
local GLProgram = require 'gl.program'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLSceneObject = require 'gl.sceneobject'
local sdl = require 'sdl'
local ig = require 'imgui'


local App = require 'imgui.appwithorbit'():subclass()

local sqrt2 = math.sqrt(2)
local sqrt3 = math.sqrt(3)
local sqrt5 = math.sqrt(5)
local _1_sqrt3 = 1 / sqrt3


-- platonic solids
local shapes = {
	{
		name = 'tetrahedron',
		vs = vector(vec3f, {
			{0, 0, 1},
			{0, (2 * sqrt2) / 3, -1 / 3},
			{sqrt2 / sqrt3, -sqrt2 / 3, -1 / 3},
			{-sqrt2 / sqrt3, -sqrt2 / 3, -1 / 3},
		}),
		xformBasis = vector(vec3x3f, {
			{
				{-.5, -sqrt3/2, 0},
				{sqrt3/2, -.5, 0},
				{0, 0, 1},
			},
			{
				{-.5, -1/(2*sqrt3), -sqrt2/sqrt3},
				{1/(2*sqrt3), 5/6, -sqrt2/3},
				{sqrt2/sqrt3, -sqrt2/3, -1/3},
			},
		}),
	},
	{
		name = 'cube',
		vs = vector(vec3f, {
			{_1_sqrt3, _1_sqrt3, _1_sqrt3},
			{-_1_sqrt3, _1_sqrt3, _1_sqrt3},
			{_1_sqrt3, -_1_sqrt3, _1_sqrt3},
			{_1_sqrt3, _1_sqrt3, -_1_sqrt3},
			{-_1_sqrt3, -_1_sqrt3, _1_sqrt3},
			{-_1_sqrt3, _1_sqrt3, -_1_sqrt3},
			{_1_sqrt3, -_1_sqrt3, -_1_sqrt3},
			{-_1_sqrt3, -_1_sqrt3, -_1_sqrt3},
		}),
		xformBasis = vector(vec3x3f, {
			{
				{1, 0, 0},
				{0, 0, -1},
				{0, 1, 0},
			},
			{
				{0, 0, 1},
				{0, 1, 0},
				{-1, 0, 0},
			}
		}),
	},
	{
		name = 'octahedron',
		vs = vector(vec3f, {
			{1, 0, 0},
			{0, 0, 1},
			{0, 1, 0},
			{0, -1, 0},
			{0, 0, -1},
			{-1, 0, 0},
		}),
		xformBasis = vector(vec3x3f, {
			{{1, 0, 0}, {0, 0, -1}, {0, 1, 0}},
			{{0, 0, 1}, {0, 1, 0}, {-1, 0, 0}}
		}),
	},
	{
		name = 'dodecahedron',
		vs = vector(vec3f, {
			{(3 + sqrt5) / 2, -1, 0},
			{(1 + sqrt5) / 2, -(1 + sqrt5) / 2, (1 + sqrt5) / 2},
			{(3 + sqrt5) / 2, 1, 0},
			{(1 + sqrt5) / 2, -(1 + sqrt5) / 2, -(1 + sqrt5) / 2},
			{1, 0, (3 + sqrt5) / 2},
			{(1 + sqrt5) / 2, (1 + sqrt5) / 2, (1 + sqrt5) / 2},
			{0, -(3 + sqrt5) / 2, 1},
			{0, -(3 + sqrt5) / 2, -1},
			{(1 + sqrt5) / 2, (1 + sqrt5) / 2, -(1 + sqrt5) / 2},
			{1, 0, -(3 + sqrt5) / 2},
			{-1, 0, (3 + sqrt5) / 2},
			{-(1 + sqrt5) / 2, -(1 + sqrt5) / 2, (1 + sqrt5) / 2},
			{0, (3 + sqrt5) / 2, 1},
			{0, (3 + sqrt5) / 2, -1},
			{-(1 + sqrt5) / 2, -(1 + sqrt5) / 2, -(1 + sqrt5) / 2},
			{-1, 0, -(3 + sqrt5) / 2},
			{-(1 + sqrt5) / 2, (1 + sqrt5) / 2, (1 + sqrt5) / 2},
			{-(3 + sqrt5) / 2, -1, 0},
			{-(1 + sqrt5) / 2, (1 + sqrt5) / 2, -(1 + sqrt5) / 2},
			{-(3 + sqrt5) / 2, 1, 0}
		}):map(function(v)
			return v / math.sqrt((9 + 3 * sqrt5) / 2)
		end),
		xformBasis = vector(vec3x3f, {
			{	--  T3
				{(1+sqrt5)/4, 1/2, (1-sqrt5)/4},
				{-1/2, -(1-sqrt5)/4, -(1+sqrt5)/4},
				{(1-sqrt5)/4, (1+sqrt5)/4, 1/2},
			},
			{	-- T5
				{1/2, (1-sqrt5)/4, -(1+sqrt5)/4},
				{(1-sqrt5)/4, (1+sqrt5)/4, -1/2},
				{(1+sqrt5)/4, 1/2, -(1-sqrt5)/4},
			}
		}),
	},
	{
		name = 'icosahedron',
		vs = vector(vec3f, {
			{0, (-1+sqrt5)/4, 1/2},
			{1/2, 0, (-1+sqrt5)/4},
			{-1/2, 0, (-1+sqrt5)/4},
			{(-1+sqrt5)/4, 1/2, 0},
			{(1-sqrt5)/4, 1/2, 0},
			{0, (1-sqrt5)/4, 1/2},
			{0, (-1+sqrt5)/4, -1/2},
			{(-1+sqrt5)/4, -1/2, 0},
			{(1-sqrt5)/4, -1/2, 0},
			{1/2, 0, (1-sqrt5)/4},
			{-1/2, 0, (1-sqrt5)/4},
			{0, (1-sqrt5)/4, -1/2},
		}):map(function(v)
			return v / math.sqrt((5 - sqrt5) / 8)
		end),
		xformBasis = vector(vec3x3f, {
			{
				{(-1+sqrt5)/4, -(1+sqrt5)/4, -1/2},
				{(1+sqrt5)/4, 1/2, (1-sqrt5)/4},
				{1/2, (1-sqrt5)/4, (1+sqrt5)/4},
			},
			{
				{(1+sqrt5)/4, 1/2, (1-sqrt5)/4},
				{-1/2, (-1+sqrt5)/4, -(1+sqrt5)/4},
				{(1-sqrt5)/4, (1+sqrt5)/4, 1/2},
			},
		}),
	},
}

-- get maximum vector of n cross x y z basis dirs
-- i.e. max col/row of Levi-Civita w/ n
local function maxPerp(n)
	local x = n:cross(vec3f(1,0,0))
	local y = n:cross(vec3f(0,1,0))
	local z = n:cross(vec3f(0,0,1))
	local xSq = x:normSq()
	local ySq = y:normSq()
	local zSq = z:normSq()
	if xSq > ySq and xSq > zSq then
		return x:normalize()
	elseif ySq > xSq and ySq > zSq then
		return y:normalize()
	else
		return z:normalize()
	end
end

local function vecTo3x3Sep(n)
	local x = maxPerp(n)
	return x, n:cross(x)
end

local epsilon = 1e-3

-- store a subdivision of the mesh
-- but really this is just a mesh itself
-- should I use the .obj mesh class?
local Subdiv = class()
function Subdiv:init()
	self.edges = table()
	self.faces = table()
end

for _,shape in ipairs(shapes) do
	shape.vtxAdj = {}
	for i=1,#shape.vs do
		shape.vtxAdj[i] = {}
	end

	print('building edges')
	local visited = table()
	do
		local function translate(v)
			return vec4x4f():setTranslate(v:unpack())
		end

		local vInitIndex = 1
		local vInit = shape.vs.v[vInitIndex-1]

		-- init a 4x4 xform with the translation 'v' and rot 'xform', and use right-muls to traverse the surface
		-- then whatever vtxs its translation matches up with, use those for the adjacency graph
		local mInit = translate(vInit)

		local function recurse(m, vIndex)
			local visitedIndex = visited:find(nil, function(m1)
				return (m - m1):normSq() < epsilon
			end)

			if visitedIndex then return end
			visited:insert(m:clone())

			for _,xform in ipairs(shape.xformBasis) do
				local xform4x4 = vec4x4f(
					vec4f(xform.x:unpack()),
					vec4f(xform.y:unpack()),
					vec4f(xform.z:unpack()),
					vec4f(0,0,0,1)
				)
				local mNew = m * translate(-vInit) * xform4x4 * translate(vInit)

				-- assert storage is row-major
				local vNew = vec3f(mNew.x.w, mNew.y.w, mNew.z.w)
				local vIndexNew = table.find(shape.vs, nil, function(v1)
					return (vNew - v1):normSq() < epsilon
				end)
				if not vIndexNew then
					error('failed to find vertex '..vNew)
				end
				vIndexNew = vIndexNew + 1

				if vIndex ~= vIndexNew then
					shape.vtxAdj[vIndex][vIndexNew] = true
					shape.vtxAdj[vIndexNew][vIndex] = true
				end

				recurse(mNew, vIndexNew)
			end
		end
		recurse(mInit, vInitIndex)
	end

	-- ok now we have adjacency between neighboring vertexes
	-- next

	-- now that we have adjacency ...
	-- ... get surface polys from this
	-- ... subdivide them ...

	-- determine polys:
	-- group vtxs/edges by planar and traverse?
	print('building faces')
	shape.faces = table()	-- table of faces in-order
	local facesets = {}		-- sets of faces ,keys are faces-in-order concat with ,
	for i=1,#shape.vs do
		local function recurse(vtxIndexes, normal, flip)
			local i = vtxIndexes:last()
			for j=1,#shape.vs do
				local nextNormal = normal
				if i ~= j
				and (shape.vtxAdj[i][j] or shape.vtxAdj[j][i])
				then
					local offplane
					if #vtxIndexes >= 3 then
						local v1 = shape.vs.v[vtxIndexes[1]-1]
						if not nextNormal then
							local v2 = shape.vs.v[vtxIndexes[2]-1]
							local v3 = shape.vs.v[vtxIndexes[3]-1]
							nextNormal = (v3 - v2):cross(v2 - v1):normalize()
							flip = nextNormal:dot(v1) < 0		-- flip means flip the order of vtxs when you're done
							if flip then
								nextNormal = -nextNormal
							end
						end
						local v = shape.vs.v[j-1]
						if math.abs(((v - v1):normalize()):dot(nextNormal)) > .01 then
							offplane = true
						end
					end
					if not offplane then
						if j == vtxIndexes[1]
						and #vtxIndexes >= 3
						then
							-- only if all vtxs are on the same side of this
							local allOnOneSide = true
							local v1 = shape.vs.v[vtxIndexes[1]-1]
							for k=1,#shape.vs do
								local vk = shape.vs.v[k-1]
								local dist = (vk - v1):dot(nextNormal)
								if dist > epsilon then
									allOnOneSide = false
									break
								end
							end
							if allOnOneSide then
								local facekey = table(vtxIndexes):sort():concat','
								if not facesets[facekey] then
									facesets[facekey] = true
									shape.faces:insert(
										flip
										and table(vtxIndexes):reverse()
										or table(vtxIndexes)
									)
								end
							end
						else
							if not vtxIndexes:find(j) then
								local nextVtxIndexes = table(vtxIndexes)
								nextVtxIndexes:insert(j)
								recurse(nextVtxIndexes, nextNormal, flip)
							end
						end
					end
				end
			end
		end
		local vtxIndexes = table()
		vtxIndexes:insert(i)
		recurse(vtxIndexes)
	end


	local function vecToQuat(v)
		local x,y = vecTo3x3Sep(v:normalize())
		return quatf():fromMatrix{x,y,v}
	end

	local function vecTo4x4(z)
		z = z:normalize()
		local x, y = vecTo3x3Sep(z)
		-- if row major then transpose ...
		return vec4x4f(
			vec4f(x.x, y.x, z.x, z.x),
			vec4f(x.y, y.y, z.y, z.y),
			vec4f(x.z, y.z, z.z, z.z),
			vec4f(  0,   0,   0,   1)
		)
	end

	print('building basis')
	shape.qs = vector(vec4x4f, #shape.vs)
	for i=0,#shape.vs-1 do
		shape.qs.v[i] = vecTo4x4(shape.vs.v[i])
	end


	shape.vtxBaseCount = #shape.vs


	-- ok at this point ...
	-- subdivision ...
	shape.subdivs = table()

	-- maybe for subdivisions, maintaining adjacency doesn't matter, instead draw it with glPolygonMode
	-- https://en.wikipedia.org/wiki/Geodesic_polyhedron
	-- first subdivision of cube and dodecahedron needs to triangulation ...
	local n = #shape.faces[1]
	for _,face in ipairs(shape.faces) do
		assert.len(face, n)
	end

	-- goes slow, TODO use key hash
	shape.vtxForKey = {}
	local function vtxKey(v)
		return tostring(v:map(function(x) return 1e-3 * math.round(1e+3 * x) end))
	end

	print'building vtx keys'
	for i=1,#shape.vs do
		local v = shape.vs.v[i-1]
		shape.vtxForKey[vtxKey(v)] = i
	end

	local function findOrCreateVertex(v)
		local key = vtxKey(v)
		local i = shape.vtxForKey[key]
		if not i then
			i = #shape.vs + 1
			shape.vtxForKey[key] = i
			assert.eq(#shape.vs, #shape.qs)
			shape.vs:emplace_back()[0] = v
			shape.qs:emplace_back()[0] = vecTo4x4(v)
		end
		return i
	end

	print'building initial subdiv'
	if n == 3 then
		local subdiv = Subdiv()
		for i,face in ipairs(shape.faces) do
			subdiv.faces[i] = table(face)
		end
		shape.subdivs[1] = subdiv
	else
		local subdiv = Subdiv()
		for _,face in ipairs(shape.faces) do
			local vtxs = face:mapi(function(i) return shape.vs.v[i-1] end)
			local centerVtx = vtxs:sum() / #vtxs
			local centerIndex = findOrCreateVertex(centerVtx)
			for i=1,#face do
				local i1 = face[i]
				local i2 = face[(i % #face) + 1]
				subdiv.faces:insert{centerIndex, i1, i2}
			end
		end
		shape.subdivs:insert(subdiv)
		assert.len(shape.subdivs, 1)
	end

	-- ok now subdiv using "class 1"
	-- but really
	-- dodecahedron has 5-sided objects
	-- how do you do opposing vertexes on a face?
	for subdivIndex=2,6 do
print('building subdivIndex', subdivIndex)
		local subdiv = Subdiv()
--[[ divide the previous iterations
		for _,face in ipairs(shape.subdivs[subdivIndex-1].faces) do
			assert.len(face, 3)
			local edgeCenterIndexes = table()
			for i=1,#face do
				local i1 = face[i]
				local i2 = face[(i%#face)+1]
				local edgeCenterVtx = (shape.vs.v[i1-1] + shape.vs.v[i2-1]) * .5
				local edgeCenterIndex = findOrCreateVertex(edgeCenterVtx)
				edgeCenterIndexes:insert(edgeCenterIndex)
			end
			assert.len(edgeCenterIndexes, 3)
			local f1, f2, f3 = table.unpack(face)
			local e1, e2, e3 = edgeCenterIndexes:unpack()
			subdiv.faces:insert{e3, f1, e1}
			subdiv.faces:insert{e1, f2, e2}
			subdiv.faces:insert{e2, f3, e3}
			subdiv.faces:insert{e1, e2, e3}
		end
--]]
-- [[ redivide the original edge
		-- TODO barycentric subdivision
		for _,face in ipairs(shape.subdivs[1].faces) do
			local f1, f2, f3 = table.unpack(face)
			local v1 = shape.vs.v[f1-1]
			local v2 = shape.vs.v[f2-1]
			local v3 = shape.vs.v[f3-1]
			local edgeDivs = subdivIndex
			local patchVs = table()
			local patchIndexes = table()
			local da = v2 - v1
			local db = v3 - v1
			for i=0,edgeDivs  do
				local fi = i / edgeDivs
				patchIndexes[i] = patchIndexes[i] or {}
				for j=0,edgeDivs-i do
					local fj = j / edgeDivs
					local v = v1 + da * fi + db * fj
					patchIndexes[i][j] = findOrCreateVertex(v)
				end
			end
			for i=0,edgeDivs-1 do
				for j=0,edgeDivs-i-1 do
					if patchIndexes[i][j]
					and patchIndexes[i+1][j]
					and patchIndexes[i][j+1]
					then
						subdiv.faces:insert{
							patchIndexes[i][j],
							patchIndexes[i+1][j],
							patchIndexes[i][j+1],
						}
					end
					if patchIndexes[i][j+1]
					and patchIndexes[i+1][j]
					and patchIndexes[i+1][j+1]
					then
						subdiv.faces:insert{
							patchIndexes[i][j+1],
							patchIndexes[i+1][j],
							patchIndexes[i+1][j+1],
						}
					end
				end
			end
		end
--]]
		shape.subdivs:insert(subdiv)
		assert.len(shape.subdivs, subdivIndex)


		-- build vtxsUsedSet / vtxsUsedIndexes / edges
		subdiv.vtxsUsedSet = table()
		for _,face in ipairs(subdiv.faces) do
			for i,vi in ipairs(face) do
				subdiv.vtxsUsedSet[vi] = true
				local vi2 = face[(i % #face) + 1]
				subdiv.edges[vi] = subdiv.edges[vi] or {}
				subdiv.edges[vi][vi2] = true
				subdiv.edges[vi2] = subdiv.edges[vi2] or {}
				subdiv.edges[vi2][vi] = true
			end
		end
		subdiv.vtxsUsedIndexes = subdiv.vtxsUsedSet:keys():sort()


		-- build vtxNbhds
		subdiv.vtxNbhds = {}
		for _,vertexIndex in ipairs(subdiv.vtxsUsedIndexes) do

			-- TODO cache these in order per vertex
			local nbhdVtxIndexes = table()
			for nbhdVtxIndex in pairs(subdiv.edges[vertexIndex]) do
				if subdiv.vtxsUsedSet[nbhdVtxIndex] then
					nbhdVtxIndexes:insert(nbhdVtxIndex)
				end
			end

			-- now find basis for vertex
			-- sort by angle
			-- and find the one opposite this
			local xform = shape.qs.v[vertexIndex-1]
			
			-- TODO this would look better if qs was a 4x4 col-major, which I do define in numo9, I could put in vec-ffi ...
			local ex = vec3f(xform.x.x, xform.y.x, xform.z.x)
			local ey = vec3f(xform.x.y, xform.y.y, xform.z.y)

			nbhdVtxIndexes:sort(function(a,b)
				local va = shape.vs.v[a-1]
				local vb = shape.vs.v[b-1]
				return math.atan2(va * ey, va * ex)
					< math.atan2(vb * ey, vb * ex)
			end)
			subdiv.vtxNbhds[vertexIndex] = nbhdVtxIndexes
		end
	end

print'renormalizing'
	-- [[ normalize new vtxs
	for i=0,#shape.vs-1 do
		shape.vs.v[i] = shape.vs.v[i]:normalize()
	end
	--]]

print'done'
end

local vars = {
	numPlayers = 2,
	shapeIndex = 3,
	subdivIndex = 6,
	nextSubdivIndex = 6,	-- for gui until you start the next game
	numPieces = 1+12,
}

local playerTurn
local selectedIndex
local haveJumped
local players
local vtxPieces
local playerStartForVtxIndex

local colors = table{
	vec4f(1,0,0,1),
	vec4f(0,1,0,1),
	vec4f(0,0,1,1),
	vec4f(1,1,0,1),
	vec4f(1,0,1,1),
	vec4f(0,1,1,1),
}

function App:initGame()
	local shape = assert.index(shapes, vars.shapeIndex)
	local subdiv = shape.subdivs[vars.subdivIndex]

	vtxPieces = {}	-- map from vertex index to piece
	playerStartForVtxIndex = {}	-- map from vertex index to player index of starting locations

	players = table()
	for playerIndex=1,vars.numPlayers do
		local maxDist, vertexIndex
		for _,vi in ipairs(subdiv.vtxsUsedIndexes) do
			local v = shape.vs.v[vi-1]
			local dist = 0
			for _,oplayer in ipairs(players) do
				assert.le(1, oplayer.vertexIndex)
				assert.le(oplayer.vertexIndex, #shape.vs)
				local v2 = shape.vs.v[oplayer.vertexIndex-1]
				--[[
print(v, v2, 'dot', v * v2, 'acos', math.acos(v2 * v))
				dist = dist + math.acos(v2 * v)
				--]]
				-- [[
				dist = dist + (v2 - v):length()
				--]]
			end
			if not maxDist or maxDist < dist then
				maxDist = dist
				vertexIndex = vi
			end
		end
assert(vertexIndex)

		local player = {
			playerIndex = playerIndex,
			vertexIndex = vertexIndex,
			color = assert.index(colors, playerIndex),
		}
		players:insert(player)

		local v1 = shape.vs.v[vertexIndex-1]
		local vtxsSorted = table(subdiv.vtxsUsedIndexes)
			:sort(function(a,b)
				return shape.vs.v[a-1]:dot(v1) < shape.vs.v[b-1]:dot(v1)
			end)
			:sub(1, vars.numPieces)

		for _,vi in ipairs(vtxsSorted) do
			playerStartForVtxIndex[vi] = playerIndex
		end

		player.pieces = vtxsSorted
			:mapi(function(vi, i)
				return {
					index = i,
					playerIndex = playerIndex,
					vertexIndex = vi,
				}
			end)

		for _,piece in ipairs(player.pieces) do
			vtxPieces[piece.vertexIndex] = piece
		end
	end

	local function startTurn()
		selectedIndex = nil
		haveJumped = nil

		--[[ TODO slowly interpolate to ...
		local ez = shape.vs.v[players[playerTurn-1].vertexIndex]
		local ex, ey = vecTo3x3Sep(ez)
		self.view.angle:fromMatrix{ex, ey, ez}
		--]]
	end

	local function takeNextTurn()
		playerTurn = (playerTurn % vars.numPlayers) + 1
		startTurn()
	end

	playerTurn = 1
	selectedIndex = nil
	haveJumped = nil
	startTurn()

	onClick = function(x, y, playerIndex, pieceIndex, vertexIndex)
print('onClick x='..x
	..' y='..y
	..' playerIndex='..playerIndex
	..' pieceIndex='..pieceIndex
	..' vertexIndex='..vertexIndex
)
		local currentPlayer = assert.index(players, playerTurn)

		-- nothing is selected
		if not selectedIndex  then
			if playerTurn ~= playerIndex then return end
			selectedIndex = pieceIndex

		-- something is selected
		-- and we clicked the selected piece
		elseif selectedIndex == pieceIndex
		and playerTurn == playerIndex
		then
			selectedIndex = nil	-- deselect
			if haveJumped then
				takeNextTurn()
			end

		-- something is selected
		-- and we clicked somewhere else
		else
			local selectedPiece = assert.index(currentPlayer.pieces, selectedIndex)

			-- clicked somewhere one tile away
			if subdiv.edges[vertexIndex]
			and subdiv.edges[vertexIndex][selectedPiece.vertexIndex]
			then -- and make sure it's one edge distance from selectedIndex

				-- clicked somewhere one tile away and empty
				if playerIndex == -1
				and pieceIndex == -1
				then
					if not haveJumped then
						-- exchange places
						vtxPieces[selectedPiece.vertexIndex] = nil
						selectedPiece.vertexIndex = vertexIndex
						vtxPieces[vertexIndex] = selectedPiece
						takeNextTurn()
					end

				-- clicked somewhere one tile away and full
				else
					-- if it's another piece ...
					-- make sure it's one distance away ...
					-- then hop over it.

					--local otherPiecePlayer = assert.index(players, playerIndex)
					--local otherPiece = assert.index(otherPiecePlayer.pieces, pieceIndex)

					-- now find the next step past this piece
					print('clicked other piece')

					local nbhdVtxIndexes = subdiv.vtxNbhds[vertexIndex]

					print('source vertexIndex', selectedPiece.vertexIndex)
					print('clicked vertexIndex', vertexIndex)
					print('nbhd', nbhdVtxIndexes:concat', ')

					local i = nbhdVtxIndexes:find(selectedPiece.vertexIndex)
					assert(i, "the selected index vertex should be in the neighborhood")

					i = ((i-1 + math.floor(#nbhdVtxIndexes/2)) % #nbhdVtxIndexes) + 1

					local jumpToVtxIndex = nbhdVtxIndexes[i]

					if not vtxPieces[jumpToVtxIndex] then
						-- exchange places
						vtxPieces[selectedPiece.vertexIndex] = nil
						selectedPiece.vertexIndex = jumpToVtxIndex
						vtxPieces[jumpToVtxIndex] = selectedPiece
						haveJumped = true
					end
				end

			-- clicked somewhere more than one tile away
			else
				-- first make sure its empty
				if playerIndex == -1
				and pieceIndex == -1
				then
					-- then check all possible neighborhoods around the selected tile
					for _,nbhdVI in ipairs(subdiv.vtxNbhds[selectedPiece.vertexIndex]) do
						-- see if they have a piece
						if vtxPieces[nbhdVI] then
							-- and then  see if any of their neighborhoods include this vertex
							local nbhdVtxIndexes = subdiv.vtxNbhds[nbhdVI]

							local i = nbhdVtxIndexes:find(selectedPiece.vertexIndex)
							-- and if so, skip that piece
							if i then
								i = ((i-1 + math.floor(#nbhdVtxIndexes/2)) % #nbhdVtxIndexes) + 1

								local jumpToVtxIndex = nbhdVtxIndexes[i]

								if jumpToVtxIndex == vertexIndex then
									-- exchange places
									vtxPieces[selectedPiece.vertexIndex] = nil
									selectedPiece.vertexIndex = jumpToVtxIndex
									vtxPieces[jumpToVtxIndex] = selectedPiece
									haveJumped = true
								end
							end
						end
					end
				end
			end
		end
	end
end

local selectedPieceColor = vec4f(1, .75, .5, 1)
function App:initGL()
	App.super.initGL(self)


	local billboardPointVtxBuf = GLArrayBuffer{
		dim = 2,
		data = {-1, -1, 1, -1, -1, 1, 1, 1},
		usage = gl.GL_STATIC_DRAW,
	}:unbind()


	self.drawFBOObj = GLSceneObject{
		program = {
			version = 'latest',
			precision = 'best',
			vertexCode = [[
layout(location=0) in vec2 vertex;
out vec2 texcoordv;
void main() {
	texcoordv = vertex * .5 + .5;
	gl_Position = vec4(vertex, 0., 1.);
}
]],
			fragmentCode = [[
in vec2 texcoordv;
layout(location=0) out vec4 fragColor;
uniform sampler2D tex;
void main() {
	fragColor = texture(tex, texcoordv);
}
]],
		},
		uniforms = {
			tex = 0,
		},
		geometry = {
			mode = gl.GL_TRIANGLE_STRIP,
		},
		vertexes = billboardPointVtxBuf,
	}


	-- solid-color shader
	local lineProgram = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
layout(location=0) in vec3 vertex;
uniform mat4 modelMat;
uniform mat4 viewMat;
uniform mat4 projMat;
void main() {
	gl_Position = projMat * (viewMat * (modelMat * vec4(vertex, 1.)));
	gl_PointSize = 7.;
}
]],
		fragmentCode = [[
layout(location=0) out vec4 fragColor;
layout(location=1) out ivec4 fragID;
uniform ivec4 shapeID;
void main() {
	fragColor = vec4(0., 0., 0., 1.);
	fragID = shapeID;
}
]],
	}:useNone()


	-- really this is a cheap-diffuse-lighting shader (where normal = vertex)
	local faceProgram = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
layout(location=0) in vec3 vertex;
layout(location=0) out vec3 vertexv;
uniform mat4 modelMat;
uniform mat4 viewMat;
uniform mat4 projMat;
void main() {
	vertexv = (modelMat * vec4(vertex, 0.)).xyz;
	gl_Position = projMat * (viewMat * (modelMat * vec4(vertex, 1.)));
	gl_PointSize = 7.;
}
]],
		fragmentCode = [[
layout(location=0) in vec3 vertexv;
layout(location=0) out vec4 fragColor;
layout(location=1) out ivec4 fragID;
uniform vec4 color;
uniform ivec4 shapeID;
void main() {
	float dot = max(abs(normalize(vertexv).z), .3);
	fragColor = dot * color;
	fragID = shapeID;
}
]],
	}:useNone()


	self.modelMat = vec4x4f():setIdent()

	for _,shape in ipairs(shapes) do
		local vtxGPU = GLArrayBuffer{
			dim = 3,
			data = shape.vs.v,
			size = shape.vs:getNumBytes(),
			usage = gl.GL_STATIC_DRAW,
		}:unbind()

		for subdivIndex=0,#shape.subdivs do
			local subdiv = shape.subdivs[subdivIndex] or shape
			local faceGeoms = subdiv.faces:mapi(function(face)
				return {
					--mode = gl.GL_POLYGON,		-- not in GLES3
					mode = gl.GL_TRIANGLE_FAN,	-- GLES3
					indexes = {
						data = table.mapi(face, function(i) return i-1 end),
					},
				}
			end)

			subdiv.lineObj = GLSceneObject{
				program = lineProgram,
				vertexes = vtxGPU,
				geometries = faceGeoms,
				uniforms = {
					modelMat = self.modelMat.ptr,
					viewMat = self.view.mvMat.ptr,
					projMat = self.view.projMat.ptr,
					color = {1,1,1,1},
					shapeID = {-1,-1,-1,-1},
				},
			}
			subdiv.faceObj = GLSceneObject{
				program = faceProgram,
				vertexes = vtxGPU,
				geometries = faceGeoms,
				uniforms = {
					modelMat = self.modelMat.ptr,
					viewMat = self.view.mvMat.ptr,
					projMat = self.view.projMat.ptr,
					color = {1,1,1,1},
					shapeID = {-1,-1,-1,-1},
				},
			}
		end
	end

	self.placeObj = GLSceneObject{
		program = faceProgram,
		vertexes = {
			dim = 3,
			data = range(0,40*3-1):mapi(function(i)
				local j = i % 3
				local k = math.floor(i / 3)
				local th = k/40 * 2 * math.pi
				if j == 0 then
					return math.cos(th)
				elseif j == 1 then
					return math.sin(th)
				else
					return 0
				end
			end),
		},
		geometry = {
			mode = gl.GL_TRIANGLE_FAN,
		},
		uniforms = {
			modelMat = self.modelMat.ptr,
			viewMat = self.view.mvMat.ptr,
			projMat = self.view.projMat.ptr,
			color = {0,0,0,0},
			shapeID = {-1,-1,-1,-1},
		},
	}

	self:refreshFBO()

	-- these only work on desktop GL
	-- in GLES3 desktop, neither glPointSize nor gl_PointSize works
	-- in WebGL?
	if op.safeindex(gl, 'GL_PROGRAM_POINT_SIZE') then
		gl.glEnable(gl.GL_PROGRAM_POINT_SIZE)
	end
	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glLineWidth(2)

	self:initGame()
end

function App:resize(...)
	App.super.resize(self, ...)
	self:refreshFBO()
end



function App:refreshFBO()
	-- store color here
	self.colorFBOTex = GLTex2D{
		width = self.width,
		height = self.height,
		internalFormat = gl.GL_RGBA,
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}:unbind()

	-- write out IDs when you render to this texture
	-- use it for click for detecting
	self.clickIDFBOTex = GLTex2D{
		width = self.width,
		height = self.height,
		internalFormat = gl.GL_RGBA32I,
		magFilter = gl.GL_NEAREST,
		minFilter = gl.GL_NEAREST,
	}:unbind()


	self.drawFBOObj.texs[1] = self.colorFBOTex

	self.fbo = GLFramebuffer{
		width = self.width,
		height = self.height,
		useDepth = true,
	}
		:bind()
		-- TOOD how about together :setColorAttachmentsAndDrawBuffers to do both these things in one call?
		:setColorAttachmentTex2D(self.colorFBOTex.id, 0)
		:setColorAttachmentTex2D(self.clickIDFBOTex.id, 1)
		:drawBuffers(gl.GL_COLOR_ATTACHMENT0, gl.GL_COLOR_ATTACHMENT1)
		:unbind()
end


App.viewDist = 2

local clickShapeID = vec4i()

local clearShapeID = vec4i(-1,-1,-1,-1)
local clearColor = vec4f(1,1,1,1)
local shapeID = vec4i(-1,-1,-1,-1)

function App:update(...)
	self.fbo:bind()
	assert(self.fbo:check())

	gl.glClearColor(1,1,1,1)
	gl.glClearBufferfv(gl.GL_COLOR_BUFFER_BIT, 0, clearColor.s)
	gl.glClearBufferiv(gl.GL_COLOR_BUFFER_BIT, 1, clearShapeID.s)

	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))
--	gl.glClear(gl.GL_DEPTH_BUFFER_BIT)
	gl.glEnable(gl.GL_DEPTH_TEST)


	self.modelMat:setIdent()

	local shape = shapes[vars.shapeIndex]
	local subdiv = shape.subdivs[vars.subdivIndex] or shape
	if subdiv then
		subdiv.faceObj:draw()
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		subdiv.lineObj:draw()
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
		-- TODO TODO
		-- also draw the dual's vertexIndex so we can click the shape surface
	end

	for _,vi in ipairs(subdiv.vtxsUsedIndexes) do
		local piece = vtxPieces[vi]
		local piecePlayerIndex = -1
		local pieceIndex = -1
		local color
		local globj
		if piece then
			piecePlayerIndex = piece.playerIndex
			pieceIndex = piece.index
			if selectedIndex == pieceIndex
			and piecePlayerIndex == playerTurn
			then
				color = selectedPieceColor.s
			else
				color = players[piecePlayerIndex].color.s
			end
			globj = shapes[5].subdivs[6].faceObj
		else
			local startPlayerIndex = playerStartForVtxIndex[vi]
			if startPlayerIndex then
				color = {.5, .5, .5, 0}
			else
				-- in this case, don't draw any color, instead skip the color write
				-- until I figure out how to skip color write. ..
				-- .... set it black
				color = {0,0,0,0}
			end
			globj = self.placeObj
		end
		shapeID:set(piecePlayerIndex, pieceIndex, vi, 0)

		self.modelMat
			--:setIdent()
			--:setTranslate(shape.vs.v[vi-1]:unpack())
			:copy(shape.qs.v[vi-1])
			:applyScale(.07, .07, .07)

		-- TODO this doesn't work
		-- how to make it just write the shapeID but not the color?
		if not color then
			self.fbo:drawBuffers(gl.GL_COLOR_ATTACHMENT1)
		end

		globj:draw{
			uniforms = {
				color = color,
				shapeID = shapeID.s,
			},
		}

		if not color then
			self.fbo:drawBuffers(gl.GL_COLOR_ATTACHMENT0, gl.GL_COLOR_ATTACHMENT1)
		end
	end


	local mx = self.mouse.ipos.x
	local my = self.height - 1 - self.mouse.ipos.y
	gl.glReadBuffer(gl.GL_COLOR_ATTACHMENT1)
	gl.glReadPixels(mx, my, 1, 1, self.clickIDFBOTex.format, self.clickIDFBOTex.type, clickShapeID.s)
	gl.glReadBuffer(gl.GL_BACK)


	self.fbo:unbind()

	gl.glDisable(gl.GL_DEPTH_TEST)
	self.drawFBOObj:draw()

	App.super.update(self, ...)
end

function App:updateGUI()
	if ig.igBeginMainMenuBar() then
		if ig.igBeginMenu'New Game' then
			ig.luatableInputInt('subdiv', vars, 'nextSubdivIndex')
			for shapeIndex,shape in ipairs(shapes) do
				if ig.igButton(shape.name) then
					vars.subdivIndex = vars.nextSubdivIndex
					vars.shapeIndex = shapeIndex
					self:initGame()
				end
			end

			ig.igEndMenu()
		end
		ig.igEndMainMenuBar()
	end
end

function App:event(e)
	App.super.event(self, e)

	-- same as in glapp.orbit
	local canHandleMouse = not ig.igGetIO()[0].WantCaptureMouse
	local canHandleKeyboard = not ig.igGetIO()[0].WantCaptureKeyboard

	if canHandleMouse then
		if e[0].type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN then
			if e[0].button.button == 1 then
				if onClick then
					onClick(
						tonumber(e[0].button.x)/self.width,
						tonumber(e[0].button.y)/self.height,
						clickShapeID:unpack()
					)
				end
			end
		end
	end
end

App():run()
