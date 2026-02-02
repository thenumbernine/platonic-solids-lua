#!/usr/bin/env luajit
local cmdline = require 'ext.cmdline'(...)
local table = require 'ext.table'
local range = require 'ext.range'
local assert = require 'ext.assert'
local math = require 'ext.math'
local op = require 'ext.op'
local vec4i = require 'vec-ffi.vec4i'	-- or ui?
local vec4f = require 'vec-ffi.vec4f'
local vec4x4f = require 'vec-ffi.vec4x4f'
local gl = require 'gl.setup'(cmdline.gl)
local GLTex2D = require 'gl.tex2d'
local GLFramebuffer = require 'gl.framebuffer'
local GLProgram = require 'gl.program'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLSceneObject = require 'gl.sceneobject'
local sdl = require 'sdl'
local ig = require 'imgui'
local matrix = require 'matrix'

local App = require 'imgui.appwithorbit'():subclass()

local sqrt2 = math.sqrt(2)
local sqrt3 = math.sqrt(3)
local sqrt5 = math.sqrt(5)
local _1_sqrt3 = 1 / sqrt3

local shapes = {
	{
		name = 'tetrahedron',
		vs = matrix{
			{0, 0, 1},
			{0, (2 * sqrt2) / 3, -1 / 3},
			{sqrt2 / sqrt3, -sqrt2 / 3, -1 / 3},
			{-sqrt2 / sqrt3, -sqrt2 / 3, -1 / 3},
		},
		xformBasis = {
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
		},
	},
	{
		name = 'cube',
		vs = matrix{
			{_1_sqrt3, _1_sqrt3, _1_sqrt3},
			{-_1_sqrt3, _1_sqrt3, _1_sqrt3},
			{_1_sqrt3, -_1_sqrt3, _1_sqrt3},
			{_1_sqrt3, _1_sqrt3, -_1_sqrt3},
			{-_1_sqrt3, -_1_sqrt3, _1_sqrt3},
			{-_1_sqrt3, _1_sqrt3, -_1_sqrt3},
			{_1_sqrt3, -_1_sqrt3, -_1_sqrt3},
			{-_1_sqrt3, -_1_sqrt3, -_1_sqrt3},
		},
		xformBasis = {
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
		},
	},
	{
		name = 'octahedron',
		vs = matrix{
			{1, 0, 0},
			{0, 0, 1},
			{0, 1, 0},
			{0, -1, 0},
			{0, 0, -1},
			{-1, 0, 0},
		},
		xformBasis = {
			{{1, 0, 0}, {0, 0, -1}, {0, 1, 0}},
			{{0, 0, 1}, {0, 1, 0}, {-1, 0, 0}}
		}
	},
	{
		name = 'dodecahedron',
		vs = matrix{
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
		} / math.sqrt((9 + 3 * sqrt5) / 2),
		xformBasis = {
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
		},
	},
	{
		name = 'icosahedron',
		vs = matrix{
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
		} / math.sqrt((5 - sqrt5) / 8),
		xformBasis = {
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
		},
	},
}

local epsilon = 1e-3
for _,shape in ipairs(shapes) do
	for i=1,#shape.vs do
		shape.vs[i] = matrix(shape.vs[i])
	end
	for i=1,#shape.xformBasis do
		shape.xformBasis[i] = matrix(shape.xformBasis[i])
	end
end

