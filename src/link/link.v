module main

import common
import os

const app = common.CoreutilInfo{
	name:        'link'
	description: 'Call the link function to create a link named FILE2 to an existing FILE1.'
}

struct Settings {
mut:
	files []string
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	st.files = fp.remaining_parameters()
	match st.files.len {
		0 { app.quit(message: 'missing operand') }
		1 { app.quit(message: "missing operand after '${st.files[0]}'", show_help_advice: true) }
		2 {}
		else { app.quit(message: "extra operand '${st.files[2]}'", show_help_advice: true) }
	}

	return st
}

fn link(settings Settings) !int {
	mut exit_code := 0
	os.link(settings.files[0], settings.files[1]) or {
		app.quit(
			message: "cannot create link '${settings.files[1]}' to '${settings.files[0]}': ${err.msg()}"
		)
	}
	return exit_code
}

fn main() {
	exit(link(args()) or { common.err_programming_error })
}
