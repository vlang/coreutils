// Settings for Utility: tac
// DO NOT EDIT - This file is auto-generated and may be overwritten in the future.
import os

struct Settings {
mut:
	before      bool
	regex       bool
	separator   string
	input_files []string
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	st.before = fp.bool('before', `b`, false, 'attach the separator before instead of after')
	st.regex = fp.bool('regex', `r`, false, 'interpret the separator as a regular expression')
	st.separator = fp.string('separator', `s`, '\n', 'use STRING as the separator instead of newline')
	mut rem_pars := fp.remaining_parameters()
	process_args(mut st, mut rem_pars)
	return st
}