for _,shape in ipairs(shapes) do
	shape.vtxAdj = {}
	for i=1,#shape.vs do
		shape.vtxAdj[i] = {}
	end

	local visited = table()
	do
		local function translate(v)
			return matrix{
				{1,0,0,v[1]},
				{0,1,0,v[2]},
				{0,0,1,v[3]},
				{0,0,0,1}
			}
		end

		local vInitIndex = 1
		local vInit = shape.vs[vInitIndex]

		-- init a 4x4 xform with the translation 'v' and rot 'xform', and use right-muls to traverse the surface
		-- then whatever vtxs its translation matches up with, use those for the adjacency graph
		local mInit = translate(vInit)

		local function recurse(m, vIndex)
			local visitedIndex = table.find(visited, nil, function(m1)
				return (m - m1):normSq() < epsilon
			end)

			if visitedIndex then return end
			visited:insert(m:clone())

			for _,xform in ipairs(shape.xformBasis) do
				local xform4x4 = matrix{4,4}:lambda(function(i,j)
					if i<=3 and j<=3 then return xform[i][j] end
					return i==j and 1 or 0
				end)
				mNew = m * translate(-vInit) * xform4x4 * translate(vInit)

				local vNew = matrix{3}:lambda(function(i) return mNew[i][4] end)
				local vIndexNew = table.find(shape.vs, nil, function(v1)
					return (vNew - v1):normSq() < epsilon
				end)
				if not vIndexNew then
					error('failed to find vertex '..vNew)
				end

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
						local v1 = shape.vs[vtxIndexes[1]]
						if not nextNormal then
							local v2 = shape.vs[vtxIndexes[2]]
							local v3 = shape.vs[vtxIndexes[3]]
							nextNormal = (v3 - v2):cross(v2 - v1):normalize()
							flip = nextNormal:dot(v1) < 0		-- flip means flip the order of vtxs when you're done
							if flip then
								nextNormal = -nextNormal
							end
						end
						local v = shape.vs[j]
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
							local v1 = shape.vs[vtxIndexes[1]]
							for k,vk in ipairs(shape.vs) do
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
		local x,y,z = v:unpack()
		x = 1e-3 * math.round(1e+3 * x)
		y = 1e-3 * math.round(1e+3 * y)
		z = 1e-3 * math.round(1e+3 * z)
		return table{x,y,z}:concat','
	end
	for i,v in ipairs(shape.vs) do
		shape.vtxForKey[vtxKey(v)] = i
	end
	local function findOrCreateVertex(v)
		local key = vtxKey(v)
		local i = shape.vtxForKey[key]
		if not i then
			i = #shape.vs + 1
			shape.vtxForKey[key] = i
			shape.vs[i] = matrix(v)
		end
		return i
	end

	local function setFaceAdj(subdiv, i,j,k)
		subdiv.vtxAdj = subdiv.vtxAdj or {}
		subdiv.vtxAdj[i] = subdiv.vtxAdj[i] or {}
		subdiv.vtxAdj[j] = subdiv.vtxAdj[j] or {}
		subdiv.vtxAdj[k] = subdiv.vtxAdj[k] or {}
		subdiv.vtxAdj[i][j] = true
		subdiv.vtxAdj[j][i] = true
		subdiv.vtxAdj[i][k] = true
		subdiv.vtxAdj[k][i] = true
		subdiv.vtxAdj[j][k] = true
		subdiv.vtxAdj[k][j] = true
	end

	if n == 3 then
		local subdiv = table()
		for i,face in ipairs(shape.faces) do
			setFaceAdj(subdiv, table.unpack(face))
			subdiv[i] = table(face)
		end
		shape.subdivs[1] = subdiv
	else
		local subdiv = table()
		for _,face in ipairs(shape.faces) do
			local vtxs = face:mapi(function(i) return shape.vs[i] end)
			local centerVtx = vtxs:sum() / #vtxs
			local centerIndex = findOrCreateVertex(centerVtx)
			for i=1,#face do
				local i1 = face[i]
				local i2 = face[(i % #face) + 1]
				subdiv:insert{centerIndex, i1, i2}
				setFaceAdj(subdiv, centerIndex, i1, i2)
			end
		end
		shape.subdivs:insert(subdiv)
		assert.len(shape.subdivs, 1)
	end

	-- ok now subdiv using "class 1"
	-- but really
	-- dodecahedron has 5-sided objects
	-- how do you do opposing vertexes on a face?
	for subdivIndex=2,10 do
print('subdivIndex', subdivIndex)
		local subdiv = table()
--[[ divide the previous iterations
		for _,face in ipairs(shape.subdivs[subdivIndex-1]) do
			assert.len(face, 3)
			local edgeCenterIndexes = table()
			for i=1,#face do
				local i1 = face[i]
				local i2 = face[(i%#face)+1]
				local edgeCenterVtx = (shape.vs[i1] + shape.vs[i2]) * .5
				local edgeCenterIndex = findOrCreateVertex(edgeCenterVtx)
				edgeCenterIndexes:insert(edgeCenterIndex)
			end
			assert.len(edgeCenterIndexes, 3)
			local f1, f2, f3 = table.unpack(face)
			local e1, e2, e3 = edgeCenterIndexes:unpack()
			subdiv:insert{e3, f1, e1}
			setFaceAdj(subdiv, e3, f1, e1)
			subdiv:insert{e1, f2, e2}
			setFaceAdj(subdiv, e1, f2, e2)
			subdiv:insert{e2, f3, e3}
			setFaceAdj(subdiv, e2, f3, e3)
			subdiv:insert{e1, e2, e3}
			setFaceAdj(subdiv, e1, e2, e3)
		end
--]]
-- [[ redivide the original edge
		-- TODO barycentric subdivision
		for _,face in ipairs(shape.subdivs[1]) do
			local f1, f2, f3 = table.unpack(face)
			local v1 = shape.vs[f1]
			local v2 = shape.vs[f2]
			local v3 = shape.vs[f3]
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
						subdiv:insert{
							patchIndexes[i][j],
							patchIndexes[i+1][j],
							patchIndexes[i][j+1],
						}
						setFaceAdj(
							subdiv, 
							patchIndexes[i][j],
							patchIndexes[i+1][j],
							patchIndexes[i][j+1]
						)
					end
					if patchIndexes[i][j+1]
					and patchIndexes[i+1][j]
					and patchIndexes[i+1][j+1]
					then
						subdiv:insert{
							patchIndexes[i][j+1],
							patchIndexes[i+1][j],
							patchIndexes[i+1][j+1],
						}
						setFaceAdj(
							subdiv, 
							patchIndexes[i][j+1],
							patchIndexes[i+1][j],
							patchIndexes[i+1][j+1]
						)
					end
				end
			end
		end
--]]
		shape.subdivs:insert(subdiv)
		assert.len(shape.subdivs, subdivIndex)
	end

	-- [[ normalize new vtxs
	for i=1,#shape.vs do
		shape.vs[i] = shape.vs[i]:normalize()
	end
	--]]
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
local players
local vtxsUsed
local vtxPieces 

local colors = table{
	vec4f(1,0,0,1),
	vec4f(0,1,0,1),
	vec4f(0,0,1,1),
	vec4f(1,1,0,1),
	vec4f(1,0,1,1),
	vec4f(0,1,1,1),
}

local function initGame()
	local shape = assert.index(shapes, vars.shapeIndex)

	local faces = shape.subdivs[vars.subdivIndex]
	vtxsUsed = {}
	for _,face in ipairs(faces) do
		for _,vi in ipairs(face) do
			vtxsUsed[vi] = true
		end
	end

	vtxPieces = {}	-- map from vertex index to piece

	selectedIndex = nil

	players = table()
	for playerIndex=1,vars.numPlayers do
		local vtxDists = range(#shape.vs):mapi(function(i)
			local v = shape.vs[i]
			local dist = 0
			for _,oplayer in ipairs(players) do
				dist = dist + (shape.vs[oplayer.vertexIndex] - v):norm()	-- TODO arclen
			end
			return dist
		end)
		local vertexIndex = select(2, table.sup(vtxDists))
assert(vertexIndex)

		local player = {
			playerIndex = playerIndex,
			vertexIndex = vertexIndex,
			color = assert.index(colors, playerIndex),
		}
		players:insert(player)

		local v1 = shape.vs[vertexIndex]
		local vtxsSorted = table.keys(vtxsUsed)
		vtxsSorted:sort(function(a,b)
			return shape.vs[a]:dot(v1) < shape.vs[b]:dot(v1)
		end)

		player.pieces = vtxsSorted
			:sub(1, vars.numPieces)
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

	playerTurn = 1
	onClick = function(x, y, playerIndex, pieceIndex, vertexIndex)
print('onClick', x, y, playerIndex, pieceIndex, vertexIndex)
		local currentPlayer = assert.index(players, playerTurn)
		if not selectedIndex  then
			if playerTurn ~= playerIndex then return end

			selectedIndex = pieceIndex
		elseif selectedIndex == pieceIndex then
			selectedIndex = nil
		else
			local selectedPiece = assert.index(currentPlayer.pieces, selectedIndex)

			local subdiv = shape.subdivs[vars.subdivIndex]
			if subdiv.vtxAdj[vertexIndex][selectedPiece.vertexIndex] then -- and make sure it's one edge distance from selectedIndex
				if playerIndex == -1
				and pieceIndex == -1
				then
					-- exchange places

					vtxPieces[selectedPiece.vertexIndex] = nil
					selectedPiece.vertexIndex = vertexIndex
					vtxPieces[vertexIndex] = selectedPiece

					selectedIndex = nil
				else
					-- if it's another piece ...
					-- make sure it's one distance away ...
					-- then hop over it.
				
					local otherPiecePlayer = assert.index(players, playerIndex)
					local otherPiece = assert.index(otherPiecePlayer.pieces, pieceIndex)
					
					-- now find the next step past this piece
					print('clicked other piece')

					local nbhdVtxIndexes = table()
					for nbhdVtxIndex in pairs(subdiv.vtxAdj[vertexIndex]) do
						if vtxsUsed[nbhdVtxIndex] then
							nbhdVtxIndexes:insert(nbhdVtxIndex)
						end
					end
			
					print('nbhd', nbhdVtxIndexes:concat', ')
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
uniform sampler2D fboTex;
void main() {
	fragColor = texture(fboTex, texcoordv);
}
]],
		},
		uniforms = {
			fboTex = 0,
		},
		geometry = {
			mode = gl.GL_TRIANGLE_STRIP,
		},
		vertexes = billboardPointVtxBuf,
	}



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

		local vtxs = table()
		for _,v in ipairs(shape.vs) do
			for j,x in ipairs(v) do
				vtxs:insert(x)
			end
		end
		local vtxGPU = GLArrayBuffer{
			dim = 3,
			data = vtxs,
			usage = gl.GL_STATIC_DRAW,
		}:unbind()

		shape.subdivObjs = table()
		for subdivIndex=0,#shape.subdivs do
			local faceGeoms = (shape.subdivs[subdivIndex] or shape.faces):mapi(function(face)
				return {
					--mode = gl.GL_POLYGON,		-- not in GLES3
					mode = gl.GL_TRIANGLE_FAN,	-- GLES3
					indexes = {
						data = table.mapi(face, function(i) return i-1 end),
					},
				}
			end)

			shape.subdivObjs[subdivIndex] = {
				lineObj = GLSceneObject{
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
				},
				faceObj = GLSceneObject{
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
				},
			}
		end
	end


	self:refreshFBO()
	
	-- these only work on desktop GL
	-- in GLES3 desktop, neither glPointSize nor gl_PointSize works
	-- in WebGL?
	if op.safeindex(gl, 'GL_PROGRAM_POINT_SIZE') then
		gl.glEnable(gl.GL_PROGRAM_POINT_SIZE)
	end
	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glLineWidth(2)

	initGame(2)
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
	local shapeObj = shape.subdivObjs[vars.subdivIndex]
	if shapeObj then
		shapeObj.faceObj:draw()
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		shapeObj.lineObj:draw()
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
	end

	for vi in pairs(vtxsUsed) do
		local piece = vtxPieces[vi]
		local playerIndex = -1
		local pieceIndex = -1
		local color
		if piece then
			playerIndex = piece.playerIndex
			pieceIndex = piece.index
			if selectedIndex == pieceIndex then
				color = selectedPieceColor.s
			else
				color = players[playerIndex].color.s
			end
		else
			color = {0,0,0,0}
		end
		shapeID:set(playerIndex, pieceIndex, vi, 0)

		self.modelMat
			:setIdent()
			:setTranslate(shape.vs[vi]:unpack())
			:applyScale(.1, .1, .1)

		shapes[5].subdivObjs[0].faceObj:draw{
			uniforms = {
				color = color,
				shapeID = shapeID.s,
			},
		}
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
					initGame()
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
