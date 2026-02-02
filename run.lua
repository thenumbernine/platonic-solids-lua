#!/usr/bin/env luajit
local cmdline = require 'ext.cmdline'(...)
local table = require 'ext.table'
local assert = require 'ext.assert'
local op = require 'ext.op'
local gl = require 'gl.setup'(cmdline.gl)
local GLProgram = require 'gl.program'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLSceneObject = require 'gl.sceneobject'
local ig = require 'imgui'
local matrix = require 'matrix'

local App = require 'imgui.appwithorbit'():subclass()

local shapeIndex = 1

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

	if n == 3 then
		shape.subdivs[1] = shape.faces:mapi(function(face) return table(face) end)
	else
		local subdiv = table()
		for _,face in ipairs(shape.faces) do
			local vtxs = face:mapi(function(i) return shape.vs[i] end)
			local centerVtx = vtxs:sum() / #vtxs 
			local centerIndex = #shape.vs + 1
			shape.vs[centerIndex] = centerVtx
			for i=1,#face do
				local i1 = face[i]
				local i2 = face[(i%#face)+1]
				subdiv:insert{centerIndex, i1, i2}
			end
		end
		shape.subdivs:insert(subdiv)
		assert.len(shape.subdivs, 1)
	end

	-- ok now subdiv using "class 1"
	-- but really
	-- dodecahedron has 5-sided objects
	-- how do you do opposing vertexes on a face?
	for subdivIndex=2,5 do
		local subdiv = table()
		for _,face in ipairs(shape.subdivs[subdivIndex-1]) do
			assert.len(face, 3)
			local edgeCenterIndexes = table()
			for i=1,#face do
				local i1 = face[i]
				local i2 = face[(i%#face)+1]
				local edgeCenterVtx = (shape.vs[i1] + shape.vs[i2]) * .5
				local edgeCenterIndex = #shape.vs + 1
				edgeCenterIndexes:insert(edgeCenterIndex)
				shape.vs[edgeCenterIndex] = edgeCenterVtx
			end
			assert.len(edgeCenterIndexes, 3)
			local f1, f2, f3 = table.unpack(face)
			local e1, e2, e3 = edgeCenterIndexes:unpack()
			subdiv:insert{e3, f1, e1}	
			subdiv:insert{e1, f2, e2}
			subdiv:insert{e2, f3, e3}
			subdiv:insert{e1, e2, e3}
		end
		shape.subdivs:insert(subdiv)
		assert.len(shape.subdivs, subdivIndex)
	end

	-- normalize new vtxs
	for i=1,#shape.vs do
		shape.vs[i] = shape.vs[i]:normalize()
	end
end

local vars = {
	subdivIndex = 0,
}
function App:initGL()
	App.super.initGL(self)
	gl.glClearColor(1,1,1,1)

	local lineProgram = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
layout(location=0) in vec3 vertex;
uniform mat4 mvMat;
uniform mat4 projMat;
void main() {
	gl_Position = projMat * (mvMat * vec4(vertex, 1.));
	gl_PointSize = 7.;
}
]],
		fragmentCode = [[
layout(location=0) out vec4 fragColor;
void main() {
	fragColor = vec4(0., 0., 0., 1.);
}
]],
	}:useNone()

	local faceProgram = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
layout(location=0) in vec3 vertex;
layout(location=0) out vec3 vertexv;
uniform mat4 mvMat;
uniform mat4 projMat;
void main() {
	vertexv = (mvMat * vec4(vertex, 0.)).xyz;
	gl_Position = projMat * (mvMat * vec4(vertex, 1.));
	gl_PointSize = 7.;
}
]],
		fragmentCode = [[
layout(location=0) in vec3 vertexv;
layout(location=0) out vec4 fragColor;
void main() {
	float dot = max(abs(normalize(vertexv).z), .3);
	fragColor = vec4(dot, 0., 0., 1.);
}
]],
	}:useNone()

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
						mvMat = self.view.mvMat.ptr,
						projMat = self.view.projMat.ptr,
					},
				},
				faceObj = GLSceneObject{
					program = faceProgram,
					vertexes = vtxGPU,
					geometries = faceGeoms,
					uniforms = {
						mvMat = self.view.mvMat.ptr,
						projMat = self.view.projMat.ptr,
					},
				},
			}
		end

	end

	-- these only work on desktop GL
	-- in GLES3 desktop, neither glPointSize nor gl_PointSize works
	-- in WebGL?
	if op.safeindex(gl, 'GL_PROGRAM_POINT_SIZE') then
		gl.glEnable(gl.GL_PROGRAM_POINT_SIZE)
	end
	gl.glEnable(gl.GL_DEPTH_TEST)
end

App.viewDist = 2

function App:update(...)
	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	local shape = shapes[shapeIndex]
	local shapeObjs = shape.subdivObjs[vars.subdivIndex]
	if shapeObjs then
		shapeObjs.faceObj:draw()
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		shapeObjs.lineObj:draw()
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
	end

	App.super.update(self, ...)
end

function App:updateGUI()
	if ig.igBeginMainMenuBar() then
		if ig.igBeginMenu'shape' then
			for i,shape in ipairs(shapes) do
				if ig.igButton(shape.name) then
					shapeIndex = i
				end
			end
			
			ig.luatableInputInt('subdiv', vars, 'subdivIndex')
			ig.igEndMenu()
		end
		ig.igEndMainMenuBar()
	end
end

App():run()
