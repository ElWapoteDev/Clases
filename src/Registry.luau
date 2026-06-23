--!strict

local Registry = {}

export type Constructor = (self: any, ...any) -> ()
export type Destructor = (self: any) -> ()

export type ClassInfo = {
	name: string,
	super: any?,
	constructor: Constructor?,
	destructor: Destructor?,
	constructors: { Constructor },
	destructors: { Destructor },
	ancestors: { [any]: boolean },
	instanceMetatable: { [any]: any },
	abstract: boolean,
}

export type InstanceInfo = {
	class: any,
	classInfo: ClassInfo,
	destroyed: boolean,
	cleanups: { { object: any, methodName: string? } }?,
}

local classInfoByClass = (setmetatable({}, { __mode = "k" }) :: any) :: { [any]: ClassInfo }
local instanceInfoByInstance = (setmetatable({}, { __mode = "k" }) :: any) :: { [any]: InstanceInfo }

function Registry.setClass(class: any, info: ClassInfo)
	classInfoByClass[class] = info
end

function Registry.getClass(class: any): ClassInfo?
	return classInfoByClass[class]
end

function Registry.mustGetClass(class: any): ClassInfo
	local info = classInfoByClass[class]

	if info == nil then
		error("expected a Clases class", 3)
	end

	return info
end

function Registry.isClass(value: any): boolean
	return classInfoByClass[value] ~= nil
end

function Registry.setInstance(instance: any, info: InstanceInfo)
	instanceInfoByInstance[instance] = info
end

function Registry.getInstance(instance: any): InstanceInfo?
	return instanceInfoByInstance[instance]
end

function Registry.mustGetInstance(instance: any): InstanceInfo
	local info = instanceInfoByInstance[instance]

	if info == nil then
		error("expected a Clases instance", 3)
	end

	return info
end

function Registry.isInstance(value: any): boolean
	return instanceInfoByInstance[value] ~= nil
end

return Registry
