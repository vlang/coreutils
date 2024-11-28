import common
import os

const app = common.CoreutilInfo{
	name:        'users'
	description: 'print login names of users currently logged in'
}

// Settings for Utility: users
struct Settings {
mut:
	input_file &char = ''.str
}

fn users(settings Settings) {
	users := utmp_users(settings.input_file).join(' ')
	print(users)
	if users != '' {
		print(common.eol())
	}
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	mut rem_pars := fp.remaining_parameters()
	if rem_pars.len == 0 {
		st.input_file = common.utmp_file_charptr
	} else if rem_pars.len == 1 {
		st.input_file = rem_pars[0].str
	} else if rem_pars.len > 1 {
		app.quit(message: "extra operand '${rem_pars[1]}'", show_help_advice: true)
	}
	return st
}

fn main() {
	users(args())
}
