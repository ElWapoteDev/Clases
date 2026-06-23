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

El repo trae `wally.toml`, pero esta marcado como privado hasta definir scope real:

```toml
private = true
```

Para publicar en Wally despues:

1. Cambia `name = "tu-scope/clases"`.
2. Quita `private = true`.
3. Ejecuta:

```bash
wally package --list --output build/clases.tar.gz
wally package --output build/clases.tar.gz
```

## pesde

Tambien existe `pesde.toml` para proyectos que usen pesde. Esta marcado como privado por la misma razon: evitar publicar accidentalmente bajo un scope temporal.

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
