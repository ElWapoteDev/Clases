--!strict

--[=[
	@class Clases

	Libreria pequena y estricta para crear clases en Luau/Roblox con lifecycle
	real: constructores y destructores encadenados, `super`, `Destroy` idempotente,
	cleanup LIFO de recursos, mixins con deteccion de conflictos, clases abstractas,
	introspeccion y tipado practico.

	El nucleo se mantiene chico y sin magia: cada subclase aplana sus miembros
	heredados en un `__index` de profundidad 1, la metadata vive en tablas debiles
	fuera de los objetos del usuario y las clases se congelan por defecto.
]=]

local Cleanup = require("@self/Cleanup")
local Registry = require("@self/Registry")

--- Funcion de constructor: corre al crear una instancia, en orden base -> derivada.
export type Constructor = Registry.Constructor
--- Funcion de destructor: corre una vez al destruir, en orden derivada -> base.
export type Destructor = Registry.Destructor
--- Una tarea de cleanup registrada en una instancia.
export type CleanupEntry = Cleanup.Entry

--[=[
	@interface Definition
	@within Clases

	Forma de la tabla que describe una clase en `Clases.define`/`extend`.
]=]
export type Definition = {
	name: string?,
	ClassName: string?,
	extends: AnyClass?,
	constructor: Constructor?,
	destructor: Destructor?,
	methods: { [string]: any }?,
	static: { [string]: any }?,
	mixins: { { [string]: any } }?,
	abstract: boolean?,
	freeze: boolean?,
}

--[=[
	@interface Object
	@within Clases

	Metodos que toda instancia creada por Clases expone. Inclúyelo con
	intersección (`Clases.Object & { ... }`) al declarar el tipo de tus instancias.
]=]
export type Object = {
	IsA: (self: Object, class: any) -> boolean,
	is: (self: Object, class: any) -> boolean,
	assert: <U>(self: Object, class: Class<U>) -> U,
	getClass: (self: Object) -> AnyClass?,
	getClassName: (self: Object) -> string,
	super: (self: Object, methodName: string, ...any) -> ...any,
	addCleanup: (self: Object, object: any, methodName: string?, key: any?) -> any,
	getCleanup: (self: Object, key: any) -> any?,
	removeCleanup: (self: Object, object: any, shouldClean: boolean?) -> any?,
	connect: (self: Object, signal: any, callback: (...any) -> ...any) -> any,
	bindToInstance: (self: Object, instance: any) -> any,
	addPromise: (self: Object, promise: any) -> any,
	cleanup: (self: Object) -> (),
	Destroy: (self: Object) -> (),
	destroy: (self: Object) -> (),
	isDestroyed: (self: Object) -> boolean,
}

--[=[
	@type Class<T, A...>
	@within Clases

	Tipo de una clase de Clases. `T` es el tipo de instancia que produce.
	`A...` es el pack de argumentos del constructor (por defecto `...any`), de modo
	que `Class<T>` sigue compilando sin cambios y `Class<T, (number, string)>`
	hace que `Class.new(...)` y `Class(...)` revisen sus argumentos.
]=]
export type Class<T, A... = ...any> = typeof(setmetatable(
	{} :: {
		ClassName: string,
		new: (A...) -> T,
		extend: (...any) -> any,
		is: (...any) -> boolean,
		IsA: (...any) -> boolean,
		assert: (...any) -> T,
	},
	{} :: {
		__call: (self: any, A...) -> T,
	}
))

--- Una clase de Clases cuyo tipo de instancia y argumentos no se conocen estaticamente.
export type AnyClass = Class<any>

local Clases = {}

local RESERVED_MEMBERS: { [string]: boolean } = {
	ClassName = true,
	new = true,
	extend = true,
	is = true,
	IsA = true,
	assert = true,
	getClass = true,
	getClassName = true,
	super = true,
	addCleanup = true,
	getCleanup = true,
	removeCleanup = true,
	connect = true,
	bindToInstance = true,
	addPromise = true,
	cleanup = true,
	Destroy = true,
	destroy = true,
	isDestroyed = true,
}

local function fail(message: string): never
	error(`[Clases] {message}`, 3)
