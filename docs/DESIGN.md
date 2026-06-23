# Design Notes

Estas son las decisiones que guian Clases.

## Objetivos

- Ser mejor que el patron manual `Class.__index = Class` sin esconder demasiada magia.
- Mantener una API pequena: definir, extender, comprobar tipo, llamar `super`, destruir y limpiar recursos.
- Ser portable: modulo Rojo, ejecutable en Roblox y testeable en Lune sin abrir Studio.
- Priorizar errores tempranos: nombres reservados, mixins conflictivos y clases abstractas fallan al momento correcto.
- Mantener un nucleo pequeno: clases, herencia, `super`, lifecycle y cleanup. Nada de decoradores, contenedores globales o metaprogramacion opaca.

## Decisiones

### `__index` Directo

Luau optimiza llamadas con `:` y recomienda evitar `__index` como funcion o cadenas profundas. Por eso cada subclase copia los metodos heredados y las instancias apuntan directamente a la tabla de su clase concreta.

Resultado: herencia real para el usuario, pero lookup de metodo simple para el VM.

### Cadenas Precomputadas

Cada clase guarda su lista final de constructores y destructores. Crear o destruir una instancia no vuelve a caminar la jerarquia; solo itera la lista ya resuelta.

### Metadata Cacheada

Las instancias se registran en una tabla debil junto a su clase y `ClassInfo`. Eso mantiene objetos de usuario limpios, evita campos reservados ocultos y acelera `IsA`, `getClassName` y `Destroy`.

### Constructores Y Destructores Encadenados

El constructor corre base -> derivada. El destructor corre derivada -> base. Esto reduce el error comun de olvidar inicializar o liberar el estado base.

Cuando un constructor falla, cualquier cleanup registrado hasta ese punto se ejecuta antes de relanzar el error.

### Cleanup Integrado

Roblox tiene muchos recursos que no se limpian solos cuando un objeto de Luau deja de ser referenciado: conexiones, instancias, callbacks, threads y objetos con `Destroy`/`Disconnect`. Clases integra un stack LIFO pequeno para cubrir ese caso sin depender de Trove, Janitor o Maid.

No intenta reemplazar esas librerias cuando ya necesitas su API completa; solo cubre el 80% que todo objeto con ciclo de vida necesita.

### Mixins Sin Magia

Los mixins solo agregan metodos. No tienen constructores propios, ni orden oculto, ni estado implicito. Si dos mixins definen el mismo metodo con implementaciones distintas, la clase falla al definirse.

### Freeze Por Defecto

Las clases se congelan con `table.freeze` para que la API sea estable despues de definirse. Si necesitas construir una clase dinamicamente durante migracion o tests especificos, usa `freeze = false`.

### `@self` En La Raiz

`src/init.luau` importa modulos hijos con `require("@self/...")`, que evita la ambiguedad de resolver hijos desde un `init.luau`.

### Sourcemap Determinista

`lune run sourcemap` genera un `sourcemap.json` pequeno recorriendo `src`. Rojo sigue siendo la fuente para build/sync, pero el check headless no depende del subcomando `rojo sourcemap`.

### Empaquetado Minimo

Wally incluye solo `src`, `README`, `LICENSE`, `default.project.json` y `wally.toml`. pesde queda configurado como manifiesto privado para publicar cuando exista el scope final.

## Verificacion

- `lune run check`: formato, lint, tipos, tests, sourcemap y paquete Wally.
- `lune run bench`: comparacion contra el patron manual `Class.__index = Class`.
- `wally package --list --output build/clases.tar.gz`: valida la superficie de paquete.
- `rojo build default.project.json -o build/Clases.rbxm`: valida el modelo de libreria en un entorno Rojo sano.

## Fuentes Usadas

- Luau OOP y tipado de metatables: https://luau.org/types/object-oriented-programs/
- Rendimiento de method calls y `__index` directo: https://luau.org/performance/
- `table.freeze`: https://luau.org/library/
- Require-by-string y aliases: https://rfcs.luau.org/require-by-string-aliases.html
- `@self` para `init.luau`: https://rfcs.luau.org/abstract-module-paths-and-init-dot-luau.html
- Rojo project format: https://rojo.space/docs/v7/project-format/
- Rojo sync details: https://rojo.space/docs/v7/sync-details/
- Lune runtime headless: https://github.com/lune-org/lune
- Lune filesystem API: https://lune-org.github.io/docs/api-reference/fs/
- Selene linter: https://kampfkarren.github.io/selene/
- StyLua formatter: https://github.com/JohnnyMorganz/StyLua
- luau-lsp analyzer: https://github.com/JohnnyMorganz/luau-lsp
- Wally packages: https://wally.run/
- pesde manifests: https://docs.pesde.daimond113.com/reference/manifest/
- Trove cleanup surface: https://sleitnick.github.io/RbxUtil/api/Trove/
- Janitor cleanup rationale: https://github.com/howmanysmall/Janitor
