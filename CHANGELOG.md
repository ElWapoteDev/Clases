# Changelog

Todos los cambios notables de Clases. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
[SemVer](https://semver.org/lang/es/).

## [0.2.1] - 2026-06-23

### Changed

- Metadata de autoria a `ElWapoteDev` (wally.toml, pesde.toml, LICENSE). Sin
  cambios de codigo.

## [0.2.0] - 2026-06-23

Primera version publicada en Wally como `elwapotedev/clases`.

### Added

- `Clases.Class<T, A...>` ahora lleva un pack de argumentos del constructor (por
  defecto `...any`), de modo que `Class.new(...)` y `Class(...)` quedan tipados.
  `Clases.Class<T>` sigue compilando sin cambios.
- `Clases.assert` y `object:assert(Class)` refinan al tipo de la clase en vez de
  devolver `any`.
- `object:connect(signal, callback)`: registra una conexion y la desconecta al
  destruir.
- `object:bindToInstance(instance)`: destruye la instancia cuando el `Instance` de
  Roblox asociado dispara `Destroying`.
- `object:addPromise(promise)`: cancela la promesa al destruir y la suelta del
  stack de cleanup cuando se resuelve (duck-typing, sin dependencia).
- `object:addCleanup(task, methodName?, key?)` acepta una llave opcional:
  re-registrar bajo la misma llave libera el recurso anterior.
- `object:getCleanup(key)`: lee el recurso registrado bajo una llave.
- Archivo de tipos `types/roblox.d.luau` para analizar los globales de Roblox que
  toca la libreria sin vendorizar el dump completo del API.

### Changed

- El cleanup de threads usa `task.cancel` cuando esta disponible (Roblox) y cae a
  `coroutine.close` en runtimes headless (Lune); `task.cancel` ademas cancela
  reanudaciones ya agendadas por el scheduler.
- Los errores de constructores y destructores conservan su traceback original
  (via `xpcall` + `debug.traceback`) en lugar de aplanarlo a un string.
- Comentarios de documentacion (estilo Moonwave) en todos los simbolos publicos,
  para hover en luau-lsp.
- Pagina de documentacion rediseñada: resaltado real de Luau con Shiki, tema
  claro/oscuro, indice lateral, copiar al portapapeles y matriz de comparacion.

## [0.1.0] - 2026-06-23

### Added

- Nucleo: `define`/`create`, `extend`, `super`, `Destroy`/`destroy`, `cleanup`,
  `IsA`/`is`, `assert`, `getClass`/`getClassName`, `isDestroyed`.
- Herencia con cadenas de constructores/destructores precomputadas y `__index`
  plano de profundidad 1.
- Cleanup LIFO de funciones, threads, `Instance`, `RBXScriptConnection` y objetos
  con metodos conocidos; rollback de cleanups si el constructor falla.
- Mixins con deteccion de conflictos, clases abstractas y `table.freeze` por
  defecto.
- Tooling headless con Lune: tests, benchmarks, sourcemap y `lune run check`
  (StyLua, Selene, `luau-lsp analyze`, paquete Wally). CI y GitHub Pages.

[0.2.1]: https://github.com/ElWapoteDev/Clases/releases/tag/v0.2.1
[0.2.0]: https://github.com/ElWapoteDev/Clases/releases/tag/v0.2.0
[0.1.0]: https://github.com/ElWapoteDev/Clases/releases/tag/v0.1.0
