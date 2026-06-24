--!strict

--[=[
	@class Cleanup

	Estrategias de limpieza de recursos. Sabe como liberar funciones, threads,
	`Instance`, `RBXScriptConnection`, promesas y objetos con metodos de limpieza
	conocidos. Lo usan el lifecycle de las instancias y `Clases.cleanup`.

	No forma parte de la API publica salvo por `Clases.cleanup`.
]=]
local Cleanup = {}

--- Una tarea de cleanup registrada: un recurso y, opcionalmente, el metodo que lo libera.
export type Entry = {
	object: any,
	methodName: string?,
	key: any?,
}

local DEFAULT_METHODS = {
	"Destroy",
	"destroy",
	"Disconnect",
	"disconnect",
	"Clean",
	"clean",
	"Cleanup",
	"cleanup",
	"Cancel",
	"cancel",
}

local function callNamedMethod(object: any, methodName: string)
	local method = object[methodName]

	if type(method) ~= "function" then
		error(`cleanup method "{methodName}" is not callable`, 3)
	end

	method(object)
end

local function closeThread(object: thread)
	if coroutine.running() == object then
		error("cannot clean up the currently running thread", 3)
	end

	-- `task.cancel` cierra el thread y ademas cancela cualquier reanudacion ya
	-- agendada por el scheduler (task.spawn/delay/defer). `coroutine.close` solo
	-- cierra el thread, dejando viva una reanudacion pendiente que luego falla.
	-- `task` es un global de Roblox: en runtimes headless (Lune) no existe, asi
	-- que ahi se usa `coroutine.close`.
	if task ~= nil then
		local ok, err = pcall(function()
			task.cancel(object)
			return true
		end)
		if not ok then
			error(err or "failed to cancel thread", 3)
		end
		return
	end

	local ok, err = coroutine.close(object)
	if not ok then
		error(err or "failed to close thread", 3)
	end
end

--[=[
	@within Cleanup
	Libera un solo recurso. Si se pasa `methodName`, llama ese metodo sobre el
	objeto. Si no, elige la estrategia segun el tipo:

	- `function`: la llama.
	- `thread`: la cancela con `task.cancel` (o `coroutine.close` headless).
	- `Instance`: llama `:Destroy()`.
	- `RBXScriptConnection`: llama `:Disconnect()`.
	- `table`: usa el primer metodo conocido (`Destroy`, `destroy`, `Disconnect`,
	  `Cancel`, `cancel`, ...).

	Lanza si no hay estrategia aplicable.
]=]
function Cleanup.cleanOne(object: any, methodName: string?)
	if object == nil then
		return
	end

	if methodName ~= nil then
		callNamedMethod(object, methodName)
		return
	end

	local objectType = typeof(object)

	if objectType == "function" then
		object()
		return
	end

	if objectType == "thread" then
		closeThread(object)
		return
	end

	if objectType == "Instance" then
		object:Destroy()
		return
	end

	if objectType == "RBXScriptConnection" then
		object:Disconnect()
		return
	end

	if type(object) == "table" then
		for _, candidate in DEFAULT_METHODS do
			if type(object[candidate]) == "function" then
				object[candidate](object)
				return
			end
		end
	end

	error(`no cleanup strategy for {objectType}`, 2)
end

--[=[
	@within Cleanup
	Libera muchas tareas en orden LIFO (la ultima registrada se libera primero).
	Si alguna falla, sigue con el resto y al final lanza con todos los errores
	acumulados.
]=]
function Cleanup.cleanMany(entries: { Entry })
	local errors = {}

	for index = #entries, 1, -1 do
		local entry = entries[index]
		entries[index] = nil :: any

		local ok, err = pcall(function()
			Cleanup.cleanOne(entry.object, entry.methodName)
			return true
		end)
		if not ok then
			table.insert(errors, tostring(err))
		end
	end

	if #errors > 0 then
		error(table.concat(errors, "\n"), 2)
	end
end

--[=[
	@within Cleanup
	Quita una tarea concreta por identidad de entrada (no por valor del recurso),
	para no confundirla con otra que comparta el mismo objeto. Por defecto la
	libera; pasa `shouldClean = false` para quitarla sin liberar. Devuelve el
	recurso quitado, o `nil` si la entrada no estaba.
]=]
function Cleanup.removeEntry(entries: { Entry }, entry: Entry, shouldClean: boolean?): any?
	for index = #entries, 1, -1 do
		if entries[index] == entry then
			table.remove(entries, index)

			if shouldClean ~= false then
				Cleanup.cleanOne(entry.object, entry.methodName)
			end

			return entry.object
		end
	end

	return nil
end

return Cleanup