end

local function ensureName(name: any): string
	if type(name) ~= "string" or name == "" then
		fail("class name must be a non-empty string")
	end

	return name
end

local function normalizeDefinition(nameOrDefinition: any, maybeDefinition: Definition?): (string, Definition)
	if type(nameOrDefinition) == "string" then
		local definition = maybeDefinition or {}
		return ensureName(nameOrDefinition), definition
	end

	if type(nameOrDefinition) == "table" then
		local definition = nameOrDefinition :: Definition
		return ensureName(definition.name or definition.ClassName), definition
	end

	fail("expected Class.define(name, definition) or Class.define(definition)")
	error("unreachable")
end

local function assertMethodKey(key: any)
	if type(key) ~= "string" then
		fail("method and static keys must be strings")
	end

	if RESERVED_MEMBERS[key] then
		fail(`"{key}" is reserved by Clases`)
	end
end

local function copyInheritedMembers(class: { [any]: any }, superClass: any?)
	if superClass == nil then
		return
	end

	local superInfo = Registry.getClass(superClass)
	if superInfo == nil then
		fail("extends must be another Clases class")
	end

	for key, value in pairs(superClass) do
		if key ~= "ClassName" then
			class[key] = value
		end
	end
end

local function applyMixins(class: { [any]: any }, mixins: { { [string]: any } }?)
	if mixins == nil then
		return
	end

	for _, mixin in mixins do
		if type(mixin) ~= "table" then
			fail("mixins must be tables")
		end

		for key, value in pairs(mixin) do
			assertMethodKey(key)

			local existing = rawget(class, key)
			if existing ~= nil and existing ~= value then
				fail(`mixin conflict on "{key}"`)
			end

			class[key] = value
		end
	end
end

local function applyMembers(class: { [any]: any }, members: { [string]: any }?)
	if members == nil then
		return
	end

	for key, value in pairs(members) do
		assertMethodKey(key)
		class[key] = value
	end
end

local function is(value: any, class: any): boolean
	local targetInfo = Registry.getClass(class)
	if targetInfo == nil then
		return false
	end

	local valueInfo = Registry.getInstance(value)
	if valueInfo == nil then
		return false
	end

	return valueInfo.class == class or valueInfo.classInfo.ancestors[class] == true
end

local function assertIs(value: any, class: any): any
	if not is(value, class) then
		local expected = Registry.getClass(class)
		local actual = Registry.getInstance(value)
		local expectedName = if expected ~= nil then expected.name else tostring(class)
		local actualName = if actual ~= nil then actual.classInfo.name else typeof(value)

		fail(`expected {expectedName}, got {actualName}`)
	end

	return value
end

local function runConstructors(classInfo: Registry.ClassInfo, instance: any, ...: any)
	for _, constructor in classInfo.constructors do
		constructor(instance, ...)
	end
end

local function traceback(caught: any): any
	-- Solo los errores de tipo string llevan traceback adjunto; los errores
	-- estructurados (tablas) se devuelven intactos para que el caller pueda
	-- inspeccionarlos via pcall.
	if type(caught) == "string" then
		return debug.traceback(caught, 2)
	end

	return caught
end

local function instantiate(class: any, ...: any): any
	local classInfo = Registry.mustGetClass(class)
	local args = table.pack(...)

	if classInfo.abstract then
		fail(`cannot instantiate abstract class {classInfo.name}`)
	end

	local instance = {}
	Registry.setInstance(instance, {
		class = class,
		classInfo = classInfo,
		destroyed = false,
	})
	setmetatable(instance, classInfo.instanceMetatable)

	local ok, err = xpcall(function()
		runConstructors(classInfo, instance, table.unpack(args, 1, args.n))
	end, traceback)
	if not ok then
		local instanceInfo = Registry.mustGetInstance(instance)
		instanceInfo.destroyed = true

		if instanceInfo.cleanups ~= nil then
			pcall(Cleanup.cleanMany, instanceInfo.cleanups)
			instanceInfo.cleanups = nil
		end
		instanceInfo.cleanupKeys = nil

		if type(err) == "string" then
			error(`[Clases] constructor for {classInfo.name} failed:\n{err}`, 0)
		end

		-- Relanza el error estructurado del usuario sin modificarlo.
		error(err, 0)
	end

	return instance
