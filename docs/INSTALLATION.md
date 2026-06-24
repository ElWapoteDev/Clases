# Instalacion

## Como modelo Rojo

Para generar un `ModuleScript` importable:

```bash
rojo build default.project.json -o build/Clases.rbxm
```

El modelo resultante contiene:

```text
Clases
├─ Cleanup
└─ Registry
```

## Como modulo vendorizado

Copia `src` a tu proyecto y montalo con Rojo:

```json
{
  "ReplicatedStorage": {
    "Shared": {
      "Clases": {
        "$path": "vendor/Clases/src"
      }
    }
  }
}
```

Despues:

```luau
local Clases = require(game.ReplicatedStorage.Shared.Clases)
```

Si copias los archivos manualmente dentro de otro proyecto, cambia los requires internos de `src/init.luau`:

```luau
local Cleanup = require(script.Cleanup)
local Registry = require(script.Registry)
```

El repo original usa `@self` porque su raiz es `src/init.luau`; dentro de un juego Roblox normal, `script.Cleanup` es mas directo.

## Wally

Publicado en Wally como `elwapotedev/clases`. Agregalo a tu `wally.toml`:

```toml
[dependencies]
Clases = "elwapotedev/clases@0.2.1"
```

Luego:

```bash
wally install
```

Eso lo coloca en `Packages/`. Montalo con Rojo y requierelo como cualquier paquete Wally.

## pesde

Tambien existe `pesde.toml` para proyectos que usen pesde. Sigue marcado como privado hasta publicar en ese registro.

## Tooling recomendado

```bash
aftman install
lune run check
```

`lune run check` valida:

- StyLua
- Selene
- `luau-lsp analyze`
- Tests headless con Lune
- Sourcemap determinista
- Superficie del paquete Wally
