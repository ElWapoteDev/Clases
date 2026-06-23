--!strict

local Cleanup = {}

export type Entry = {
	object: any,
	methodName: string?,
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
		if coroutine.running() == object then
			error("cannot clean up the currently running thread", 2)
		end

		local ok, err = coroutine.close(object)
		if not ok then
			error(err or "failed to close thread", 2)
		end

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

function Cleanup.remove(entries: { Entry }, object: any, shouldClean: boolean?): any?
	for index = #entries, 1, -1 do
		local entry = entries[index]

		if entry.object == object then
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
