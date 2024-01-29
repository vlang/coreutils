module main

import os
import common
import io
import arrays

const app_name = 'cksum'
const app_description = 'Print CRC checksum and byte counts of each FILE.'
const buffer_length = 128 * 1024

struct Args {
	fnames []string
}

fn swap_32(x u32) u32 {
	return ((x & 0xff000000) >> 24) | ((x & 0x00ff0000) >> 8) | ((x & 0x0000ff00) << 8) | ((x & 0x000000ff) << 24)
}

fn calc_sums(args Args) {
	mut files := args.fnames.clone()

	// read from stdin if no files supplied
	if files.len < 1 {
		files = ['-']
	}

	mut f := os.File{}
	mut buf := []u8{len: buffer_length, cap: buffer_length}

	for file in files {
		if file == '-' {
			f = os.stdin()
		} else {
			f = os.open(file) or {
				eprintln('cksum: ${file}: No such file or directory')
				exit(1)
			}
			defer {
				f.close()
			}
		}

		mut rd := io.new_buffered_reader(io.BufferedReaderConfig{ reader: f, cap: buffer_length })
		mut crc := u64(0)
		mut total_length := u64(0)

		for {
			res := u64(rd.read(mut buf) or { break })

			chunks := res / 8
			for outer := 0; outer < chunks; outer++ {
				chunk := buf[outer * 8..outer * 8 + 8].clone()
				first := four_bytes_to_int(chunk[..4])
				mut second := four_bytes_to_int(chunk[4..])

				crc ^= swap_32(first)
				second = swap_32(second)
				// println('${crc} ${second}')

				crc = crctab[7][(crc >> 24) & 0xFF] ^ crctab[6][(crc >> 16) & 0xFF] ^ crctab[5][(crc >> 8) & 0xFF] ^ crctab[4][crc & 0xFF] ^ crctab[3][(second >> 24) & 0xFF] ^ crctab[2][(second >> 16) & 0xFF] ^ crctab[1][(second >> 8) & 0xFF] ^ crctab[0][second & 0xFF]
			}

			remaining_len := res - chunks * 8
			if remaining_len > 0 {
				rest := buf[8 * chunks..].clone()
				crc = cksum_slice8(rest, crc, remaining_len)
			}
			total_length = u64(rd.total_read)
		}

		mut len_counter := total_length
		for ; len_counter; len_counter >>= 8 {
			crc = (crc << 8) ^ crctab[0][((crc >> 24) ^ len_counter) & 0xFF]
		}
		crc = ~crc & 0xffff_ffff

		file_str := match file {
			'-' { '' }
			else { file }
		}
		println('${crc} ${total_length} ${file_str}')
	}
}

fn cksum_slice8(buf []u8, crc_in u64, remaining_len u64) u64 {
	mut crc_tmp := crc_in

	for i := 0; i < remaining_len; i++ {
		cp := buf[i]
		index := ((crc_tmp >> 24) ^ cp) & 0xFF
		tab_value := crctab[0][index]
		crc_shift := crc_tmp << 8
		crc_tmp = crc_shift ^ tab_value
	}

	return crc_tmp
}

fn id[T](x T) T {
	return x
}

fn four_bytes_to_int(bytes []u8) u32 {
	// emulates original evil type punning
	// TODO this is *damn* slow -- rewrite via evil bit hacking
	mut tmp_bytes := []string{}
	for c in bytes.reverse() {
		tmp_bytes << c.hex()
	}
	return u32(arrays.join_to_string[string](tmp_bytes, '', id[string])
		.parse_uint(16, 32) or { panic(err) })
}

fn parse_args() Args {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	fnames := fp.remaining_parameters()
	return Args{fnames}
}

fn main() {
	calc_sums(parse_args())
}
