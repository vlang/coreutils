import common
import os

struct Settings {
mut:
	count            bool
	repeated         bool
	unique           bool
	case_insensitive bool
	check_chars      int
	help             bool
	version          bool
	skip_fields      int
	skip_chars       int
	line_delimiter   u8
	input_file       string
	output_file      string
}

fn args() Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)
	fp.footer("\nA field is a run of blanks (usually spaces and/or TABs), then non-blank\ncharacters.  Fields are skipped before chars.\n\nNote: 'uniq' does not detect repeated lines unless they are adjacent.\nYou may want to sort the input first, or use 'sort -u' without 'uniq'.")

	mut st := Settings{}
	st.count = fp.bool('count', `c`, false, 'prefix lines by the number of occurrences')
	st.repeated = fp.bool('repeated', `d`, false, 'only print duplicate lines, one for each group')
	st.unique = fp.bool('unique', `u`, false, 'only print unique lines')
	st.case_insensitive = fp.bool('ignore-case', `i`, false, 'ignore differences in case when comparing')
	st.check_chars = fp.int('check-chars', `w`, -1, 'compare no more than N characters in lines')
	st.skip_fields = fp.int('skip-fields', `f`, -1, 'avoid comparing the first N fields')
	st.skip_chars = fp.int('skip-chars', `s`, -1, 'avoid comparing the first N characters')
	st.input_file = '-'
	st.output_file = '-'
	zero_terminated := fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')
	if zero_terminated {
		st.line_delimiter = `\0`
	} else {
		st.line_delimiter = `\n`
	}
	fnames := fp.remaining_parameters()

	// Validation
	match fnames.len {
		1 {
			st.input_file = fnames[0]
		}
		2 {
			st.input_file = fnames[0]
			st.output_file = fnames[1]
		}
		else {
			common.exit_with_error_message(app_name, 'extra operand ‘${fnames[2]}’')
		}
	}

	return st
}
