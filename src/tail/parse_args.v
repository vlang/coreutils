import common
import flag
import os
import time

struct Args {
	bytes          i64
	follow         bool
	lines          i64
	pid            string
	quiet          bool
	retry          bool
	sleep_interval f64
	verbose        bool
	from_start     bool
	delimiter      u8 = `\n`
	files          []string
}

fn parse_args(args []string) Args {
	mut fp := flag.new_flag_parser(args)

	fp.application(app_name)
	fp.version(common.coreutils_version())
	fp.skip_executable()
	fp.description('
		Print the last 10 lines of each FILE to standard output.
		With more than one FILE, precede each with a header giving the file name.

		With no FILE, or when FILE is -, read standard input.'.trim_indent())

	eol := common.eol()
	wrap := eol + flag.space

	bytes_arg := fp.string('bytes', `c`, '-1',
		'output the last NUM bytes; or use -c +<int> to output      ${wrap}' +
		'starting with byte <int> of each file')

	follow_arg := fp.bool('follow', `f`, false, 'output appended data as the file grows')
	f_arg := fp.bool('', `F`, false, 'same as --follow=name --retry')

	lines_arg := fp.string('lines', `n`, '10',
		'output the last NUM lines, instead of the last 10; or us${wrap}' +
		'-n +NUM to skip NUM-1 lines at the start')

	pid_arg := fp.string('pid', ` `, '', 'with -f, terminate after process ID, PID dies')
	quiet_arg := fp.bool('quiet', `q`, false, 'never output headers giving file names')
	silent_arg := fp.bool('silent', ` `, false, 'same as --quiet')
	retry_arg := fp.bool('retry', ` `, false, 'keep trying to open a file if it is inaccessible')

	sleep_interval_arg := fp.float('sleep-interval', `s`, 1.0,
		'with -f, sleep for approximately N seconds (default 1.0)${wrap}' +
		'between iterations; with inotify and --pid=P, check${wrap}' +
		'process P at least once every N seconds')

	verbose_arg := fp.bool('verbose', `v`, false, 'always output headers giving file names')
	zero_terminated_arg := fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')

	fp.footer('

		NUM may have a multiplier suffix: b 512, kB 1000, K 1024, MB
		1000*1000, M 1024*1024, GB 1000*1000*1000, G 1024*1024*1024, and
		so on for T, P, E, Z, Y, R, Q. Binary prefixes can be used, too:
		KiB=K, MiB=M, and so on.

		This implementation of TAIL follows files by name only. File
		descriptors are not supported'.trim_indent())

	fp.footer(common.coreutils_footer())
	files_arg := fp.finalize() or { exit_error(err.msg()) }
	from_start := bytes_arg.starts_with('+') || lines_arg.starts_with('+')
	delimiter := if zero_terminated_arg { `\0` } else { `\n` }
	files := scan_files_arg(files_arg)

	return Args{
		bytes:          string_to_i64(bytes_arg) or { exit_error(err.msg()) }
		follow:         follow_arg || f_arg
		lines:          string_to_i64(lines_arg) or { exit_error(err.msg()) }
		pid:            pid_arg
		quiet:          quiet_arg || silent_arg
		retry:          f_arg || retry_arg
		verbose:        verbose_arg
		sleep_interval: sleep_interval_arg
		from_start:     from_start
		delimiter:      delimiter
		files:          files
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
fn exit_success(msg string) {
	println(msg)
	exit(0)
}

@[noreturn]
fn exit_error(msg string) {
	common.exit_with_error_message(app_name, msg)
}
