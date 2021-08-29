import os
import common
import encoding.base64

const (
	application_name   = 'base64'

	// multiple of 3 so we can encode the data in chunks and concatenate
	chunk_size_encode  = 15 * 1024

	// 4/3 of chunk_size_encode
	buffer_size_encode = 4 * (15 / 3) * 1024

	// multiple of 4 so we can decode the data in chunks and concatenate
	chunk_size_decode  = 16 * 1024

	// more than 3/4 of chunk_size_decode
	buffer_size_decode = 16 * 1024

	newline            = []byte{len: 1, init: `\n`}
)

fn get_file(args []string) os.File {
	if args.len == 0 || args[0] == '-' {
		return os.stdin()
	} else {
		file_path := args[0]
		return os.open(file_path) or {
			eprintln('$application_name: $file_path: No such file or directory')
			exit(1)
		}
	}
}

fn encode_and_print(mut file os.File, wrap int) {
	mut std_out := os.stdout()
	defer {
		file.close()
		std_out.close()
	}
	mut in_buffer := []byte{len: chunk_size_encode}
	mut out_buffer := []byte{len: buffer_size_encode}

	// remember last column that was printed in the previous chunk.
	mut last_column := 0
	// read the file in chunks for constant memory usage.
	mut pos := u64(0)
	for {
		read_bytes := file.read_bytes_into(pos, mut in_buffer) or {
			match err {
				none {
					0
				}
				else {
					-1
				}
			}
		}

		match read_bytes {
			0 {
				break
			}
			-1 {
				eprintln('$application_name: Cannot read file')
				exit(1)
			}
			else {
				pos += u64(read_bytes)
			}
		}

		encoded_bytes := base64.encode_in_buffer(in_buffer[..read_bytes], out_buffer.data)

		// print newlines after specified wrap.
		if wrap != 0 {
			mut printed_bytes := 0
			for ((encoded_bytes - printed_bytes) >= wrap) {
				// Don't write further than wrap.
				write_to := printed_bytes + wrap - last_column
				std_out.write(out_buffer[printed_bytes..write_to]) or {
					eprintln(err)
					exit(1)
				}
				std_out.write(newline) or {
					eprintln(err)
					exit(1)
				}
				printed_bytes += wrap - last_column
				// reset last_column as we have filled up the row.
				last_column = 0
			}
			// print rest of the data.
			std_out.write(out_buffer[printed_bytes..encoded_bytes]) or {
				eprintln(err)
				exit(1)
			}
			// flush here, as otherwise the very final newline is printed
			// before the data that's actually left.
			std_out.flush()
			// remember column for the next chunk.
			last_column = encoded_bytes - printed_bytes
		} else {
			std_out.write(out_buffer[..encoded_bytes]) or {
				eprintln(err)
				exit(1)
			}
		}
	}
	// print final \n only if there is no newline yet and wrapping is enabled.
	if wrap != 0 && last_column != 0 {
		print('\n')
	}
}

fn decode_and_print(mut file os.File) {
	mut std_out := os.stdout()
	defer {
		file.close()
		std_out.close()
	}
	mut in_buffer := []byte{len: chunk_size_decode}
	mut out_buffer := []byte{len: buffer_size_decode}

	// read the file in chunks for constant memory usage.
	for {
		mut n_bytes := 0
		// using slice magic to overwrite possible '\n' and fill the single
		// buffer with base64 encoded data only.
		for {
			read_bytes := file.read_bytes_into_newline(mut in_buffer[n_bytes..]) or {
				eprintln('$application_name: Cannot read file')
				exit(1)
			}
			// edge case, when buffer is filled completely and last element it not \n.
			if read_bytes == 0 || ((n_bytes + read_bytes) == buffer_size_decode
				&& in_buffer.last() != `\n`)
				|| in_buffer[n_bytes + read_bytes - 1] != `\n` { // edge case, last read byte is not a newline.
				n_bytes = n_bytes + read_bytes
				break
			}
			n_bytes = n_bytes + read_bytes - 1 // overwrite newline
		}
		if n_bytes <= 0 {
			break
		}
		unsafe {
			base64_string := tos(in_buffer.data, n_bytes)
			decoded_bytes := base64.decode_in_buffer(base64_string, out_buffer.data)
			std_out.write(out_buffer[..decoded_bytes]) or {
				eprintln(err)
				exit(1)
			}
		}
	}
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(application_name)
	fp.usage_example('[OPTION]... [FILE]')
	fp.description('Base64 encode or decode FILE, or standard input, to standard output.')
	fp.description('If no FILE is specified on the command line or FILE is -, read them from standard input.')

	decode_opt := fp.bool('decode', `d`, false, 'decode data')
	wraping_opt := fp.int('wrap=', `w`, 76,
		'wrap encoded lines after COLS character (default 76).' +
		'\n\t\t\t\t\t\t\t\t\tUse 0 to disable line wrapping.')
	args := fp.finalize() or {
		eprintln(err)
		exit(1)
	}
	if args.len > 1 {
		extra_arg := args[1]
		eprintln('$application_name: extra operand `$extra_arg`')
		eprintln("Try 'base64 --help' for more information.")
		exit(1)
	}
	if wraping_opt < 0 {
		eprintln('$application_name: invalid wrap size: \'$wraping_opt\'')
		exit(1)
	}

	mut file := get_file(args)

	match decode_opt {
		true { decode_and_print(mut file) }
		else { encode_and_print(mut file, wraping_opt) }
	}
}
