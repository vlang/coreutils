module main

import os
import flag
import strconv
import common
import encoding.base64

const app_name = 'cksum'

const app_description = 'Print or verify checksums.'

const app = common.CoreutilInfo{
	name:        app_name
	description: app_description
}

struct Settings {
mut:
	algorithm       Algorithm
	algorithm_given bool
	bit_length      int
	check           bool
	base64_output   bool
	raw             bool
	tag             bool
	untagged        bool
	zero            bool
	ignore_missing  bool
	quiet           bool
	status          bool
	strict          bool
	warn            bool
	files           []string
}

fn main() {
	settings := args()
	if settings.check {
		check_files(settings)
	} else {
		print_checksums(settings)
	}
}

// read_input returns the bytes of file, or of standard input for '-'. A file
// that cannot be read is reported and ends the program, as in GNU.
fn read_input(file string) []u8 {
	if file == '-' {
		mut data := []u8{}
		mut buf := []u8{len: 64 * 1024}
		mut stdin := os.stdin()
		for {
			n := stdin.read(mut buf) or { break }
			data << buf[..n]
		}
		return data
	}
	if os.is_dir(file) {
		app_quit('${quote_name(file)}: Is a directory')
	}
	return os.read_bytes(file) or {
		app_quit('${quote_name(file)}: ${os.error_posix().msg()}')
	}
}

// block_count is the size column of the sysv and bsd output: like sum(1),
// sysv counts 512 byte blocks and bsd counts 1024 byte blocks, both rounding up.
fn block_count(length int, block int) u64 {
	return (u64(length) + u64(block) - 1) / u64(block)
}

// write_digest prints the checksum of one input in the form GNU uses for the
// chosen algorithm and output options.
fn write_digest(settings Settings, file string, show_name bool, data []u8) {
	sum := checksum(settings.algorithm, data, settings.bit_length) or { return }

	if settings.raw {
		mut out := os.stdout()
		if settings.algorithm.is_numeric() {
			// 16 and 32 bit checksums go out in network byte order.
			mut bytes := []u8{}
			if settings.algorithm == .sysv || settings.algorithm == .bsd {
				bytes << u8(sum.numeric >> 8)
				bytes << u8(sum.numeric)
			} else {
				bytes << u8(sum.numeric >> 24)
				bytes << u8(sum.numeric >> 16)
				bytes << u8(sum.numeric >> 8)
				bytes << u8(sum.numeric)
			}
			out.write(bytes) or {}
			return
		}
		out.write(sum.digest) or {}
		return
	}

	delim := if settings.zero { '\x00' } else { '\n' }

	if settings.algorithm.is_numeric() {
		// The numeric algorithms have no printable digest form, so neither
		// --tag nor --untagged changes anything here.
		name := if show_name { ' ${file}' } else { '' }
		match settings.algorithm {
			.bsd {
				print('${sum.numeric:05} ${block_count(data.len, 1024):5}${name}')
			}
			.sysv {
				print('${sum.numeric} ${block_count(data.len, 512)}${name}')
			}
			else {
				print('${sum.numeric} ${data.len}${name}')
			}
		}
		print(delim)
		return
	}

	// The byte digests default to the tagged form. A file name that would break
	// the one record per line rule is escaped, and the line is marked.
	mut name := file
	mut marker := ''
	if !settings.zero {
		escaped := escape_name(file)
		name = escaped.text
		marker = escaped.marker
	}
	value := if settings.base64_output { base64.encode(sum.digest) } else { sum.digest.hex() }
	if settings.untagged {
		// The reversed style carries no digest name. A binary marker is used
		// when both --tag and --untagged are given.
		star := if settings.tag { '*' } else { ' ' }
		print('${marker}${value} ${star}${name}${delim}')
		return
	}
	print('${marker}${settings.algorithm.tag(settings.bit_length)} (${name}) = ${value}${delim}')
}

fn print_checksums(settings Settings) {
	mut files := settings.files.clone()
	if files.len == 0 {
		files << '-'
	}
	// GNU only prints the file name when it came from a command line operand.
	show_names := settings.files.len > 0
	for file in files {
		write_digest(settings, file, show_names, read_input(file))
	}
}

