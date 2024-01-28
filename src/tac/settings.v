fn process_args(mut st Settings, mut rem_pars []string) {
	if rem_pars.len == 0 {
		st.input_files << '-'
	} else {
		st.input_files = rem_pars
	}

	if st.separator.len == 0 {
		app.quit(message: 'separator cannot be empty')
	}
}
