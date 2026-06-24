--!strict

local Clases = require("../src")

export type Counter = Clases.Object & {
	value: number,
	add: (self: Counter, amount: number) -> number,
}

-- Con el pack de argumentos del constructor, `Counter.new(...)` y `Counter(...)`
-- quedan tipados sin tener que declarar `new` a mano.
export type CounterClass = Clases.Class<Counter, (number)>

local Counter: CounterClass = Clases.define("TypedCounter", {
	constructor = function(self: Counter, value: number)
		self.value = value
	end,

	methods = {
		add = function(self: Counter, amount: number): number
			self.value += amount
			return self.value
		end,
	},
})

local counter = Counter.new(10)
counter:add(5)

-- `assert` refina: `Clases.assert(value, Counter)` devuelve `Counter`, no `any`.
local sameCounter = Clases.assert(counter, Counter)
sameCounter:add(1)

counter:Destroy()

return Counter
