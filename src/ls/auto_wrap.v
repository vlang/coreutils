import os

fn set_auto_wrap(options Options) {
	if options.no_wrap {
		wrap_off := '\e[?7l'
		wrap_reset := '\e[?7h'
		println(wrap_off)

		at_exit(fn [wrap_reset] () {
			println(wrap_reset)
		}) or {}

		// Ctrl-C handler
		os.signal_opt(os.Signal.int, fn (sig os.Signal) {
			println('\e[?7h')
			exit(0)
		}) or {}
	}
}
