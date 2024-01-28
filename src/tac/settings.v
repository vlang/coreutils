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
	st.input_files = fp.remaining_parameters()

	if st.input_files.len == 0 {
		st.input_files << '-'
	}

	if st.separator.len == 0 {
		app.quit(message: 'separator cannot be empty')
	}

	return st
}
