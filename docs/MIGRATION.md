# Migracion desde clases manuales

## Antes

```luau
local PlotObject = {}
PlotObject.__index = PlotObject

function PlotObject.new(plot: Model)
	local self = setmetatable({}, PlotObject)
	self.Plot = plot
	return self
end

function PlotObject:Destroy()
end

return PlotObject
```

## Despues

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Clases = require(ReplicatedStorage.Shared.Clases)

export type PlotObject = Clases.Object & {
	Plot: Model,
}

export type PlotObjectClass = Clases.Class<PlotObject> & {
	new: (plot: Model) -> PlotObject,
}

local PlotObject = Clases.define("PlotObject", {
	constructor = function(self: PlotObject, plot: Model)
		self.Plot = plot
	end,

	destructor = function(self: PlotObject)
		print("destroy plot object")
	end,
}) :: PlotObjectClass

return PlotObject
```

## Migrar conexiones

Antes:

```luau
self.Connection = part.Touched:Connect(function() end)

function Object:Destroy()
	self.Connection:Disconnect()
end
```

Despues:

```luau
self:addCleanup(part.Touched:Connect(function() end))
```

## Migrar herencia manual

Antes:

```luau
local Dog = setmetatable({}, Animal)
Dog.__index = Dog

function Dog.new(name, breed)
	local self = Animal.new(name)
	setmetatable(self, Dog)
	self.breed = breed
	return self
end
```

Despues:

```luau
local Dog = Animal:extend("Dog", {
	constructor = function(self, _name, breed)
		self.breed = breed
	end,
})
```

## Migrar destructor base

Antes:

```luau
function Dog:Destroy()
	-- dog cleanup
	Animal.Destroy(self)
end
```

Despues:

```luau
local Dog = Animal:extend("Dog", {
	destructor = function(self)
		-- dog cleanup
	end,
})
```

Clases llama el destructor de `Animal` automaticamente despues.

## Estrategia segura

1. Migra una clase pequena.
2. Agrega tipo de instancia.
3. Reemplaza conexiones manuales por `addCleanup`.
4. Corre tests o abre Studio.
5. Migra clases con herencia despues.

No migres todo de golpe si el sistema ya esta en produccion.
