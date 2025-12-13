// tail - output the last part of files
import os
import time
import v.mathutil

const app_name = 'tail'

struct FileInfo {
	name string
pub mut:
	size  u64
	stdin bool
}

fn main() {
	args := parse_args(os.args)
	tail(args, fn (s string) {
		print(s)
		flush_stdout()
	})
}

fn tail(args Args, out_fn fn (string)) {
	mut tail_forever := false
	mut files := args.files.map(FileInfo{ name: it, stdin: it.contains(tmp_pattern) })

	for {
		for i, mut file in files {
			stat := os.stat(file.name) or {
				if args.retry {
					continue
				}
				exit_error(err.msg())
			}

			if stat.size < file.size {
				out_fn('\n===> ${file.name} truncated <===\n')
			} else if stat.size != file.size {
				leading_line_feeds := i > 0 || (tail_forever && args.files.len > 1)
				file_header(file, leading_line_feeds, args, out_fn)

				match true {
					tail_forever { tail_new_bytes(file, out_fn) }
					args.bytes > 0 { tail_bytes(file, args, stat.size, out_fn) }
					args.lines > 0 { tail_file(file, args, stat.size, out_fn) }
					else { exit_error('invalid state') }
				}
			}

			file.size = stat.size
		}

		if args.follow {
			tail_forever = true
			time.sleep(i64(args.sleep_interval * time.second))
			if args.pid.len > 0 {
				result := os.execute('ps ${args.pid}')
				if result.exit_code != 0 {
					break
				}
			}
			continue
		}
		break
	}
}

fn file_header(file FileInfo, leading_line_feeds bool, args Args, out_fn fn (string)) {
	if leading_line_feeds {
		out_fn('\n\n')
	}
	if args.quiet {
		return
	}
	name := if file.stdin { 'standard input' } else { file.name }
	if args.files.len > 1 || args.verbose {
		out_fn('===> ${name} <===\n')
	}
}

fn tail_bytes(file FileInfo, args Args, stat_size u64, out_fn fn (string)) {
	pos := if args.from_start {
		args.bytes
	} else {
		mathutil.max(u64(0), stat_size - u64(args.bytes))
	}
	mut f := os.open(file.name) or {
		if args.retry {
			return
		}
		exit_error(err.msg())
	}
	defer { f.close() }
	print_file_at(f, pos, out_fn)
}

fn tail_file(file FileInfo, args Args, stat_size u64, out_fn fn (string)) {
	mut f := os.open(file.name) or {
		if args.retry {
			return
		}
		exit_error(err.msg())
	}
	defer { f.close() }

	buf_size := i64(4096)
	mut buf := []u8{len: int(buf_size)}
	mut count := 0
	end := i64(stat_size)

	if args.from_start {
		mut pos := i64(0)

		loop1: for pos <= end {
			len := mathutil.min(end - pos, buf_size)
			f.read_bytes_into(u64(pos), mut buf) or { exit_error(err.msg()) }

			for i := 0; i < len; i += 1 {
				if buf[i] == args.delimiter {
					count += 1
					if count >= args.lines - 1 {
						pos = pos + i + 1
						break loop1
					}
				}
			}

			pos += buf_size + 1
		}

		print_file_at(f, pos, out_fn)
	} else {
		mut pos := end

		loop2: for pos > 0 {
			len := mathutil.min(pos, buf_size)
			pos = mathutil.max(pos - buf_size, 0)
			f.read_bytes_into(u64(pos), mut buf) or { exit_error(err.msg()) }

			for i := len - 1; i >= 0; i -= 1 {
				if buf[i] == args.delimiter {
					count += 1
					if count >= args.lines {
						pos = pos + i + 1
						break loop2
					}
				}
			}
		}

		print_file_at(f, pos, out_fn)
	}
}

fn tail_new_bytes(file FileInfo, out_fn fn (string)) {
	mut f := os.open(file.name) or { exit_error(err.msg()) }
	defer { f.close() }
	print_file_at(f, file.size, out_fn)
}

fn print_file_at(file os.File, pos i64, out_fn fn (string)) {
	mut idx := pos
	buf_size := 4096
	mut buf := []u8{len: buf_size}
	mut bytes_read := buf_size

	for bytes_read == buf_size {
		bytes_read = file.read_bytes_into(u64(idx), mut buf) or { exit_error(err.msg()) }
		out_fn(buf[0..bytes_read].bytestr())
		idx += bytes_read
	}
}

fn tmp_from_stdin() string {
	tmp := temp_file_name()
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

fn temp_file_name() string {
	dir := os.temp_dir()
	name := '${dir}/t${time.ticks()}'
	return name
}
