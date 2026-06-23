# API completa

## `Clases.define(name, definition)`

Crea una clase.

```luau
local Class = Clases.define("ClassName", {
	constructor = function(self, ...) end,
	destructor = function(self) end,
	methods = {},
	static = {},
	mixins = {},
	abstract = false,
	freeze = true,
})
```

Tambien puedes pasar el nombre dentro de la definicion:

```luau
local Class = Clases.define({
	name = "ClassName",
	methods = {},
})
```

### `definition.constructor`

Corre al crear una instancia.

```luau
constructor = function(self, name: string)
	self.name = name
end
```

En herencia, los constructores corren de base a derivada.

### `definition.destructor`

Corre cuando llamas `object:Destroy()`.

```luau
destructor = function(self)
	print("destroying", self.name)
end
```

En herencia, los destructores corren de derivada a base.

### `definition.methods`

Metodos de instancia.

```luau
methods = {
	speak = function(self)
		return "hello"
	end,
}
```

No puedes definir nombres reservados como `Destroy`, `super`, `extend`, `addCleanup`, etc.

### `definition.static`

Miembros estaticos agregados a la clase.

```luau
static = {
	category = "Controller",
}
```

### `definition.mixins`

Lista de tablas de metodos que se copian a la clase.

```luau
mixins = { Damageable, Highlightable }
```

Si dos mixins definen el mismo metodo con funciones distintas, la clase falla al definirse.

### `definition.abstract`

Evita instanciar una clase base.

```luau
local AbstractEntity = Clases.define("AbstractEntity", {
	abstract = true,
})
```

Las subclases si pueden instanciarse.

### `definition.freeze`

Por defecto es `true`. Congela la tabla de clase con `table.freeze`.

Usa `freeze = false` solo si tienes una razon fuerte, como generar miembros dinamicamente en un test o migracion.

## `Class(...)`

Crea una instancia. Es lo mismo que llamar `Class.new(...)` en runtime.

```luau
local dog = Dog("Kira")
```

## `Class.new(...)`

Crea una instancia. Recomendado cuando quieres tipar argumentos del constructor.

```luau
local dog = Dog.new("Kira")
```

## `Class:extend(name, definition)`

Crea una subclase.

```luau
local Dog = Animal:extend("Dog", {
	constructor = function(self, name, breed)
		self.breed = breed
	end,
})
```

Tambien existe:

```luau
local Dog = Clases.extend(Animal, "Dog", definition)
```

## `Class:is(value)` / `Class:IsA(value)`

Comprueba si un valor es instancia de esa clase o de una subclase.

```luau
Dog:is(dog) -- true
Animal:is(dog) -- true
```

## `Class.assert(value)`

Devuelve `value` si es instancia de la clase; si no, lanza error.

```luau
local dog = Dog.assert(value)
```

## `object:IsA(Class)` / `object:is(Class)`

Comprueba identidad de clase desde la instancia.

```luau
dog:IsA(Animal)
```

## `object:super(methodName, ...)`

Llama el metodo heredado mas cercano con ese nombre.

```luau
speak = function(self)
	return `{self:super("speak")} bark`
end
```

Si no existe metodo padre, lanza error.

## `object:addCleanup(resource, methodName?)`

Registra un recurso para limpiarlo despues.

```luau
self:addCleanup(connection)
self:addCleanup(instance)
self:addCleanup(function() end)
self:addCleanup(customObject, "Stop")
```

Devuelve el mismo recurso para que puedas guardarlo:

```luau
self.touchConnection = self:addCleanup(part.Touched:Connect(function() end))
```

## `object:removeCleanup(resource, shouldClean?)`

Quita un recurso del stack de cleanup.

```luau
self:removeCleanup(connection) -- quita y limpia
self:removeCleanup(connection, false) -- quita sin limpiar
```

## `object:cleanup()`

Ejecuta solo los cleanups registrados y deja la instancia viva.

```luau
self:cleanup()
```

Puedes registrar nuevos cleanups despues si el objeto no fue destruido.

## `object:Destroy()` / `object:destroy()`

Destruye la instancia una sola vez:

1. Marca la instancia como destruida.
2. Corre destructores.
3. Corre cleanups LIFO.
4. Agrega errores si algun destructor o cleanup falla.

## `object:isDestroyed()`

Devuelve si la instancia ya fue destruida.

```luau
if object:isDestroyed() then
	return
end
```

## `object:getClass()`

Devuelve la clase concreta de la instancia.

## `object:getClassName()`

Devuelve el nombre de clase concreta.

## `Clases.cleanup(resource, methodName?)`

Limpia un recurso usando la misma logica interna sin crear una clase.

```luau
Clases.cleanup(connection)
Clases.cleanup(part)
Clases.cleanup(object, "Stop")
```

## `Clases.isClass(value)`

Devuelve si `value` es una clase creada por Clases.

## `Clases.isInstance(value)`

Devuelve si `value` es una instancia creada por Clases.

## `Clases.getClass(value)`

Devuelve la clase concreta si `value` es instancia, o `nil`.

## `Clases.getClassName(value)`

Devuelve el nombre de clase concreta si `value` es instancia, o `nil`.
