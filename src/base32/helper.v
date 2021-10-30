import os
import bitfield
import strings
import common

const (
	name              = 'base32'
	block_size        = 5
	group_size        = 5
	bits_in_byte      = 8
	init_builder_size = 1024
	end_byte          = `=`
	char_set          = [`A`, `B`, `C`, `D`, `E`, `F`, `G`, `H`, `I`, `J`, `K`, `L`, `M`, `N`,
		`O`, `P`, `Q`, `R`, `S`, `T`, `U`, `V`, `W`, `X`, `Y`, `Z`, `2`, `3`, `4`, `5`, `6`, `7`,
		`=`]
	invalid           = 'invalid input'
)

fn get_blocks(groups []byte) []byte {
	mut full_block := bitfield.new(block_size * bits_in_byte)
	mut i := 0
	for group in groups {
		byte_val := if `A` <= group && group <= `Z` {
			byte(group - `A`)
		} else if `2` <= group && group <= `7` {
			byte(26 + group - `2`)
		} else {
			byte(1 << group_size)
		}
		full_block.insert(i, group_size, byte_val)
		i += group_size
	}
	size := full_block.get_size()
	mut res := []byte{}
	for i = 0; i < size; i += bits_in_byte {
		res << byte(full_block.extract(i, bits_in_byte))
	}
	return res
}

fn decode_and_output(file os.File, wrap int) {
	mut groups := []byte{len: block_size * bits_in_byte / group_size}
	mut builder := strings.new_builder(init_builder_size)
	mut i := u64(0)
	for {
		num := file.read_bytes_into(i, mut groups) or {
			common.exit_with_error_message(name, err.msg)
		}
		if num == 0 || (num == 1 && groups[0] == `\n`) {
			break
		} else if num < groups.len {
			common.exit_with_error_message(name, invalid)
		}
		i += u64(num)
		builder.write(get_blocks(groups)) or { common.exit_with_error_message(name, err.msg) }
	}
	print(builder.str())
}

// IMP: This code assumes that each group_size <= 8 bits (1 byte).
// If using groups without this property, change the return type
fn get_groups(block []byte, num byte) []byte {
	full_block := bitfield.from_bytes(block)
	mut groups := []byte{}
	num_blocks := block_size * bits_in_byte / group_size
	for i in 0 .. num_blocks {
		byte_val := byte(full_block.extract(i * group_size, group_size))
		groups << if byte_val < 26 { byte_val + `A` } else { byte_val - 26 + `2` }
	}
	for i in 0 .. num {
		groups[groups.len - i - 1] = end_byte
	}
	return groups
}

fn encode_and_output(file os.File, wrap int) {
	mut block := []byte{len: block_size}
	mut i := u64(0)
	mut done := false
	for !done {
		num := file.read_bytes_into(i, mut block) or {
			match err {
				none {
					0
				}
				else {
					common.exit_with_error_message(name, err.msg)
				}
			}
		}
		if num == 0 {
			break
		}
		done = num < block_size
		i += u64(num)

		for j in num .. block_size {
			block[j] = 0
		}

		num_equal := match num {
			1 { 6 }
			2 { 4 }
			3 { 3 }
			4 { 1 }
			else { 0 }
		}
		groups := get_groups(block, byte(num_equal))
		mut result := strings.new_builder(groups.len)
		result.write(groups) or { common.exit_with_error_message(name, err.msg) }
		print(result.str())
	}
	println('')
}

fn get_file(file_arg []string) os.File {
	if file_arg.len == 0 || file_arg[0] == '-' {
		return os.stdin()
	} else {
		return os.open(file_arg[0]) or { common.exit_with_error_message(name, err.msg) }
	}
}

fn run_base32(args []string) {
	mut fp := common.flag_parser(os.args)
	fp.application(name)
	fp.usage_example('[OPTION]... [FILE]')
	fp.description('Base32 encode or decode FILE, or standard input, to standard output.')
	fp.description('If no FILE is specified on the command line or FILE is -, read them from standard input.')

	decode := fp.bool('decode', `d`, false, 'decode data')
	wrap := fp.int('wrap=', `w`, 76, 'wrap encoded lines after COLS character (default 76).' +
		'\n\t\t\t\t\t\t\t\t\tUse 0 to disable line wrapping altogether.')
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('$name $common.coreutils_version()')
	}
	file_arg := fp.finalize() or { common.exit_with_error_message(name, err.msg) }

	if file_arg.len > 1 {
		common.exit_with_error_message(name, 'only one file should be provided')
	}
	file := get_file(file_arg)
	if decode {
		decode_and_output(file, wrap)
	} else {
		encode_and_output(file, wrap)
	}
	// println(args)
}

[noreturn]
fn success_exit(msg string) {
	println(msg)
	exit(0)
}

[noreturn]
fn error_exit(msg string) {
	eprintln(msg)
	exit(1)
}
