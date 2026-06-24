# Documentacion de Clases

Clases es una libreria para crear objetos en Luau/Roblox con lifecycle, herencia, `super`, cleanup y tipado practico.

## Lectura recomendada

1. [Instalacion](INSTALLATION.md)
2. [Tipado estricto](TYPING.md)
3. [API completa](API.md)
4. [Lifecycle y cleanup](LIFECYCLE.md)
5. [Herencia y mixins](MIXINS.md)
6. [Uso en Roblox](ROBLOX.md)
7. [Migracion desde clases manuales](MIGRATION.md)
8. [Diseno interno](DESIGN.md)
9. [Publicacion](PUBLISHING.md)
10. [FAQ](FAQ.md)

## Resumen rapido

```luau
local Clases = require(game.ReplicatedStorage.Shared.Clases)

type DoorController = Clases.Object & {
	part: BasePart,
	open: (self: DoorController) -> (),
}

type DoorControllerClass = Clases.Class<DoorController, (BasePart)>

local DoorController: DoorControllerClass = Clases.define("DoorController", {
	constructor = function(self: DoorController, part: BasePart)
		self.part = part

		self:connect(part.Touched, function()
			self:open()
		end)
	end,

	methods = {
		open = function(self: DoorController)
			print("open", self.part.Name)
		end,
	},
})

local controller = DoorController.new(workspace.Door)
controller:Destroy()
```

## Filosofia

- Una clase manual de Luau esta bien para cosas pequenas.
- Clases vale la pena cuando hay lifecycle, conexiones, herencia, cleanup o equipos tocando el mismo codigo.
- El tipado no intenta adivinar magia: defines el tipo final de cada objeto y castea la clase una vez.
- El runtime se mantiene pequeno y explicable.
