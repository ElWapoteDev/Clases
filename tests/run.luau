--!strict

local Clases = require("../src")

type Test = {
	name: string,
	run: () -> (),
}

local tests: { Test } = {}

local function test(name: string, run: () -> ())
	table.insert(tests, {
		name = name,
		run = run,
	})
end

local function expectEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(message or `expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function expectTrue(value: any, message: string?)
	if value ~= true then
		error(message or `expected true, got {tostring(value)}`, 2)
	end
end

local function expectFalse(value: any, message: string?)
	if value ~= false then
		error(message or `expected false, got {tostring(value)}`, 2)
	end
end

local function expectError(run: () -> (), expectedText: string?)
	local ok, err = pcall(function()
		run()
		return true
	end)

	if ok then
		error("expected function to throw", 2)
	end

	if expectedText ~= nil and string.find(tostring(err), expectedText, 1, true) == nil then
		error(`expected error containing "{expectedText}", got "{tostring(err)}"`, 2)
	end
end

test("creates callable classes with constructors and methods", function()
	local Animal = Clases.define("Animal", {
		constructor = function(self: any, name: string)
			self.name = name
		end,

		methods = {
			speak = function(self: any): string
				return `hi {self.name}`
			end,
		},
	})

	local animal = Animal("Nina")

	expectEqual(animal.name, "Nina")
	expectEqual(animal:speak(), "hi Nina")
	expectEqual(tostring(animal), "Animal")
	expectTrue(Animal:is(animal))
	expectTrue(animal:IsA(Animal))
	expectEqual(animal:getClass(), Animal)
	expectEqual(animal:getClassName(), "Animal")
end)

test("inherits with automatic constructor order and fast direct indexing", function()
	local order = {}

	local Animal = Clases.define("Animal", {
		constructor = function(self: any, name: string)
			table.insert(order, "animal")
			self.name = name
		end,

		methods = {
			speak = function(self: any): string
				return self.name
			end,
		},
	})

	local Dog = Animal:extend("Dog", {
		constructor = function(self: any, _name: string, breed: string)
			table.insert(order, "dog")
			self.breed = breed
		end,

		methods = {
			speak = function(self: any): string
				return `{self:super("speak")} the {self.breed}`
			end,
		},
	})

	local dog = Dog("Kira", "collie")

	expectEqual(table.concat(order, ","), "animal,dog")
	expectEqual(dog:speak(), "Kira the collie")
	expectTrue(Clases.is(dog, Dog))
	expectTrue(Clases.is(dog, Animal))
	expectFalse(Clases.is({}, Animal))
	expectEqual(Dog.assert(dog), dog)
end)

test("cleans constructor failures before rethrowing", function()
	local order = {}

	local Broken = Clases.define("Broken", {
		constructor = function(self: any)
			self:addCleanup(function()
				table.insert(order, "first")
			end)

			self:addCleanup(function()
				table.insert(order, "second")
			end)

			error("boom")
		end,
	})

	expectError(function()
		Broken()
	end, "constructor for Broken failed")

	expectEqual(table.concat(order, ","), "second,first")
end)

test("preserves a structured (non-string) constructor error", function()
	local Bad = Clases.define("BadStruct", {
		constructor = function()
			error({ code = 42 })
		end,
	})

	local ok, err = pcall(function()
		Bad()
	end)

	expectFalse(ok)
	expectEqual(type(err), "table")
	expectEqual((err :: any).code, 42)
end)

test("runs destructors once, then cleanup tasks in LIFO order", function()
	local order = {}

	local Base = Clases.define("Base", {
		destructor = function()
			table.insert(order, "base")
		end,
	})

	local Thing = Base:extend("Thing", {
		destructor = function()
			table.insert(order, "thing")
		end,
	})

	local thing = Thing()
	thing:addCleanup(function()
		table.insert(order, "first")
	end)
	thing:addCleanup(function()
		table.insert(order, "second")
	end)

	thing:Destroy()
	thing:Destroy()

	expectTrue(thing:isDestroyed())
	expectEqual(table.concat(order, ","), "thing,base,second,first")
end)

test("supports cleanup method selection and removal", function()
	local order = {}

	local Thing = Clases.define("Thing")
	local thing = Thing()

	local resource = {
		close = function()
			table.insert(order, "closed")
		end,
	}

	local skipped = {
		Destroy = function()
			table.insert(order, "destroyed")
		end,
	}

	thing:addCleanup(resource, "close")
	thing:addCleanup(skipped)

	expectEqual(thing:removeCleanup(skipped, false), skipped)

	thing:Destroy()

	expectEqual(table.concat(order, ","), "closed")
end)

test("can cleanup early and keep using remaining lifecycle", function()
	local order = {}
	local Thing = Clases.define("Thing")
	local thing = Thing()

	thing:addCleanup(function()
		table.insert(order, "manual")
	end)
	thing:cleanup()

	thing:addCleanup(function()
		table.insert(order, "destroy")
	end)
	thing:Destroy()

	expectEqual(table.concat(order, ","), "manual,destroy")
end)

test("exposes direct cleanup helper for resources", function()
	local order = {}

	Clases.cleanup(function()
		table.insert(order, "function")
	end)

	Clases.cleanup({
		destroy = function()
			table.insert(order, "table")
		end,
	})

	local thread = coroutine.create(function()
		coroutine.yield()
	end)
	coroutine.resume(thread)
	Clases.cleanup(thread)

	expectEqual(table.concat(order, ","), "function,table")

	expectError(function()
		Clases.cleanup({})
	end, "no cleanup strategy")
end)

test("adds mixins with conflict detection", function()
	local Clickable = {
		click = function(self: any)
			self.clicked = true
		end,
	}

	local Button = Clases.define("Button", {
		mixins = { Clickable },
	})

	local button = Button()
	button:click()

	expectTrue(button.clicked)

	expectError(function()
		Clases.define("BrokenButton", {
			mixins = {
				Clickable,
				{
					click = function() end,
				},
			},
		})
	end, "mixin conflict")
end)

test("protects reserved API names", function()
	expectError(function()
		Clases.define("Bad", {
			methods = {
				Destroy = function() end,
			},
		})
	end, "reserved")
end)

test("freezes classes by default", function()
	local Frozen = Clases.define("Frozen")

	expectError(function()
		(Frozen :: any).lateMethod = function() end
	end)
end)

test("fails loudly when super method does not exist", function()
	local Lonely = Clases.define("Lonely", {
		methods = {
			askSuper = function(self: any)
				return self:super("askSuper")
			end,
		},
	})

	expectError(function()
		Lonely():askSuper()
	end, 'no super method "askSuper"')
end)

test("prevents abstract classes from being instantiated", function()
	local Abstract = Clases.define("Abstract", {
		abstract = true,
	})

	expectError(function()
		Abstract()
	end, "abstract")

	local Concrete = Abstract:extend("Concrete")
	expectEqual(Concrete():getClassName(), "Concrete")
end)

test("keyed cleanup replaces and frees the previous resource", function()
	local order = {}

	local Thing = Clases.define("KeyedThing")
	local thing = Thing()

	thing:addCleanup(function()
		table.insert(order, "first")
	end, nil, "slot")

	-- Re-registrar bajo la misma llave libera el recurso anterior de inmediato.
	thing:addCleanup(function()
		table.insert(order, "second")
	end, nil, "slot")

	expectEqual(table.concat(order, ","), "first")

	thing:Destroy()

	expectEqual(table.concat(order, ","), "first,second")
end)

test("getCleanup returns the resource registered under a key", function()
	local Thing = Clases.define("LookupThing")
	local thing = Thing()

	local task = function() end
	thing:addCleanup(task, nil, "slot")

	expectEqual(thing:getCleanup("slot"), task)
	expectEqual(thing:getCleanup("missing"), nil)

	thing:Destroy()
end)

test("re-registering the same resource under one key cleans it exactly once", function()
	local cleaned = 0

	local Thing = Clases.define("RekeyThing")
	local thing = Thing()

	local resource = function()
		cleaned += 1
	end

	thing:addCleanup(resource, nil, "slot")
	thing:addCleanup(resource, nil, "slot") -- mismo objeto: no debe liberar ahora

	expectEqual(cleaned, 0)

	thing:Destroy()

	expectEqual(cleaned, 1)
end)

test("keyed replace frees the keyed entry, not a same-valued unkeyed one", function()
	local order = {}

	local Thing = Clases.define("DupThing")
	local thing = Thing()

	-- El mismo objeto registrado dos veces: una con llave y otra sin ella,
	-- con metodos distintos para distinguir cual se libera y cuando.
	local shared = {
		keyed = function()
			table.insert(order, "keyed")
		end,
		loose = function()
			table.insert(order, "loose")
		end,
	}
	local fresh = function()
		table.insert(order, "fresh")
	end

	thing:addCleanup(shared, "keyed", "slot")
	thing:addCleanup(shared, "loose")
	thing:addCleanup(fresh, nil, "slot") -- reemplaza: libera solo la entrada con llave

	expectEqual(table.concat(order, ","), "keyed")

	thing:Destroy()

	-- Sobreviven la entrada suelta y fresh; LIFO: fresh, luego loose.
	expectEqual(table.concat(order, ","), "keyed,fresh,loose")
end)

test("connect registers a signal connection and disconnects on destroy", function()
	local disconnected = false
	local received

	local signal = {
		Connect = function(_, callback: (...any) -> ...any)
			received = callback
			return {
				Disconnect = function()
					disconnected = true
				end,
			}
		end,
	}

	local Controller = Clases.define("SignalController")
	local controller = Controller()
	controller:connect(signal, function() end)

	expectTrue(type(received) == "function")

	controller:Destroy()
	expectTrue(disconnected)
end)

test("bindToInstance destroys the object when the instance dies", function()
	local fired

	local fakeInstance = {
		Destroying = {
			Connect = function(_, callback: (...any) -> ...any)
				fired = callback
				return {
					Disconnect = function() end,
				}
			end,
		},
	}

	local Component = Clases.define("BoundComponent")
	local component = Component()
	component:bindToInstance(fakeInstance)

	expectFalse(component:isDestroyed())

	fired()

	expectTrue(component:isDestroyed())
end)

test("addPromise cancels a pending promise on destroy", function()
	local cancelled = false

	local promise = {
		cancel = function()
			cancelled = true
		end,
		finally = function(self: any, _callback: () -> ())
			return self
		end,
	}

	local Service = Clases.define("PromiseService")
	local service = Service()
	service:addPromise(promise)

	service:Destroy()

	expectTrue(cancelled)
end)

test("addPromise drops a settled promise so destroy does not cancel it", function()
	local cancelled = false

	local promise = {
		cancel = function()
			cancelled = true
		end,
		finally = function(self: any, callback: () -> ())
			callback() -- el promise ya esta resuelto: corre finally de inmediato
			return self
		end,
	}

	local Service = Clases.define("SettledService")
	local service = Service()
	service:addPromise(promise)

	service:Destroy()

	expectFalse(cancelled)
end)

local passed = 0
local failed = 0

for _, case in tests do
	local ok, err = pcall(function()
		case.run()
		return true
	end)

	if ok then
		passed += 1
		print(`[PASS] {case.name}`)
	else
		failed += 1
		print(`[FAIL] {case.name}\n{tostring(err)}`)
	end
end

print(`\n{passed} passed, {failed} failed`)

if failed > 0 then
	error(`{failed} test(s) failed`, 0)
end
