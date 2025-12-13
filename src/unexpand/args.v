import common
import flag
import os
import time

const app_name = 'unexpand'
const spaces = flag.space

struct Options {
	all        bool
	first_only bool
	tabs       string
	files      []string
}

fn get_options() Options {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Convert spaces to tabs')
	fp.arguments_description('[files]')

	all := fp.bool('all', `a`, false, 'convert all blanks instead of just initial blanks')
	first_only := fp.bool('first-only', ` `, false, 'convert only leading sequences of blanks (overrides -a)')
	tabs := fp.string('list', `t`, '', 'use comma separated list of tab positions.\n${spaces}' +
		"The last specified position can be prefixed with '/'\n${spaces}" +
		'to specify a tab size to use after the last$\n${spaces}' +
		"explicitly specified tab stop.  Also a prefix of '+'\n${spaces}" +
		'can be used to align remaining tab stops relative to$\n${spaces}' +
		'the last specified tab stop instead of the first column\n')
	files := fp.finalize() or { exit_error(err.msg()) }

	return Options{
		all:        all
		first_only: first_only
		tabs:       tabs
		files:      scan_files_arg(files)
	}
}

fn scan_files_arg(files_arg []string) []string {
	mut files := []string{}

	for file in files_arg {
		if file == '-' {
			files << stdin_to_tmp()
			continue
		}
		files << file
	}

	if files.len == 0 {
		files << stdin_to_tmp()
	}

	return files
}

const tmp_pattern = '/${app_name}-tmp-'

fn stdin_to_tmp() string {
	tmp := '${os.temp_dir()}/${tmp_pattern}${time.ticks()}'
	os.create(tmp) or { exit_error(err.msg()) }
	mut f := os.open_append(tmp) or { exit_error(err.msg()) }
	defer { f.close() }

	for {
		s := os.get_raw_line()
		if s.len == 0 {
			break
		}
		f.write_string(s) or { exit_error(err.msg()) }
	}
	return tmp
}

@[noreturn]
fn exit_error(msg string) {
	common.exit_with_error_message(app_name, msg)
}