fn args() Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.arguments_description('[OPTION]... [FILE]...')
	fp.description(app_description)
	fp.description('By default use the 32 bit CRC algorithm.')
	fp.description('')
	fp.description('With no FILE, or when FILE is -, read standard input.')

	mut settings := Settings{}

	algorithm := fp.string_opt('algorithm', `a`, 'select the digest type to use.  See DIGEST below',
		flag.FlagConfig{
			val_desc: 'TYPE'
		}) or { 'crc' }
	settings.algorithm_given = option_given(os.args, 'algorithm', 'a')
	settings.algorithm = parse_algorithm(algorithm) or {
		common.exit_with_error_message(app_name, invalid_algorithm(algorithm))
	}

	length := fp.string_opt('length', `l`, 'digest length in bits; must not exceed the max size',
		flag.FlagConfig{
			val_desc: 'BITS'
		}) or { '' }
	if length.len > 0 {
		settings.bit_length = check_length(length, settings.algorithm)
	} else {
		settings.bit_length = settings.algorithm.bit_length()
	}

	settings.check = fp.bool_opt('check', `c`, 'read checksums from the FILEs and check them',
		flag.FlagConfig{}) or { false }
	settings.base64_output = fp.bool_opt('base64', 0,
		'emit base64-encoded digests, not hexadecimal', flag.FlagConfig{}) or { false }
	settings.raw = fp.bool_opt('raw', 0, 'emit a raw binary digest, not hexadecimal',
		flag.FlagConfig{}) or { false }
	settings.tag = fp.bool_opt('tag', 0, 'create a BSD-style checksum (the default)',
		flag.FlagConfig{}) or { false }
	settings.untagged = fp.bool_opt('untagged', 0,
		'create a reversed style checksum, without digest type', flag.FlagConfig{}) or { false }
	settings.zero = fp.bool_opt('zero', `z`, 'end each output line with NUL, not newline',
		flag.FlagConfig{}) or { false }

	settings.ignore_missing = fp.bool_opt('ignore-missing', 0,
		"don't fail or report status for missing files", flag.FlagConfig{}) or { false }
	settings.quiet = fp.bool_opt('quiet', 0,
		"don't print OK for each successfully verified file", flag.FlagConfig{}) or { false }
	settings.status = fp.bool_opt('status', 0,
		"don't output anything, status code shows success", flag.FlagConfig{}) or { false }
	settings.strict = fp.bool_opt('strict', 0,
		'exit non-zero for improperly formatted checksum lines', flag.FlagConfig{}) or { false }
	settings.warn = fp.bool_opt('warn', `w`, 'warn about improperly formatted checksum lines',
		flag.FlagConfig{}) or { false }

	settings.files = fp.remaining_parameters()
	return settings
}

// option_given reports whether an option appeared on the command line. V's flag
// module does not record this, and --check has to know whether --algorithm was
// named explicitly, because otherwise the digest to verify with comes from the
// list itself.
fn option_given(args []string, long string, short string) bool {
	for arg in args[1..] {
		if arg == '--${long}' || arg.starts_with('--${long}=') {
			return true
		}
		if short.len > 0 && arg.len > 1 && arg[0] == `-` && arg[1] != `-`
			&& (arg[1] == short[0] || (arg.len > 2 && arg[2] == short[0])) {
			return true
		}
	}
	return false
}

// check_length validates --length. GNU only accepts it for BLAKE2b, whose
// digest length is variable, and it has to be a multiple of 8.
fn check_length(length string, algorithm Algorithm) int {
	bits := strconv.atoi(length) or {
		invalid_length(length, 'invalid number')
	}
	if bits % 8 != 0 {
		invalid_length(length, 'length is not a multiple of 8')
	}
	if !algorithm.accepts_length() {
		app_quit('--length is only supported with --algorithm=blake2b')
	}
	if bits < blake2b_min_bits || bits > blake2b_max_bits {
		invalid_length(length, 'maximum digest length for ‘BLAKE2b’ is ${blake2b_max_bits} bits')
	}
	return bits
}

// invalid_length reports a bad --length. GNU prints two separate diagnostics for
// this, each with its own prefix, and does not suggest --help.
@[noreturn]
fn invalid_length(length string, reason string) {
	eprintln('${app_name}: invalid length: ‘${length}’')
	eprintln('${app_name}: ${reason}')
	exit(1)
}

// app_quit reports an error and exits without the "Try --help" advice, which is
// what GNU does for everything except a bad option or argument.
@[noreturn]
fn app_quit(message string) {
	app.quit(
		message:     message
		return_code: 1
	)
}
