# Lifecycle y cleanup

Roblox deja vivos muchos recursos si no los desconectas o destruyes. Una clase manual normalmente termina con conexiones olvidadas, instancias temporales vivas o callbacks colgando.

Clases incluye lifecycle porque en Roblox eso no es lujo: es supervivencia.

## Orden de construccion

En herencia, los constructores corren de base a derivada:

```text
Entity constructor
Character constructor
NPC constructor
```

Eso asegura que el estado base exista antes de que el hijo lo use.

## Orden de destruccion

Los destructores corren al reves:

```text
NPC destructor
Character destructor
Entity destructor
cleanup LIFO
```

Eso permite que el hijo libere su estado antes de que la base cierre recursos compartidos.

## Cleanup LIFO

Los recursos se limpian en orden inverso al registro:

```luau
self:addCleanup(function()
	print("first")
end)

self:addCleanup(function()
	print("second")
end)

self:Destroy()
-- second
-- first
```

Este orden es util porque lo ultimo que creaste suele depender de lo anterior.

## Conexiones

```luau
constructor = function(self, part: BasePart)
	self:addCleanup(part.Touched:Connect(function(hit)
		self:onTouched(hit)
	end))
end
```

Al llamar `Destroy`, la conexion se desconecta.

## Instancias

```luau
local folder = Instance.new("Folder")
folder.Parent = workspace

self:addCleanup(folder)
```

Al destruir la clase, `folder:Destroy()` se ejecuta.

## Funciones

```luau
self:addCleanup(function()
	print("closing custom resource")
end)
```

## Objetos custom

```luau
self:addCleanup(resource, "Stop")
```

Si no pasas metodo custom, Clases intenta en orden:

- `Destroy`
- `destroy`
- `Disconnect`
- `disconnect`
- `Clean`
- `clean`
- `Cleanup`
- `cleanup`
- `Cancel`
- `cancel`

## Threads

Si registras un thread, Clases intenta cerrarlo con `coroutine.close`.

```luau
local thread = coroutine.create(function()
	while true do
		coroutine.yield()
	end
end)

self:addCleanup(thread)
```

## Constructor que falla

Si un constructor falla despues de registrar cleanups, Clases limpia lo ya registrado antes de relanzar el error.

```luau
constructor = function(self)
	self:addCleanup(connection)
	error("boom")
end
```

Esto evita medias-instancias con recursos vivos.

## `cleanup()` no destruye

```luau
object:cleanup()
```

Corre los recursos registrados, pero el objeto sigue vivo y puede registrar otros cleanups.

## `Destroy()` es idempotente

Puedes llamar:

```luau
object:Destroy()
object:Destroy()
```

Los destructores y cleanups solo corren una vez.