end

local function getInstanceClass(self: any): any
	return Registry.mustGetInstance(self).class
end

local function getInstanceClassName(self: any): string
	return Registry.mustGetInstance(self).classInfo.name
end

local function getInstanceInfo(self: any): Registry.InstanceInfo
	return Registry.mustGetInstance(self)
end

local function getCleanups(instanceInfo: Registry.InstanceInfo): { Cleanup.Entry }
	if instanceInfo.cleanups == nil then
		local newCleanups = {} :: { Cleanup.Entry }
		instanceInfo.cleanups = newCleanups
		return newCleanups
	end

	return (instanceInfo.cleanups :: any) :: { Cleanup.Entry }
end

local function addCleanup(self: any, object: any, methodName: string?, key: any?): any
	local instanceInfo = getInstanceInfo(self)

	if instanceInfo.destroyed then
		fail(`cannot add cleanup to destroyed {instanceInfo.classInfo.name}`)
	end

	local cleanups = getCleanups(instanceInfo)

	if key ~= nil then
		local keyed: { [any]: Cleanup.Entry }
		if instanceInfo.cleanupKeys == nil then
			keyed = {}
			instanceInfo.cleanupKeys = keyed
		else
			keyed = (instanceInfo.cleanupKeys :: any) :: { [any]: Cleanup.Entry }
		end

		local existing = keyed[key]
		if existing ~= nil then
			if existing.object == object then
				-- Mismo recurso bajo la misma llave: actualiza el metodo sin
				-- liberarlo (evita liberar de mas algo que sigue en uso).
				existing.methodName = methodName
				return object
			end

			-- Reemplaza: libera el recurso anterior por identidad de entrada
			-- (no por valor) antes de guardar el nuevo.
			Cleanup.removeEntry(cleanups, existing, true)
			keyed[key] = nil
		end

		local entry: Cleanup.Entry = { object = object, methodName = methodName, key = key }
		table.insert(cleanups, entry)
		keyed[key] = entry

		return object
	end

	table.insert(cleanups, { object = object, methodName = methodName } :: Cleanup.Entry)

	return object
end

local function getCleanup(self: any, key: any): any?
	local instanceInfo = getInstanceInfo(self)
	local keyed = instanceInfo.cleanupKeys

	if keyed == nil then
		return nil
	end

	local entry = keyed[key]
	return if entry ~= nil then entry.object else nil
end

local function removeCleanup(self: any, object: any, shouldClean: boolean?): any?
	local instanceInfo = getInstanceInfo(self)
	local cleanups = instanceInfo.cleanups

	if cleanups == nil then
		return nil
	end

	for index = #cleanups, 1, -1 do
		local entry = cleanups[index]

		if entry.object == object then
			table.remove(cleanups, index)

			if entry.key ~= nil and instanceInfo.cleanupKeys ~= nil then
				instanceInfo.cleanupKeys[entry.key] = nil
			end

			if shouldClean ~= false then
				Cleanup.cleanOne(entry.object, entry.methodName)
			end

			return entry.object
		end
	end

	return nil
end

-- Declaracion adelantada: `bindToInstance` referencia `destroyInstance`, que se
-- define mas abajo. `function destroyInstance(...)` asigna a este local.
local destroyInstance: (self: any) -> ()

local function connect(self: any, signal: any, callback: (...any) -> ...any): any
	return addCleanup(self, signal:Connect(callback))
end

local function bindToInstance(self: any, instance: any): any
	return addCleanup(
		self,
		instance.Destroying:Connect(function()
			destroyInstance(self)
		end)
	)
end

local function addPromise(self: any, promise: any): any
	addCleanup(self, promise, "cancel")

	if type(promise) == "table" and type(promise.finally) == "function" then
		promise:finally(function()
			pcall(removeCleanup, self, promise, false)
		end)
	end

	return promise
end

