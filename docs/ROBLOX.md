# Uso en Roblox

## Requerir la libreria

Si esta en `ReplicatedStorage.Clases`:

```luau
local Clases = require(game.ReplicatedStorage.Clases)
```

Si esta vendorizada en `ReplicatedStorage.Shared.Clases`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Clases = require(ReplicatedStorage.Shared.Clases)
```

## Controller con conexiones

```luau
local ButtonController = Clases.define("ButtonController", {
	constructor = function(self, button: TextButton)
		self.button = button

		self:addCleanup(button.MouseButton1Click:Connect(function()
			self:onClicked()
		end))
	end,

	methods = {
		onClicked = function(self)
			print("clicked")
		end,
	},
})
```

## Componente de mundo

```luau
local Door = Clases.define("Door", {
	constructor = function(self, model: Model)
		self.model = model
		self.part = model.PrimaryPart

		if self.part then
			self:addCleanup(self.part.Touched:Connect(function(hit)
				self:onTouched(hit)
			end))
		end
	end,

	destructor = function(self)
		print("door destroyed", self.model.Name)
	end,

	methods = {
		onTouched = function(self, hit: BasePart)
			print(hit.Name)
		end,
	},
})
```

## Feature con Loader

En una arquitectura feature-first:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Clases = require(ReplicatedStorage.Shared.Clases)

local InventoryController = Clases.define("InventoryController", {
	constructor = function(self)
		self.connections = 0
	end,

	methods = {
		start = function(self)
			print("Inventory started")
		end,
	},
})

local M = {}
local controller

function M:OnInit()
	controller = InventoryController.new()
end

function M:OnStart()
	controller:start()
end

return M
```

## Cuando usar Clases

Usala para:

- Controllers de UI
- Componentes de mundo
- Objetos con conexiones
- Objetos con `Destroy`
- Servicios internos
- Armas, habilidades, NPCs, vehiculos
- Sistemas con herencia pequena

No hace falta para:

- Tablas constantes
- Modulos puramente funcionales
- Configuracion data-driven
- Funciones utilitarias sin estado

## Studio y autocompletado

Rojo sincroniza. Luau LSP autocompleta.

Para que VS Code vea rutas como:

```luau
game.ReplicatedStorage.Shared.Clases
```

necesitas `sourcemap.json` actualizado.

```bash
rojo sourcemap default.project.json --output sourcemap.json --include-non-scripts
```

Despues reinicia el language server:

```text
Luau: Restart Language Server
```
