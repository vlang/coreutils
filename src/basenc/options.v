import common
import flag
import os
import time

const app_name = 'basenc'

struct Options {
	base64    bool
	base64url bool
	base32    bool
	base32hex bool
	base16    bool
	base2msbf bool
	base2lsbf bool
	decode    bool
	wrap      int
	z85       bool
	files     []string
}

fn get_options() Options {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.arguments_description('[FILE]')
	fp.description('\nEncode or decode FILE, or standard input, to standard output.\n' +
		'With no FILE, or when FILE is -, read standard input.'.trim_indent())

	base64 := fp.bool('base64', ` `, false, "same as 'base64' program (RFC4648 section 4)")
	base64url := fp.bool('base64url', ` `, false, 'file- and url-safe base64 (RFC4648 section 5)')
	base32 := fp.bool('base32', ` `, false, 'file- and url-safe base64 (RFC4648 section 5)')
	base32hex := fp.bool('base32hex', ` `, false, 'extended hex alphabet base32 (RFC4648 section 7)')
	base16 := fp.bool('base16', ` `, false, 'hex encoding (RFC4648 section 8)')
	base2msbf := fp.bool('base2msbf', ` `, false, 'bit string with most significant bit (msb) first')
	base2lsbf := fp.bool('base2lsbf', ` `, false, 'bit string with least significant bit (lsb) first')
	decode := fp.bool('decode', `d`, false, 'decode data')
	wrap := fp.int('wrap', `w`, 76,
		'wrap encoded lines after <int> COLS character (default 76)\n${flag.space}' +
		'Use 0 to disable line wrapping')
	z85 := fp.bool('z85', ` `, false,
		'ascii85-like encoding (ZeroMQ spec:32/Z85); when encoding,\n${flag.space}' +
		'input length must be a multiple of 4; when decoding, input\n${flag.space}' +
		'length must be a multiple of 5\n')

	files := fp.finalize() or { exit_error(err.msg()) }

	return Options{
		base64:    base64
		base64url: base64url
		base32:    base32
		base32hex: base32hex
		base16:    base16
		base2msbf: base2msbf
		base2lsbf: base2lsbf
		decode:    decode
		wrap:      wrap
		z85:       z85
		files:     scan_files_arg(files)
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
