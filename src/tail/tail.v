// tail - output the last part of files
import common
import flag
import os
import time
import v.mathutil

const app_name = 'tail'

fn main() {
	args := get_args(os.args)
	tail(args)
}

fn tail(args Args) {
	tail_(args, fn (s string) {
		print(s)
		flush_stdout()
	})
}

fn tail_(args Args, out_fn fn (string)) {
	mut appending := false
	mut files := args.files.map(FileInfo{ name: it })

	for {
		for i, mut file in files {
			match file_changed(file) {
				.no_change {
					continue
				}
				.shrunk {
					shrunk_handler(mut file, out_fn)
					continue
				}
				.grown {}
			}

			file_header(file.name, i == 0, args, out_fn)

			match true {
				appending { append_new_lines(file, out_fn) }
				args.bytes > 0 { tail_bytes(file, args, out_fn) }
				else { tail_file(file, args, out_fn) }
			}

			stat := os.stat(file.name) or { exit_error(err.msg()) }
			file.size = stat.size
		}

		if args.follow {
			time.sleep(time.second)
			appending = true
			continue
		}

		break
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

fn tail_bytes(file FileInfo, args Args, out_fn fn (string)) {
	stat := os.stat(file.name) or { exit_error(err.msg()) }
	pos := mathutil.max(u64(0), stat.size - u64(args.bytes))
	siz := int(args.bytes)
	mut f := os.open(file.name) or { exit_error(err.msg()) }
	defer { f.close() }
	bytes := if args.from_start {
		f.read_bytes_at(int(pos), u64(siz))
	} else {
		f.read_bytes_at(siz, pos)
	}
	out_fn(bytes.bytestr())
}

fn tail_file(file FileInfo, args Args, out_fn fn (string)) {
	mut f := os.open(file.name) or { exit_error(err.msg()) }
	defer { f.close() }
	buf_size := i64(4096)
	mut count := 0

	f.seek(0, .end) or { exit_error(err.msg()) }
	end := f.tell() or { exit_error(err.msg()) }

	if args.from_start {
		mut pos := i64(0)
		f.seek(0, .start) or { exit_error(err.msg()) }
		loop1: for pos <= end {
			len := mathutil.min(end - pos, buf_size)
			buf := f.read_bytes_at(int(len), u64(pos))
			for i := 0; i < len; i += 1 {
				if buf[i] == `\n` {
					count += 1
					if count >= args.lines - 1 {
						pos = pos + i + 1
						break loop1
					}
				}
			}
			pos += buf_size + 1
		}

		bytes := f.read_bytes_at(int(end - pos), u64(pos))
		out_fn(bytes.bytestr())
	} else {
		mut pos := end
		loop2: for pos > 0 {
			len := mathutil.min(pos, buf_size)
			pos = mathutil.max(pos - buf_size, 0)
			buf := f.read_bytes_at(int(len), u64(pos))
			for i := len - 1; i >= 0; i -= 1 {
				if buf[i] == `\n` {
					count += 1
					if count >= args.lines {
						pos = pos + i + 1
						break loop2
					}
				}
			}
		}

		size := int(end - pos)
		bytes := f.read_bytes_at(size, u64(pos))
		out_fn(bytes.bytestr())
	}
}

fn tail_file_(file FileInfo, args Args, out_fn fn (string)) {
	lines := os.read_lines(file.name) or { exit_error(err.msg()) }
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

struct FileInfo {
	name string
pub mut:
	size u64
}

enum StatusChange {
	no_change
	shrunk
	grown
}

fn file_changed(file FileInfo) StatusChange {
	stat := os.stat(file.name) or { exit_error(err.msg()) }
	return match true {
		stat.size > file.size { .grown }
		stat.size < file.size { .shrunk }
		else { .no_change }
	}
}

fn append_new_lines(file FileInfo, out_fn fn (string)) {
	stat := os.stat(file.name) or { exit_error(err.msg()) }
	f := os.open(file.name) or { exit_error(err.msg()) }
	if stat.size > file.size {
		size := stat.size - file.size
		bytes := f.read_bytes_at(int(size), u64(file.size))
		strng := bytes.bytestr()
		lines := strng.split_into_lines()
		for line in lines {
			out_fn(line)
		}
	}
}

fn shrunk_handler(mut file FileInfo, out_fn fn (string)) {
	stat := os.stat(file.name) or { exit_error(err.msg()) }
	file.size = stat.size
	out_fn('===> ${file.name} has shrunk <===')
}

struct Args {
	bytes               i64
	follow              bool
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

	follow_arg := fp.bool('follow', `f`, false, 'output appended data as the file grows')
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
		follow: follow_arg
		lines: string_to_i64(lines_arg) or { exit_error(err.msg()) }
		max_unchanged_stats: max_unchanged_stats_arg
		pid: pid_arg
		quiet: quiet_arg || silent_arg
		retry: f_arg || retry_arg
		verbose: verbose_arg
		sleep_interval: sleep_interval_arg
		zero_terminated: zero_terminated_arg
		from_start: from_start
		files: file_args
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
