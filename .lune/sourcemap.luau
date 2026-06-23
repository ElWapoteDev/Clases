--!strict

local fs = require("@lune/fs")

type JsonValue = string | number | boolean | { [string]: any } | { any }

local function escapeString(value: string): string
	return (
		value:gsub('[%z\1-\31\\"]', function(character)
			local byte = string.byte(character)

			if character == '"' then
				return '\\"'
			elseif character == "\\" then
				return "\\\\"
			elseif character == "\b" then
				return "\\b"
			elseif character == "\f" then
				return "\\f"
			elseif character == "\n" then
				return "\\n"
			elseif character == "\r" then
				return "\\r"
			elseif character == "\t" then
				return "\\t"
			end

			return string.format("\\u%04x", byte)
		end)
	)
end

local function isArray(value: { [any]: any }): boolean
	local count = 0

	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
			return false
		end

		count += 1
	end

	for index = 1, count do
		if value[index] == nil then
			return false
		end
	end

	return true
end

local function encodeJson(value: JsonValue): string
	local valueType = type(value)

	if valueType == "string" then
		return `"{escapeString(value :: string)}"`
	elseif valueType == "number" or valueType == "boolean" then
		return tostring(value)
	elseif valueType ~= "table" then
		error(`cannot encode {valueType} as JSON`, 2)
	end

	local tableValue = value :: { [any]: any }
	local parts = {}

	if isArray(tableValue) then
		for index, item in tableValue do
			parts[index] = encodeJson(item)
		end

		return `[{table.concat(parts, ",")}]`
	end

	local keys = {}
	for key in pairs(tableValue) do
		if type(key) ~= "string" then
			error("JSON object keys must be strings", 2)
		end

		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in keys do
		table.insert(parts, `"{escapeString(key)}":{encodeJson(tableValue[key])}`)
	end

	return "{" .. table.concat(parts, ",") .. "}"
end

local function moduleNameFromFile(entryName: string): string?
	local name = entryName:match("^(.*)%.luau$") or entryName:match("^(.*)%.lua$")

	if name == nil or name == "init" then
		return nil
	end

	return name
end

local function buildNode(name: string, path: string): { [string]: any }
	local children = {}

	for _, entryName in fs.readDir(path) do
		local childPath = `{path}/{entryName}`

		if fs.isDir(childPath) then
			table.insert(children, buildNode(entryName, childPath))
		else
			local moduleName = moduleNameFromFile(entryName)

			if moduleName ~= nil then
				table.insert(children, {
					name = moduleName,
					className = "ModuleScript",
					filePaths = { childPath },
				})
			end
		end
	end

	table.sort(children, function(left, right)
		return left.name < right.name
	end)

	return {
		name = name,
		className = "Folder",
		children = children,
	}
end

local root = buildNode("Clases", "src")
root.className = "ModuleScript"
root.filePaths = { "src/init.luau", "default.project.json" }

fs.writeFile("sourcemap.json", encodeJson(root) .. "\n")
print("Generated sourcemap.json")
