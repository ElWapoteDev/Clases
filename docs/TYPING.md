# Tipado estricto

La parte importante: Luau no puede inferir automaticamente el tipo exacto de una clase creada desde una tabla dinamica. La forma sana es:

1. Escribes el tipo de instancia.
2. Escribes el tipo de clase si quieres constructor tipado.
3. Casteas el resultado de `Clases.define` una vez.

Ese casteo no es una trampa; es el puente normal entre un factory runtime y el typechecker estructural de Luau.

## Patron recomendado

```luau
local Clases = require(game.ReplicatedStorage.Shared.Clases)

export type Counter = Clases.Object & {
	value: number,
	add: (self: Counter, amount: number) -> number,
}

export type CounterClass = Clases.Class<Counter> & {
	new: (value: number) -> Counter,
}

local Counter = Clases.define("Counter", {
	constructor = function(self: Counter, value: number)
		self.value = value
	end,

	methods = {
		add = function(self: Counter, amount: number): number
			self.value += amount
			return self.value
		end,
	},
}) :: CounterClass

local counter = Counter.new(10)
counter:add(5)
counter:Destroy()
```

## Por que usar `Clases.Object`

`Clases.Object` agrega los metodos que toda instancia tiene:

- `Destroy`
- `destroy`
- `addCleanup`
- `removeCleanup`
- `cleanup`
- `isDestroyed`
- `IsA`
- `is`
- `assert`
- `super`
- `getClass`
- `getClassName`

Si no lo incluyes, Luau no sabe que tu instancia tiene esos metodos.

## `Class(...)` vs `Class.new(...)`

Ambos funcionan en runtime:

```luau
local a = Counter(10)
local b = Counter.new(10)
```

Para tipado estricto de argumentos, prefiere `Class.new(...)`, porque puedes declarar:

```luau
export type CounterClass = Clases.Class<Counter> & {
	new: (value: number) -> Counter,
}
```

`Class(...)` sigue devolviendo `Counter`, pero sus argumentos son `...any` por limitaciones practicas del tipo callable generico.

## Herencia tipada

Define el tipo base:

```luau
export type Animal = Clases.Object & {
	name: string,
	speak: (self: Animal) -> string,
}

export type AnimalClass = Clases.Class<Animal> & {
	new: (name: string) -> Animal,
}
```

Define el hijo extendiendo el tipo de instancia:

```luau
export type Dog = Animal & {
	breed: string,
	fetch: (self: Dog) -> (),
}

export type DogClass = Clases.Class<Dog> & {
	new: (name: string, breed: string) -> Dog,
}
```

Luego:

```luau
local Dog = AnimalClassValue:extend("Dog", {
	constructor = function(self: Dog, _name: string, breed: string)
		self.breed = breed
	end,

	methods = {
		speak = function(self: Dog): string
			return `{self:super("speak")} the {self.breed}`
		end,

		fetch = function(self: Dog)
			print("fetch")
		end,
	},
}) :: DogClass
```

## Mixins tipados

En runtime, un mixin es una tabla de metodos. En tipos, escribe el resultado final explicitamente:

```luau
type Damageable = {
	health: number,
	takeDamage: (self: Damageable, amount: number) -> (),
}

local DamageableMixin = {
	takeDamage = function(self: Damageable, amount: number)
		self.health -= amount
	end,
}

export type Enemy = Clases.Object & {
	health: number,
	takeDamage: (self: Enemy, amount: number) -> (),
}
```

No intentes que el typechecker "descubra" el mixin por ti. Es mejor declarar la forma final del objeto.

## Exports de modulo

Un modulo tipado puede devolver la clase:

```luau
export type Service = Clases.Object & {
	start: (self: Service) -> (),
}

export type ServiceClass = Clases.Class<Service> & {
	new: () -> Service,
}

local Service = Clases.define("Service", {
	methods = {
		start = function(self: Service) end,
	},
}) :: ServiceClass

return Service
```

Y otro modulo puede importar el tipo:

```luau
local Service = require(path.Service)

type Service = Service.Service

local service: Service = Service.new()
```

## Reglas practicas

- Tipar `self` en constructor y metodos.
- Exportar `type Instancia` y `type Clase` en modulos reutilizables.
- Usar `Class.new(...)` cuando quieres validar argumentos por tipo.
- Usar `Class(...)` cuando te importa mas ergonomia que chequeo de argumentos.
- No meter `any` en tus tipos de dominio; deja el `any` aislado en el casteo de la clase.
