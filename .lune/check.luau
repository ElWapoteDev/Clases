--!strict

local process = require("@lune/process")

local checks = {
	{
		name = "format",
		command = "stylua",
		args = { "--check", "src", "tests", ".lune", "benchmarks", "examples" },
	},
	{
		name = "lint",
		command = "selene",
		args = { "src", "tests", ".lune", "benchmarks", "examples" },
	},
	{
		name = "analyze",
		command = "luau-lsp",
		args = {
			"analyze",
			"--platform",
			"standard",
			"--definitions",
			"types/roblox.d.luau",
			"src/init.luau",
			"src/Cleanup.luau",
			"src/Registry.luau",
			"tests/run.luau",
			"benchmarks/run.luau",
			"examples/typed-counter.luau",
		},
	},
	{
		name = "test",
		command = "lune",
		args = { "run", "test" },
	},
	{
		name = "sourcemap",
		command = "lune",
		args = { "run", "sourcemap" },
	},
	{
		name = "package",
		command = "wally",
		args = { "package", "--list", "--output", "clases.tar.gz" },
	},
}

for _, check in checks do
	print(`==> {check.name}`)

	local result = process.exec(check.command, check.args)

	if not result.ok then
		if result.stdout ~= "" then
			print(result.stdout)
		end

		if result.stderr ~= "" then
			print(result.stderr)
		end

		error(`check failed: {check.name}`, 0)
	end
end

print("All checks passed.")
