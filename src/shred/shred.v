import os
import rand
import math
import strconv

enum Fill_Pattern {
	random
	zeros
	source
}

const block_size = 4096

fn main() {
	config, files := get_args()
	shred(files, config)
}

fn shred(files []string, config Config) {
	for file in files {
		total_iterations := if config.zero { config.iterations + 1 } else { config.iterations }
		fill_pattern := if config.random_source.len > 0 {
			Fill_Pattern.source
		} else {
			Fill_Pattern.random
		}
		for iteration in 0 .. config.iterations {
			shred_file(file, fill_pattern, iteration + 1, total_iterations, config)
		}
		if config.zero {
			shred_file(file, .zeros, total_iterations, total_iterations, config)
		}
		if config.rm || config.remove_how.len > 0 {
			remove(file, config)
		}
	}
}

fn shred_file(file string, fill_pattern Fill_Pattern, iteration int, iterations int, config Config) {
	stat := os.lstat(file) or { eexit(err.msg()) }
	size_arg := convert_to_number(config.size)
	mut block := if stat.size >= u64(block_size) { block_size } else { int(stat.size) }
	mut fp := open_file_for_write(file, config)
	mut written := u64(0)
	for {
		pattern := match fill_pattern {
			.random { rand.bytes(block) or { panic(err) } }
			.source { random_from_source(config.random_source) }
			.zeros { []u8{len: block, init: 0} }
		}
		wrote := fp.write(pattern) or { panic(err) }
		written += u64(wrote)
		sz := math.min(size_arg, stat.size)
		if written >= sz {
			break
		}
		remaining := stat.size - written
		block = if remaining > block_size { block_size } else { int(remaining) }
	}
	fp.close()
	if config.verbose {
		show_shred_progress(file, iteration, iterations, fill_pattern)
	}
}

fn open_file_for_write(file string, config Config) os.File {
	return os.create(file) or {
		if !config.force {
			eexit(err.msg())
		}
		os.chmod(file, 0o600) or { eexit(err.msg()) }
		return os.create(file) or { eexit(err.msg()) }
	}
}

fn show_shred_progress(file string, iteration int, iterations int, fill_pattern Fill_Pattern) {
	pattern := match fill_pattern {
		.random { 'random' }
		.source { 'source' }
		.zeros { '000000' }
	}
	println('${progress_prefix(file)}: pass ${iteration} of ${iterations} (${pattern})...')
}

fn progress_prefix(file string) string {
	return 'shred ${file}'
}

fn remove(file string, config Config) {
	match config.remove_how {
		'', 'wipesync', 'wipe' {
			name := rename(file)
			if config.verbose {
				println('${progress_prefix(file)}: renamed to ${name}')
			}
			os.rm(name) or { panic(err) }
			if config.verbose {
				println('${progress_prefix(file)}: removed')
			}
		}
		'unlink' {
			os.rm(file) or { panic(err) }
			if config.verbose {
				println('${progress_prefix(file)}: removed')
			}
		}
		else {
			eexit('unrecognized --remove option')
		}
	}
}

fn rename(file string) string {
	for _ in 0 .. 10 {
		name := file + '${rand.u32()}'
		os.rename(file, name) or {}
		if os.exists(name) {
			return name
		}
	}
	eexit('can not rename file ${file}')
}

fn random_from_source(file string) []u8 {
	stat := os.lstat(file) or { eexit(err.msg()) }
	file_len := stat.size - 1
	if file_len == 0 {
		panic('zero length source file detected')
	}
	mut fp := os.open(file) or { panic(err) }
	mut buf := []u8{}
	for _ in 0 .. block_size {
		pos := rand.u64n(file_len) or { panic(err) }
		b := fp.read_bytes_at(1, pos)
		buf << b
	}
	fp.close()
	return buf
}

fn convert_to_number(input string) u64 {
	if input.len == 0 {
		return max_u64
	}
	if input.ends_with('T') {
		number := to_u64(input[..input.len - 1])
		return number * 1024 * 1024 * 1024 * 1024
	}
	if input.ends_with('G') {
		number := to_u64(input[..input.len - 1])
		return number * 1024 * 1024 * 1024
	}
	if input.ends_with('M') {
		number := to_u64(input[..input.len - 1])
		return number * 1024 * 1024
	}
	if input.ends_with('K') {
		number := to_u64(input[..input.len - 1])
		return number * 1024
	}
	return to_u64(input)
}

fn to_u64(s string) u64 {
	return strconv.common_parse_uint(s, 0, 64, true, true) or { eexit(err.msg()) }
}
