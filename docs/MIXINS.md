# Herencia y mixins

## Herencia

Usa herencia cuando hay identidad:

```text
PoliceDog IsA Dog
Dog IsA Animal
```

Ejemplo:

```luau
local Animal = Clases.define("Animal", {
	constructor = function(self, name: string)
		self.name = name
	end,

	methods = {
		speak = function(self)
			return self.name
		end,
	},
})

local Dog = Animal:extend("Dog", {
	constructor = function(self, _name: string, breed: string)
		self.breed = breed
	end,

	methods = {
		speak = function(self)
			return `{self:super("speak")} the {self.breed}`
		end,
	},
})
```

`Dog` hereda metodos de `Animal`, pero Clases copia los miembros heredados al definir la subclase. Las instancias apuntan directo a la clase concreta con `__index`.

## `super`

`super` llama el metodo padre mas cercano:

```luau
self:super("speak")
```

No llama constructores. Los constructores ya se encadenan automaticamente.

## `IsA`

```luau
local dog = Dog.new("Kira", "Collie")

dog:IsA(Dog) -- true
dog:IsA(Animal) -- true
```

Clases precomputa ancestros por clase para que `IsA` no tenga que recorrer toda la jerarquia en cada llamada.

## Mixins

Usa mixins para capacidades:

```text
Damageable
Highlightable
Interactable
CooldownBased
```

Ejemplo:

```luau
local Damageable = {
	takeDamage = function(self, amount: number)
		self.health -= amount
	end,
}

local Enemy = Clases.define("Enemy", {
	constructor = function(self)
		self.health = 100
	end,

	mixins = {
		Damageable,
	},
})
```

## Conflictos

Si dos mixins definen el mismo metodo con funciones distintas, Clases falla:

```luau
local A = { use = function() end }
local B = { use = function() end }

Clases.define("Broken", {
	mixins = { A, B },
})
-- error: mixin conflict on "use"
```

Esto es intencional. Es mejor fallar al crear la clase que descubrir en runtime que un mixin piso a otro.

## Lo que los mixins no hacen

- No tienen constructor.
- No tienen destructor.
- No tienen estado oculto.
- No hacen herencia multiple.
- No tienen orden magico.

Si un mixin necesita estado, inicializalo en el constructor de la clase que lo usa.

## Regla simple

- Herencia para identidad.
- Mixins para capacidades.
- Composicion para sistemas grandes.
