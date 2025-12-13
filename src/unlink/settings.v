import common
import os

struct Settings {
mut:
	target string
}

fn args() Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	mut st := Settings{}
	fnames := fp.remaining_parameters()

	// Validation
	match fnames.len {
		0 {
			common.exit_with_error_message(app_name, 'missing operand')
		}
		1 {
			// The desired outcome
			st.target = fnames[0]
		}
		else {
			common.exit_with_error_message(app_name, 'extra operand ‘${fnames[1]}’')
		}
	}
	return st
}