local function cleanup(self: any)
	local instanceInfo = getInstanceInfo(self)
	local cleanups = instanceInfo.cleanups

	if cleanups == nil then
		return
	end

	instanceInfo.cleanups = nil
	instanceInfo.cleanupKeys = nil
	Cleanup.cleanMany(cleanups)
end

function destroyInstance(self)
	local instanceInfo = getInstanceInfo(self)

	if instanceInfo.destroyed then
		return
	end

	instanceInfo.destroyed = true

	local errors = {}
	for _, destructor in instanceInfo.classInfo.destructors do
		local ok, err = xpcall(function()
			destructor(self)
			return true
		end, traceback)
		if not ok then
			table.insert(errors, tostring(err))
		end
	end

	local cleanups = instanceInfo.cleanups
	if cleanups ~= nil then
		instanceInfo.cleanups = nil
		instanceInfo.cleanupKeys = nil
		local ok, err = pcall(function()
			Cleanup.cleanMany(cleanups)
			return true
		end)
		if not ok then
			table.insert(errors, tostring(err))
		end
	end

	if #errors > 0 then
		error(`[Clases] errors while destroying {getInstanceClassName(self)}:\n{table.concat(errors, "\n")}`, 2)
	end
end

local function isDestroyed(self: any): boolean
	return getInstanceInfo(self).destroyed
end

local function super(self: any, methodName: string, ...: any): ...any
	local instanceInfo = getInstanceInfo(self)
	local currentClassInfo = Registry.mustGetClass(instanceInfo.class)
	local currentMethod = (instanceInfo.class :: any)[methodName]
	local cursor = currentClassInfo.super

	while cursor ~= nil do
		local method = rawget(cursor, methodName)

		if type(method) == "function" and method ~= currentMethod then
			return method(self, ...)
		end

		cursor = Registry.mustGetClass(cursor).super
	end

	fail(`no super method "{methodName}" for {currentClassInfo.name}`)
	error("unreachable")
end

local function installBuiltins(class: { [any]: any })
	class.new = function(...: any): any
		local args = table.pack(...)

		if args[1] == class then
			return instantiate(class, table.unpack(args, 2, args.n))
		end

		return instantiate(class, ...)
	end

	class.extend = function(...: any): any
		local args = table.pack(...)
		local offset = if args[1] == class then 2 else 1
		local nameOrDefinition = args[offset]
		local maybeDefinition = args[offset + 1]

		return Clases.extend(class, nameOrDefinition, maybeDefinition)
	end

	class.is = function(...: any): boolean
		local args = table.pack(...)

		if args[1] == class then
			return is(args[2], class)
		end

		if args[2] == nil then
			return is(args[1], class)
		end

		return is(args[1], args[2])
	end

	class.IsA = class.is

	class.assert = function(...: any): any
		local args = table.pack(...)

		if args[1] == class then
			return assertIs(args[2], class)
		end

		if args[2] == nil then
			return assertIs(args[1], class)
		end

		return assertIs(args[1], args[2])
	end

	class.getClass = getInstanceClass
	class.getClassName = getInstanceClassName
	class.super = super
	class.addCleanup = addCleanup
	class.getCleanup = getCleanup
	class.removeCleanup = removeCleanup
	class.connect = connect
	class.bindToInstance = bindToInstance
	class.addPromise = addPromise
	class.cleanup = cleanup
	class.Destroy = destroyInstance
	class.destroy = destroyInstance
	class.isDestroyed = isDestroyed
end

local function makeAncestors(superClass: any?): { [any]: boolean }
	local ancestors = {}

	if superClass ~= nil then
		local superInfo = Registry.mustGetClass(superClass)
		ancestors[superClass] = true

		for ancestor in pairs(superInfo.ancestors) do
			ancestors[ancestor] = true
		end
	end

	return ancestors
end

local function makeConstructors(superClass: any?, constructor: Constructor?): { Constructor }
	local constructors = {}

	if superClass ~= nil then
		local superInfo = Registry.mustGetClass(superClass)

		for _, inheritedConstructor in superInfo.constructors do
			table.insert(constructors, inheritedConstructor)
		end
	end

	if constructor ~= nil then
		table.insert(constructors, constructor)
	end

	return constructors
end

