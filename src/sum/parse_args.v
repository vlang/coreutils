import common
import os
import time

fn parse_args(args []string) Args {
	mut fp := common.flag_parser(args)
	fp.application(app_name)
	fp.description('
	Print or check BSD (16-bit) checksums.

	With no FILE, or when FILE is -, read standard input.'.trim_indent())

	fp.bool('', `r`, true, 'use BSD sum algorithm (the default), use 1K blocks')
	sys_v := fp.bool('sysv', `s`, false, 'use System V sum algorithm, use 512 bytes blocks')
	files_arg := fp.finalize() or { exit_error(err.msg()) }
	files := scan_files_arg(files_arg)

	return Args{
		sys_v: sys_v
		files: files
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

fn stdin_to_tmp() string {
	tmp := '${os.temp_dir()}/${app_name}-${time.ticks()}'
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
