--!strict

--[=[
	@class Registry

	Almacenamiento interno de Clases. Mantiene la metadata de clases e instancias
	fuera de las tablas del usuario usando dos tablas con llaves debiles, de modo
	que los objetos del usuario nunca cargan campos reservados ocultos y la metadata
	se recolecta junto con su objeto.

	No forma parte de la API publica.
]=]
local Registry = {}

--- Funcion de constructor de una clase: corre al crear una instancia.
export type Constructor = (self: any, ...any) -> ()

--- Funcion de destructor de una clase: corre una vez al destruir una instancia.
export type Destructor = (self: any) -> ()

--- Una tarea de cleanup registrada en una instancia.
export type CleanupEntry = {
	object: any,
	methodName: string?,
	key: any?,
}

--[=[
	@interface ClassInfo
	@within Registry

	Metadata precomputada de una clase. Las cadenas de constructores, destructores
	y ancestros se resuelven una sola vez al definir la clase para que crear,
	destruir y comprobar tipos no tenga que recorrer la jerarquia en cada llamada.
]=]
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

--[=[
	@interface InstanceInfo
	@within Registry

	Metadata por instancia. `cleanups` es el stack LIFO de tareas registradas;
	`cleanupKeys` indexa las tareas que se registraron con llave para reemplazo y
	lectura O(1).
]=]
export type InstanceInfo = {
	class: any,
	classInfo: ClassInfo,
	destroyed: boolean,
	cleanups: { CleanupEntry }?,
	cleanupKeys: { [any]: CleanupEntry }?,
}

local classInfoByClass = (setmetatable({}, { __mode = "k" }) :: any) :: { [any]: ClassInfo }
local instanceInfoByInstance = (setmetatable({}, { __mode = "k" }) :: any) :: { [any]: InstanceInfo }

--- Registra la metadata de una clase recien definida.
function Registry.setClass(class: any, info: ClassInfo)
	classInfoByClass[class] = info
end

--- Devuelve la metadata de una clase, o `nil` si no es una clase de Clases.
function Registry.getClass(class: any): ClassInfo?
	return classInfoByClass[class]
end

--- Devuelve la metadata de una clase, o lanza error si no es una clase de Clases.
function Registry.mustGetClass(class: any): ClassInfo
	local info = classInfoByClass[class]

	if info == nil then
		error("expected a Clases class", 3)
	end

	return info
end

--- Devuelve `true` si el valor es una clase creada por Clases.
function Registry.isClass(value: any): boolean
	return classInfoByClass[value] ~= nil
end

--- Registra la metadata de una instancia recien creada.
function Registry.setInstance(instance: any, info: InstanceInfo)
	instanceInfoByInstance[instance] = info
end

--- Devuelve la metadata de una instancia, o `nil` si no es una instancia de Clases.
function Registry.getInstance(instance: any): InstanceInfo?
	return instanceInfoByInstance[instance]
end

--- Devuelve la metadata de una instancia, o lanza error si no es una instancia de Clases.
function Registry.mustGetInstance(instance: any): InstanceInfo
	local info = instanceInfoByInstance[instance]

	if info == nil then
		error("expected a Clases instance", 3)
	end

	return info
end

--- Devuelve `true` si el valor es una instancia creada por Clases.
function Registry.isInstance(value: any): boolean
	return instanceInfoByInstance[value] ~= nil
end

return Registry