local function makeDestructors(superClass: any?, destructor: Destructor?): { Destructor }
	local destructors = {}

	if destructor ~= nil then
		table.insert(destructors, destructor)
	end

	if superClass ~= nil then
		local superInfo = Registry.mustGetClass(superClass)

		for _, inheritedDestructor in superInfo.destructors do
			table.insert(destructors, inheritedDestructor)
		end
	end

	return destructors
end

--[=[
	@within Clases
	Crea una clase a partir de un nombre y una definicion (o de una definicion con
	`name`/`ClassName`). Devuelve una clase llamable: `Class.new(...)` y `Class(...)`
	crean instancias.
]=]
function Clases.define(nameOrDefinition: any, maybeDefinition: Definition?): AnyClass
	local name, definition = normalizeDefinition(nameOrDefinition, maybeDefinition)
	local superClass = definition.extends
	local class: { [any]: any } = {}

	copyInheritedMembers(class, superClass)
	class.ClassName = name

	applyMixins(class, definition.mixins)
	applyMembers(class, definition.methods)
	applyMembers(class, definition.static)

	local classInfo: Registry.ClassInfo = {
		name = name,
		super = superClass,
		constructor = definition.constructor,
		destructor = definition.destructor,
		constructors = makeConstructors(superClass, definition.constructor),
		destructors = makeDestructors(superClass, definition.destructor),
		ancestors = makeAncestors(superClass),
		instanceMetatable = {},
		abstract = definition.abstract == true,
	}

	classInfo.instanceMetatable = {
		__index = class,
		__tostring = function()
			return name
		end,
		__metatable = `Clases<{name}>`,
	}

	Registry.setClass(class, classInfo)
	installBuiltins(class)

	setmetatable(class, {
		__call = function(_, ...: any): any
			return instantiate(class, ...)
		end,
		__tostring = function()
			return `class {name}`
		end,
	})

	if definition.freeze ~= false then
		table.freeze(classInfo.instanceMetatable)
		table.freeze(class)
	end

	return class :: any
end

--[=[
	@within Clases
	Crea una subclase de `superClass`. Equivale a `Class:extend(name, definition)`.
	Los constructores se encadenan base -> derivada y los destructores derivada -> base.
]=]
function Clases.extend(superClass: any, nameOrDefinition: any, maybeDefinition: Definition?): AnyClass
	if not Registry.isClass(superClass) then
		fail("Class.extend requires a Clases class as the first argument")
	end

	local name, definition = normalizeDefinition(nameOrDefinition, maybeDefinition)

	if definition.extends ~= nil and definition.extends ~= superClass then
		fail("definition.extends conflicts with the class being extended")
	end

	definition.extends = superClass

	return Clases.define(name, definition)
end

--- Alias de `Clases.define`.
Clases.create = Clases.define

--- Devuelve `true` si el valor es una clase creada por Clases.
function Clases.isClass(value: any): boolean
	return Registry.isClass(value)
end

--- Devuelve `true` si el valor es una instancia creada por Clases.
function Clases.isInstance(value: any): boolean
	return Registry.isInstance(value)
end

--- Devuelve `true` si `value` es instancia de `class` o de una subclase suya.
function Clases.is(value: any, class: any): boolean
	return is(value, class)
end

--- Devuelve `value` tipado como `U` si es instancia de `class`; si no, lanza error.
function Clases.assert<U>(value: any, class: Class<U>): U
	return assertIs(value, class)
end

--- Devuelve la clase concreta de `value` si es instancia de Clases, o `nil`.
function Clases.getClass(value: any): AnyClass?
	local instanceInfo = Registry.getInstance(value)
	return if instanceInfo ~= nil then instanceInfo.class else nil
end

--- Devuelve el nombre de la clase concreta de `value` si es instancia, o `nil`.
function Clases.getClassName(value: any): string?
	local instanceInfo = Registry.getInstance(value)
	return if instanceInfo ~= nil then instanceInfo.classInfo.name else nil
end

--- Libera un recurso con la misma logica interna de cleanup, sin crear una clase.
function Clases.cleanup(object: any, methodName: string?)
	Cleanup.cleanOne(object, methodName)
end

table.freeze(Clases)

return Clases
