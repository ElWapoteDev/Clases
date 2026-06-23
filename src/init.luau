--!strict

local Cleanup = require("@self/Cleanup")
local Registry = require("@self/Registry")

export type Constructor = Registry.Constructor
export type Destructor = Registry.Destructor
export type CleanupEntry = Cleanup.Entry

export type Definition = {
	name: string?,
	ClassName: string?,
	extends: any?,
	constructor: Constructor?,
	destructor: Destructor?,
	methods: { [string]: any }?,
	static: { [string]: any }?,
	mixins: { { [string]: any } }?,
	abstract: boolean?,
	freeze: boolean?,
}

export type Object = {
	IsA: (self: Object, class: any) -> boolean,
	is: (self: Object, class: any) -> boolean,
	assert: (self: Object, class: any) -> any,
	getClass: (self: Object) -> any,
	getClassName: (self: Object) -> string,
	super: (self: Object, methodName: string, ...any) -> ...any,
	addCleanup: (self: Object, object: any, methodName: string?) -> any,
	removeCleanup: (self: Object, object: any, shouldClean: boolean?) -> any?,
	cleanup: (self: Object) -> (),
	Destroy: (self: Object) -> (),
	destroy: (self: Object) -> (),
	isDestroyed: (self: Object) -> boolean,
}

export type Class<T> = typeof(setmetatable(
	{} :: {
		ClassName: string,
		new: (...any) -> T,
		extend: (...any) -> any,
		is: (...any) -> boolean,
		IsA: (...any) -> boolean,
		assert: (...any) -> any,
	},
	{} :: {
		__call: (self: any, ...any) -> T,
	}
))

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
	removeCleanup = true,
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

	local ok, err = pcall(function()
		runConstructors(classInfo, instance, table.unpack(args, 1, args.n))
		return true
	end)
	if not ok then
		local instanceInfo = Registry.mustGetInstance(instance)
		instanceInfo.destroyed = true

		if instanceInfo.cleanups ~= nil then
			pcall(Cleanup.cleanMany, instanceInfo.cleanups)
			instanceInfo.cleanups = nil
		end

		error(`constructor for {classInfo.name} failed: {tostring(err)}`, 2)
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

local function addCleanup(self: any, object: any, methodName: string?): any
	local instanceInfo = getInstanceInfo(self)

	if instanceInfo.destroyed then
		fail(`cannot add cleanup to destroyed {instanceInfo.classInfo.name}`)
	end

	local cleanups: { Cleanup.Entry }
	if instanceInfo.cleanups == nil then
		local newCleanups = {} :: { Cleanup.Entry }
		instanceInfo.cleanups = newCleanups
		cleanups = newCleanups
	else
		cleanups = (instanceInfo.cleanups :: any) :: { Cleanup.Entry }
	end

	table.insert(
		cleanups,
		{
			object = object,
			methodName = methodName,
		} :: Cleanup.Entry
	)

	return object
end

local function removeCleanup(self: any, object: any, shouldClean: boolean?): any?
	local instanceInfo = getInstanceInfo(self)
	local cleanups = instanceInfo.cleanups

	if cleanups == nil then
		return nil
	end

	return Cleanup.remove(cleanups, object, shouldClean)
end

local function cleanup(self: any)
	local instanceInfo = getInstanceInfo(self)
	local cleanups = instanceInfo.cleanups

	if cleanups == nil then
		return
	end

	instanceInfo.cleanups = nil
	Cleanup.cleanMany(cleanups)
end

local function destroy(self: any)
	local instanceInfo = getInstanceInfo(self)

	if instanceInfo.destroyed then
		return
	end

	instanceInfo.destroyed = true

	local errors = {}
	for _, destructor in instanceInfo.classInfo.destructors do
		local ok, err = pcall(function()
			destructor(self)
			return true
		end)
		if not ok then
			table.insert(errors, tostring(err))
		end
	end

	local cleanups = instanceInfo.cleanups
	if cleanups ~= nil then
		instanceInfo.cleanups = nil
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
	class.removeCleanup = removeCleanup
	class.cleanup = cleanup
	class.Destroy = destroy
	class.destroy = destroy
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

Clases.create = Clases.define

function Clases.isClass(value: any): boolean
	return Registry.isClass(value)
end

function Clases.isInstance(value: any): boolean
	return Registry.isInstance(value)
end

function Clases.is(value: any, class: any): boolean
	return is(value, class)
end

function Clases.assert(value: any, class: any): any
	return assertIs(value, class)
end

function Clases.getClass(value: any): any?
	local instanceInfo = Registry.getInstance(value)
	return if instanceInfo ~= nil then instanceInfo.class else nil
end

function Clases.getClassName(value: any): string?
	local instanceInfo = Registry.getInstance(value)
	return if instanceInfo ~= nil then instanceInfo.classInfo.name else nil
end

function Clases.cleanup(object: any, methodName: string?)
	Cleanup.cleanOne(object, methodName)
end

table.freeze(Clases)

return Clases
