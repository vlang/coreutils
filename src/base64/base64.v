import os
import flag
import encoding.base64

const (
	application_name   = 'base64'

	// multiple of 3 so we can encode the data in chunks and concatenate
	chunk_size_encode  = 15 * 1024

	// 4/3 of chunk_size_encode
	buffer_size_encode = 4 * (15 / 3) * 1024

	// multiple of 4 so we can decode the data in chunks and concatenate
	chunk_size_decode  = 16 * 1024

	// 3/4 of chunk_size_decode
	buffer_size_decode = 3 * (16 / 4) * 1024
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

	// read the file in chunks for constant memory usage.
	mut pos := u64(0)
	for {
		r_bytes := file.read_bytes_into(pos, mut in_buffer) or {
			match err {
				none {
					0
				}
				else {
					-1
				}
			}
		}

		match r_bytes {
			0 {
				break
			}
			-1 {
				eprintln('$application_name: Cannot read file')
				exit(1)
			}
			else {
				pos += u64(r_bytes)
			}
		}

		e_bytes := base64.encode_in_buffer(in_buffer[..r_bytes], out_buffer.data)

		// print newlines after specified wrap.
		if wrap != 0 {
			mut p_bytes := 0
			for ((e_bytes - p_bytes) >= wrap) {
				write_to := p_bytes + wrap
				std_out.write(out_buffer[p_bytes..write_to]) or {
					eprintln(err)
					exit(1)
				}
				// flushing is needed here, as otherwise all writes are cached.
				std_out.flush()
				print('\n')
				p_bytes += wrap
			}
			// print rest of the data.
			l_bytes := std_out.write(out_buffer[p_bytes..e_bytes]) or {
				eprintln(err)
				exit(1)
			}
			std_out.flush()
			if l_bytes != 0 {
				print('\n')
			}
		} else {
			std_out.write(out_buffer[..e_bytes]) or {
				eprintln(err)
				exit(1)
			}
		}
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
	mut pos := u64(0)
	for {
		r_bytes := file.read_bytes_into(pos, mut in_buffer) or {
			match err {
				none {
					0
				}
				else {
					-1
				}
			}
		}

		match r_bytes {
			0 {
				break
			}
			-1 {
				eprintln('$application_name: Cannot read file')
				exit(1)
			}
			else {
				pos += u64(r_bytes)
			}
		}

		unsafe {
			base64_string := tos(in_buffer.data, r_bytes)
			e_bytes := base64.decode_in_buffer(base64_string, out_buffer.data)
			std_out.write(out_buffer[..e_bytes]) or {
				eprintln(err)
				exit(1)
			}
		}
	}
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(application_name)
	fp.version('(V coreutils 0.0.1)')
	fp.skip_executable()
	fp.usage_example('[OPTION]... [FILE]')
	fp.description('Base64 encode or decode FILE, or standard input, to standard output.')
	fp.description('If no FILE is specified on the command line or FILE is -, read them from standard input.')

	decode_opt := fp.bool('decode', `d`, false, 'decode data')
	wraping_opt := fp.int('wrap=', `w`, 76, 'wrap encoded lines after COLS character (default 76).\n\t\t\t\tUse 0 to disable line wrapping')
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
