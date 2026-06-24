# Clases

[![CI](https://github.com/ElWapoteDev/Clases/actions/workflows/ci.yml/badge.svg)](https://github.com/ElWapoteDev/Clases/actions/workflows/ci.yml)
[![Docs](https://github.com/ElWapoteDev/Clases/actions/workflows/pages.yml/badge.svg)](https://github.com/ElWapoteDev/Clases/actions/workflows/pages.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Luau strict](https://img.shields.io/badge/Luau-%2D%2D!strict-1a8f52)

Clases es una libreria pequena y estricta para crear clases en Luau/Roblox con lifecycle real: herencia, `super`, `Destroy`, cleanup LIFO, mixins, introspeccion y tipado practico.

No intenta convertir Luau en Java. Toma el patron normal de metatables y lo vuelve consistente para proyectos grandes.

Pagina de documentacion: <https://elwapotedev.github.io/Clases/>.

## Por que existe

Una clase normal de Roblox suele empezar asi:

```luau
local Class = {}
Class.__index = Class
```

Eso esta bien para objetos pequenos, pero no te da:

- Orden automatico de constructores y destructores.
- `Destroy` consistente e idempotente.
- Cleanup automatico de conexiones, instancias, callbacks, threads y promesas.
- Helpers de lifecycle: `connect`, `bindToInstance` (auto-`Destroy`) y cleanup con llave.
- `super`.
- `IsA` con herencia real.
- Proteccion contra nombres reservados.
- Mixins con deteccion de conflictos.
- Clases abstractas.
- Tipado del constructor con `Clases.Class<T, A...>`.
- Tooling headless, tests, benchmarks, packaging y CI.

Clases cubre ese espacio sin meter un framework gigante.

## Instalacion rapida

Como modelo Rojo:

```bash
rojo build default.project.json -o build/Clases.rbxm
```

Como modulo en un juego:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Clases = require(ReplicatedStorage.Shared.Clases)
```

Lee la guia completa: [docs/INSTALLATION.md](docs/INSTALLATION.md).

## Ejemplo tipado

```luau
local Clases = require(game.ReplicatedStorage.Shared.Clases)

export type Counter = Clases.Object & {
	value: number,
	add: (self: Counter, amount: number) -> number,
}

-- El pack de argumentos `(number)` tipa `Counter.new(...)` y `Counter(...)`.
export type CounterClass = Clases.Class<Counter, (number)>

local Counter: CounterClass = Clases.define("Counter", {
	constructor = function(self: Counter, value: number)
		self.value = value
	end,

	methods = {
		add = function(self: Counter, amount: number): number
			self.value += amount
			return self.value
		end,
	},
})

local counter = Counter.new(10)
counter:add(5)
counter:Destroy()
```

Guia completa de tipado: [docs/TYPING.md](docs/TYPING.md).

## Con conexiones de Roblox

```luau
local ButtonController = Clases.define("ButtonController", {
	constructor = function(self, button: TextButton)
		-- connect registra y desconecta la conexion al destruir.
		self:connect(button.MouseButton1Click, function()
			self:onClicked()
		end)

		-- bindToInstance destruye el controller cuando el boton deja de existir.
		self:bindToInstance(button)
	end,

	methods = {
		onClicked = function(self)
			print("click")
		end,
	},
})

local controller = ButtonController.new(button)
controller:Destroy() -- desconecta MouseButton1Click
```

## Documentacion

- [Instalacion](docs/INSTALLATION.md)
- [Tipado estricto](docs/TYPING.md)
- [API completa](docs/API.md)
- [Lifecycle y cleanup](docs/LIFECYCLE.md)
- [Herencia y mixins](docs/MIXINS.md)
- [Uso en Roblox](docs/ROBLOX.md)
- [Migracion desde clases manuales](docs/MIGRATION.md)
- [Diseno interno](docs/DESIGN.md)
- [Publicacion](docs/PUBLISHING.md)
- [FAQ](docs/FAQ.md)

La pagina web estatica vive en [docs/index.html](docs/index.html).

## API minima

```luau
local Class = Clases.define(name, definition)
local Child = Class:extend(name, definition)
local object = Class.new(...)
local object = Class(...)
```

Instancias:

- `object:IsA(Class)` / `object:is(Class)`
- `object:assert(Class)` — refina al tipo de la clase
- `object:super("methodName", ...)`
- `object:addCleanup(task, methodName?, key?)`
- `object:getCleanup(key)`
- `object:removeCleanup(task, shouldClean?)`
- `object:connect(signal, callback)`
- `object:bindToInstance(instance)`
- `object:addPromise(promise)`
- `object:cleanup()`
- `object:Destroy()` / `object:destroy()`
- `object:isDestroyed()`
- `object:getClass()`
- `object:getClassName()`

## Calidad

```bash
aftman install
lune run check
```

`check` ejecuta:

- StyLua
- Selene
- `luau-lsp analyze`
- Tests headless con Lune
- Sourcemap determinista
- Validacion de paquete Wally

Comandos puntuales:

```bash
lune run test
lune run bench
lune run sourcemap
wally package --list --output build/clases.tar.gz
```

## Rojo

El proyecto principal genera un `ModuleScript` raiz llamado `Clases`:

```bash
rojo build default.project.json -o build/Clases.rbxm
```

Para desarrollo en Studio:

```bash
rojo serve dev.project.json
```

## Wally y pesde

Los manifests estan listos, pero marcados como privados hasta definir el scope real:

- [wally.toml](wally.toml)
- [pesde.toml](pesde.toml)

## Fuentes de diseno

El diseno se apoya en la documentacion oficial de Luau sobre OOP, rendimiento de metatables, `table.freeze`, require-by-string y sourcemaps de Rojo. Ver [docs/DESIGN.md](docs/DESIGN.md).
