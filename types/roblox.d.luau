-- Definiciones minimas de los globales de Roblox que toca Clases.
-- Solo se usa para `luau-lsp analyze` (headless). Mantiene el analisis estricto
-- sin tener que vendorizar el dump completo del API de Roblox, y sin que la
-- libreria dependa de globales que no existen en runtimes como Lune.
declare task: {
	cancel: (thread: thread) -> (),
	spawn: <A...>(functionOrThread: thread | (A...) -> ...any, A...) -> thread,
	defer: <A...>(functionOrThread: thread | (A...) -> ...any, A...) -> thread,
	delay: <A...>(duration: number, functionOrThread: thread | (A...) -> ...any, A...) -> thread,
	wait: (duration: number?) -> number,
}
