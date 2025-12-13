import common
import os

const app = common.CoreutilInfo{
	name:        'tty'
	description: 'print the file name of the terminal connected to standard input'
}

// Settings for Utility: tty
struct Settings {
mut:
	silent bool
}

fn tty(settings Settings) {
	if settings.silent {
		if isatty(c_stdin) or { false } {
			exit(0)
		}
		exit(1) // TTY_STDIN_NOTTY
	}

	if name := ttyname(c_stdin) {
		println(name)
	} else {
		println('not a tty')
		exit(1)
	}
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	st.silent = fp.bool('silent', `s`, false, 'print nothing, only return an exit status')
	if fp.bool('quiet', 0, false, 'print nothing, only return an exit status') {
		st.silent = true
	}
	rem_pars := fp.remaining_parameters()
	if rem_pars.len > 0 {
		app.quit(message: 'extra operand ‘${rem_pars[0]}’')
	}
	return st
}

fn main() {
	// TODO: Invalid usage should return with exit code 2 (TTY_FAILURE)
	tty(args())
}
