#!/usr/bin/env luajit
local table = require 'ext.table'
local gl = require 'gl'
local ig = require 'imgui'
local matrix = require 'matrix'

local App = require 'imguiapp.withorbit'():subclass()


local shapeIndex = 1

local sqrt2 = math.sqrt(2)
local sqrt3 = math.sqrt(3)

local shapes = {
	{
		name = 'tetrahedron',
		vs = matrix{
			{0, 0, 1},
			{0, (2 * sqrt2) / 3, -1 / 3},
			{sqrt2 / sqrt3, -sqrt2 / 3, -1 / 3},
			{-sqrt2 / sqrt3, -sqrt2 / 3, -1 / 3},
		},
		vtxMulTable = {
			{1, 2, 3, 4},	-- {j}, for T1 * v_i = v_j
			{4, 2, 1, 3},
			{1, 4, 2, 3},
			{3, 2, 4, 1},
			{3, 4, 1, 2},
			{2, 4, 3, 1},
			{1, 3, 4, 2},
			{2, 3, 1, 4},
			{4, 3, 2, 1},
			{4, 1, 3, 2},
			{2, 1, 4, 3},
			{3, 1, 2, 4}
		}
	},
	{
		name = 'cube',
		vs = matrix{{1, 1, 1}, {-1, 1, 1}, {1, -1, 1}, {1, 1, -1}, {-1, -1, 1}, {-1, 1, -1}, {1, -1, -1}, {-1, -1, -1}},
		vtxMulTable = {
			{1, 2, 3, 4, 5, 6, 7, 8},
			{3, 5, 7, 1, 8, 2, 4, 6},
			{4, 1, 7, 6, 3, 2, 8, 5},
			{7, 8, 4, 3, 6, 5, 1, 2},
			{7, 3, 8, 4, 5, 1, 6, 2},
			{4, 6, 1, 7, 2, 8, 3, 5},
			{8, 5, 6, 7, 2, 3, 4, 1},
			{4, 7, 6, 1, 8, 3, 2, 5},
			{8, 7, 5, 6, 3, 4, 2, 1},
			{6, 2, 4, 8, 1, 5, 7, 3},
			{6, 8, 2, 4, 5, 7, 1, 3},
			{5, 3, 2, 8, 1, 7, 6, 4},
			{1, 4, 2, 3, 6, 7, 5, 8},
			{6, 4, 8, 2, 7, 1, 5, 3},
			{5, 8, 3, 2, 7, 6, 1, 4},
			{2, 5, 1, 6, 3, 8, 4, 7},
			{2, 1, 6, 5, 4, 3, 8, 7},
			{2, 6, 5, 1, 8, 4, 3, 7},
			{3, 7, 1, 5, 4, 8, 2, 6},
			{3, 1, 5, 7, 2, 4, 8, 6},
			{8, 6, 7, 5, 4, 2, 3, 1},
			{1, 3, 4, 2, 7, 5, 6, 8},
			{5, 2, 8, 3, 6, 1, 7, 4},
			{7, 4, 3, 8, 1, 6, 5, 2}
		},
	},
	{
		name = 'octahedron',
		vs = matrix{{1, 0, 0}, {0, 0, 1}, {0, 1, 0}, {0, -1, 0}, {0, 0, -1}, {-1, 0, 0}},
		vtxMulTable={
			{1, 2, 3, 4, 5, 6},
			{1, 4, 2, 5, 3, 6},
			{5, 1, 3, 4, 6, 2},
			{1, 5, 4, 3, 2, 6},
			{5, 4, 1, 6, 3, 2},
			{1, 3, 5, 2, 4, 6},
			{5, 6, 4, 3, 1, 2},
			{3, 5, 1, 6, 2, 4},
			{6, 4, 5, 2, 3, 1},
			{5, 3, 6, 1, 4, 2},
			{3, 6, 5, 2, 1, 4},
			{6, 2, 4, 3, 5, 1},
			{2, 3, 1, 6, 4, 5},
			{6, 5, 3, 4, 2, 1},
			{2, 4, 6, 1, 3, 5},
			{3, 2, 6, 1, 5, 4},
			{6, 3, 2, 5, 4, 1},
			{2, 6, 3, 4, 1, 5},
			{2, 1, 4, 3, 6, 5},
			{4, 2, 1, 6, 5, 3},
			{4, 5, 6, 1, 2, 3},
			{3, 1, 2, 5, 6, 4},
			{4, 6, 2, 5, 1, 3},
			{4, 1, 5, 2, 6, 3}
		},
	},
	{
		name = 'dodecahedron',
		vs = matrix{{(3 + math.sqrt(5)) / 2, -1, 0}, {(1 + math.sqrt(5)) / 2, -(1 + math.sqrt(5)) / 2, (1 + math.sqrt(5)) / 2}, {(3 + math.sqrt(5)) / 2, 1, 0}, {(1 + math.sqrt(5)) / 2, -(1 + math.sqrt(5)) / 2, -(1 + math.sqrt(5)) / 2}, {1, 0, (3 + math.sqrt(5)) / 2}, {(1 + math.sqrt(5)) / 2, (1 + math.sqrt(5)) / 2, (1 + math.sqrt(5)) / 2}, {0, -(3 + math.sqrt(5)) / 2, 1}, {0, -(3 + math.sqrt(5)) / 2, -1}, {(1 + math.sqrt(5)) / 2, (1 + math.sqrt(5)) / 2, -(1 + math.sqrt(5)) / 2}, {1, 0, -(3 + math.sqrt(5)) / 2}, {-1, 0, (3 + math.sqrt(5)) / 2}, {-(1 + math.sqrt(5)) / 2, -(1 + math.sqrt(5)) / 2, (1 + math.sqrt(5)) / 2}, {0, (3 + math.sqrt(5)) / 2, 1}, {0, (3 + math.sqrt(5)) / 2, -1}, {-(1 + math.sqrt(5)) / 2, -(1 + math.sqrt(5)) / 2, -(1 + math.sqrt(5)) / 2}, {-1, 0, -(3 + math.sqrt(5)) / 2}, {-(1 + math.sqrt(5)) / 2, (1 + math.sqrt(5)) / 2, (1 + math.sqrt(5)) / 2}, {-(3 + math.sqrt(5)) / 2, -1, 0}, {-(1 + math.sqrt(5)) / 2, (1 + math.sqrt(5)) / 2, -(1 + math.sqrt(5)) / 2}, {-(3 + math.sqrt(5)) / 2, 1, 0}},
		-- TODO mul table?
	},
	--{
		--name = 'icosahedron',
		--vs = 
	--},
}

