// tail - output the last part of files
import common
import flag
import os
import v.mathutil

const app_name = 'tail'

fn main() {
	args := get_args(os.args)
	tail(args)
}

fn tail(args Args) {
	tail_(args, fn (s string) {
		println(s)
	})
}

fn tail_(args Args, out_fn fn (s string)) {
	for i, file in args.files {
		file_header(file, i == 0, args, out_fn)
		match true {
			args.bytes > 0 { tail_bytes(file, args, out_fn) }
			else { tail_file(file, args, out_fn) }
		}
	}
}

fn file_header(file string, first bool, args Args, out_fn fn (string)) {
	if !first {
		out_fn('')
	}
	if args.quiet {
		return
	}
	if args.files.len > 1 || args.verbose {
		out_fn('===> ${file} <===')
	}
}

fn tail_bytes(file string, args Args, out_fn fn (string)) {
	// simple for now
	stat := os.stat(file) or { exit_error(err.msg()) }
	pos := mathutil.max(u64(0), stat.size - u64(args.bytes))
	siz := int(args.bytes)
	mut f := os.open(file) or { exit_error(err.msg()) }
	buffer := if args.from_start {
		f.read_bytes_at(int(pos), u64(siz))
	} else {
		f.read_bytes_at(siz, pos)
	}
	out_fn(buffer.bytestr())
}

fn tail_file(file string, args Args, out_fn fn (string)) {
	// simple for now
	lines := os.read_lines(file) or { exit_error(err.msg()) }
	tail_lines(lines, args, out_fn)
}

fn tail_lines(lines []string, args Args, out_fn fn (string)) {
	count := mathutil.min(args.lines, lines.len)
	mut index := if args.from_start {
		count
	} else {
		lines.len - count
	}

	for index < lines.len {
		out_fn(lines[index])
		index += 1
	}
}

struct Args {
	bytes               i64
	follow              string
	lines               i64
	max_unchanged_stats int
	pid                 string
	quiet               bool
	retry               bool
	sleep_interval      f64
	verbose             bool
	zero_terminated     bool
	from_start          bool
	files               []string
}

fn get_args(args []string) Args {
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

	follow_arg := fp.string('follow', `f`, 'descriptor',
		'output appended data as the file grows        ${wrap}' +
		"an absent option argument means 'descriptor'")

	f_arg := fp.bool('', `F`, false, 'same as --follow=name --retry')

	lines_arg := fp.string('lines', `n`, '10',
		'output the last NUM lines, instead of the last 10; or us${wrap}' +
		'-n +NUM to skip NUM-1 lines at the start')

	max_unchanged_stats_arg := fp.int('max-unchanged-stats', ` `, 5,
		'with --follow=name, reopen a FILE which has not${wrap}' +
		'changed size after N (default 5) iterations to see if it${wrap}' +
		'has been unlinked or renamed (this is the usual case of${wrap}' +
		'rotated log files); with inotify, this option is rarely usefule')

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

	fp.footer("

		NUM may have a multiplier suffix: b 512, kB 1000, K 1024, MB
		1000*1000, M 1024*1024, GB 1000*1000*1000, G 1024*1024*1024, and
		so on for T, P, E, Z, Y, R, Q. Binary prefixes can be used, too:
		KiB=K, MiB=M, and so on.

		With --follow (-f), tail defaults to following the file
		descriptor, which means that even if a tail'ed file is renamed,
		tail will continue to track its end. This default behavior is
		not desirable when you really want to track the actual name of
		the file, not the file descriptor (e.g., log rotation). Use
		--follow=name in that case. That causes tail to track the named
		file in a way that accommodates renaming, removal and creation.".trim_indent())

	fp.footer(common.coreutils_footer())
	file_args := fp.finalize() or { exit_error(err.msg()) }
	from_start := bytes_arg.starts_with('+') || lines_arg.starts_with('+')

	return Args{
		bytes: string_to_i64(bytes_arg) or { exit_error(err.msg()) }
		follow: if f_arg { 'descriptor' } else { follow_arg }
		lines: string_to_i64(lines_arg) or { exit_error(err.msg()) }
		max_unchanged_stats: max_unchanged_stats_arg
		pid: pid_arg
		quiet: quiet_arg || silent_arg
		retry: f_arg || retry_arg
		verbose: verbose_arg
		sleep_interval: sleep_interval_arg
		zero_terminated: zero_terminated_arg
		from_start: from_start
		files: if file_args.len > 0 { file_args } else { ['-'] }
	}
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
