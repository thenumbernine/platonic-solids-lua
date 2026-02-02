#!/usr/bin/env luajit
local table = require 'ext.table'
local assert = require 'ext.assert'
local gl = require 'gl'
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
end

function App:initGL()
	App.super.initGL(self)
	gl.glClearColor(1,1,1,1)
	
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

		local indexes = table()
		for i=1,#shape.vs-1 do
			for j=i+1,#shape.vs do
				if (shape.vtxAdj[i] and shape.vtxAdj[i][j])
				or (shape.vtxAdj[j] and shape.vtxAdj[j][i])
				then
					indexes:insert(i-1)
					indexes:insert(j-1)
				end
			end
		end

		shape.globj = GLSceneObject{
			program = {
				version = 'latest',
				precision = 'best',
				vertexCode = [[
layout(location=0) in vec3 vertex;
layout(location=0) uniform mat4 mvProjMat;
void main() {
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
				fragmentCode = [[
layout(location=0) out vec4 fragColor;
void main() {
	fragColor = vec4(0., 0., 0., 1.);
}
]],
			},
			vertexes = vtxGPU,
			geometries = {
				{
					mode = gl.GL_POINTS,
				},
				{
					mode = gl.GL_LINES,
					indexes = {
						data = indexes,
					},
				},
			},
		}
	end
end

App.viewDist = 2

function App:update(...)
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)
	self.view:setup(self.width / self.height)

	gl.glEnable(gl.GL_BLEND)
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ZERO)
	gl.glEnable(gl.GL_POINT_SMOOTH)
	gl.glPointSize(3)
	
	local shape = shapes[shapeIndex]
	shape.globj.uniforms.mvProjMat = self.view.mvProjMat.ptr,
	shape.globj:draw()

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
			ig.igEndMenu()
		end
		ig.igEndMainMenuBar()
	end
end

App():run()
