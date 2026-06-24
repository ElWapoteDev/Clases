# FAQ

## Por que no autoinfiere todos los tipos?

Porque Luau no puede deducir la forma exacta de una clase creada dinamicamente desde una tabla de definicion. Clases exporta `Clases.Object` y `Clases.Class<T>` para que el patron sea claro, pero tu declaras el tipo final de cada objeto.

## Por que `Class.new` es mejor para tipado que `Class(...)`?

Con el pack de argumentos `A...`, ambas formas revisan los argumentos:

```luau
type MyClass = Clases.Class<MyObject, (string)>
```

`Class.new(...)` sigue siendo la forma recomendada cuando quieres dejar explicito
que estas construyendo, pero `Class(...)` ya no pierde el tipado.

## Esto reemplaza Trove o Janitor?

No siempre. Clases trae cleanup integrado para el lifecycle normal de objetos. Si ya necesitas la API completa de Trove/Janitor, puedes seguir usandolos y registrarlos:

```luau
self:addCleanup(trove)
```

## Es mas rapido que una clase manual?

Las llamadas de metodo estan muy cerca del patron manual porque las instancias usan `__index` directo a la clase concreta. Crear/destroy/`super`/`IsA` tienen coste extra porque agregan garantias de lifecycle e introspeccion.

## Por que no hay herencia multiple?

Porque en Luau/Roblox suele generar mas problemas que beneficios: orden ambiguo, conflictos silenciosos y tipos dificiles de entender. Clases usa herencia simple + mixins con conflicto explicito.

## Puedo modificar una clase despues de definirla?

Por defecto no. Las clases se congelan con `table.freeze`.

Si necesitas mutarla durante una migracion:

```luau
local Class = Clases.define("Class", {
	freeze = false,
})
```

## Puedo usarlo en servidor y cliente?

Si. Es realm shared. No usa APIs exclusivas de servidor o cliente.

## Como lo instalo como paquete?

Esta publicado en Wally como `elwapotedev/clases`:

```toml
[dependencies]
Clases = "elwapotedev/clases@0.2.1"
```

Luego `wally install`. El manifiesto de pesde sigue privado hasta publicar ahi.

## Me conviene usarlo para todo?

No. Usalo donde haya estado y ciclo de vida. Para datos constantes o funciones puras, un modulo normal es mejor.
