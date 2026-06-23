--!strict

local Clases = require("../src")

export type Counter = Clases.Object & {
	value: number,
	add: (self: Counter, amount: number) -> number,
}

export type CounterClass = Clases.Class<Counter> & {
	new: (value: number) -> Counter,
}

local CounterClass = Clases.define("TypedCounter", {
	constructor = function(self: Counter, value: number)
		self.value = value
	end,

	methods = {
		add = function(self: Counter, amount: number): number
			self.value += amount
			return self.value
		end,
	},
}) :: CounterClass

local counter = CounterClass.new(10)
counter:add(5)
counter:Destroy()

return CounterClass