for _,shape in ipairs(shapes) do
	shape.vtxAdj = {}
	for i=1,#shape.vs do
		shape.vtxAdj[i] = {}
	end
	--[[
	for i=1,3 do	-- only consider minimal transform basis
		local row = vtxMulTable[i]
		for _,j in ipairs(row) do
			shape.vtxAdj[i][j] = true
			shape.vtxAdj[j][i] = true
		end
	end
	print(require'ext.tolua'(shape.vtxAdj))
	--]]
	-- [[
	for i=1,#shape.vs do
		for j=1,#shape.vs do
			shape.vtxAdj[i][j] = true
		end
	end
	--]]
end

function App:initGL()
	App.super.initGL(self)
	gl.glClearColor(1,1,1,1)
	gl.glColor4f(0,0,0,1)
end

App.viewDist = 2

function App:update(...)
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)
	self.view:setup(self.width / self.height)


	local shape = shapes[shapeIndex]

	gl.glEnable(gl.GL_BLEND)
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ZERO)
	gl.glEnable(gl.GL_POINT_SMOOTH)
	gl.glPointSize(3)
	gl.glBegin(gl.GL_POINTS)
	for _,v in ipairs(shape.vs) do
		gl.glVertex3f(table.unpack(v))
	end
	gl.glEnd()

	gl.glBegin(gl.GL_LINES)
	for i,e in ipairs(shape.vtxAdj) do
		for j in pairs(e) do
			gl.glVertex3f(table.unpack(shape.vs[i]))
			gl.glVertex3f(table.unpack(shape.vs[j]))
		end
	end
	gl.glEnd()

	App.super.update(self, ...)
end

function App:updateGUI()
	for i,shape in ipairs(shapes) do
		if ig.igButton(shape.name) then
			shapeIndex = i
		end
	end
end

App():run()
