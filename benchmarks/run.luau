--!strict

local Clases = require("../src")

type Bench = {
	name: string,
	run: () -> (),
	iterations: number,
}

local function bench(name: string, iterations: number, run: () -> ())
	local started = os.clock()

	for _ = 1, iterations do
		run()
	end

	local elapsed = os.clock() - started
	local operationsPerSecond = iterations / elapsed

	print(string.format("%-32s %10.4f ms  %12.0f ops/s", name, elapsed * 1000, operationsPerSecond))
end

local Manual = {}
Manual.__index = Manual

function Manual.new(value: number): any
	return setmetatable({
		value = value,
	}, Manual)
end

function Manual.add(self: any, amount: number): number
	self.value += amount
	return self.value
end

local ClasesCounter = Clases.define("Counter", {
	constructor = function(self: any, value: number)
		self.value = value
	end,

	methods = {
		add = function(self: any, amount: number): number
			self.value += amount
			return self.value
		end,
	},
})

local ManualBase = {}
ManualBase.__index = ManualBase

function ManualBase.new(value: number): any
	return setmetatable({
		value = value,
	}, ManualBase)
end

function ManualBase.add(self: any, amount: number): number
	self.value += amount
	return self.value
end

local ManualChild = table.clone(ManualBase)
ManualChild.__index = ManualChild

function ManualChild.new(value: number): any
	local self = ManualBase.new(value) :: any
	return setmetatable(self, ManualChild)
end

function ManualChild.add(self: any, amount: number): number
	return ManualBase.add(self, amount + 1)
end

local ClasesBase = Clases.define("BenchBase", {
	constructor = function(self: any, value: number)
		self.value = value
	end,

	methods = {
		add = function(self: any, amount: number): number
			self.value += amount
			return self.value
		end,
	},
})

local ClasesChild = ClasesBase:extend("BenchChild", {
	methods = {
		add = function(self: any, amount: number): number
			return self:super("add", amount + 1)
		end,
	},
})

local benches: { Bench } = {
	{
		name = "manual constructor",
		iterations = 100000,
		run = function()
			Manual.new(1)
		end,
	},
	{
		name = "clases constructor",
		iterations = 100000,
		run = function()
			ClasesCounter(1)
		end,
	},
	{
		name = "manual method",
		iterations = 1000000,
		run = (function()
			local object = Manual.new(1)
			return function()
				object:add(1)
			end
		end)(),
	},
	{
		name = "clases method",
		iterations = 1000000,
		run = (function()
			local object = ClasesCounter(1)
			return function()
				object:add(1)
			end
		end)(),
	},
	{
		name = "manual override",
		iterations = 300000,
		run = (function()
			local object = ManualChild.new(1)
			return function()
				object:add(1)
			end
		end)(),
	},
	{
		name = "clases override + super",
		iterations = 300000,
		run = (function()
			local object = ClasesChild(1)
			return function()
				object:add(1)
			end
		end)(),
	},
	{
		name = "clases IsA",
		iterations = 1000000,
		run = (function()
			local object = ClasesChild(1)
			return function()
				object:IsA(ClasesBase)
			end
		end)(),
	},
	{
		name = "clases destroy no cleanup",
		iterations = 100000,
		run = function()
			ClasesCounter(1):Destroy()
		end,
	},
}

print("Clases benchmark")
print("Lower latency and higher ops/s are better. Run more than once; VM warmup and host load matter.")

for _, case in benches do
	bench(case.name, case.iterations, case.run)
end
