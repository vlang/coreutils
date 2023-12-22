module main

import os
import common
import io

const app_name = 'sum'
const app_description = 'Print checksum and block counts for each file in ARGS.'

struct Args {
	use_bsd  bool
	use_sysv bool
	fnames   []string
}

struct Sum {
	checksum    int
	block_count u64
mut:
	file_name string
}

const bsd_block_size = 1024
const sysv_block_size = 512
const buffer_length = 128 * 1024

// bsd_sum_stream calculates checksum using BSD algorithm
fn bsd_sum_stream(bytes []u8, checksum int, _ bool) int {
	mut tmp_checksum := checksum

	for b in bytes {
		tmp_checksum = (tmp_checksum >> 1) + ((tmp_checksum & 1) << 15)
		tmp_checksum += b
		tmp_checksum &= 0xffff
	}

	return tmp_checksum
}

// sysv_sum_stream calculates checksum using SysV algorithm
fn sysv_sum_stream(bytes []u8, checksum int, is_final_chunk bool) int {
	mut temp := checksum

	for b in bytes {
		temp += b
	}

	if is_final_chunk {
		r := (temp & 0xffff) + ((temp & 0xffffffff) >> 16)
		return (r & 0xffff) + (r >> 16)
	} else {
		return temp
	}
}

fn get_file_block_count(file string, block_size int) u64 {
	file_size := os.file_size(file)
	mut blocks := file_size / u64(block_size)
	if file_size % u64(block_size) != 0 {
		blocks += 1
	}
	return blocks
}

fn get_stream_block_count(read_byte_count int, block_size int, current_count u64) u64 {
	if read_byte_count % block_size != 0 {
		return current_count + u64(read_byte_count / block_size) + 1
	} else {
		return current_count + u64(read_byte_count / block_size)
	}
}

fn rjust(s string, width int) string {
	if width == 0 {
		return s
	}
	return ' '.repeat(width - s.len) + s
}

fn calc_sums(args Args) []Sum {
	mut files := args.fnames.clone()

	// read from stdin if no files supplied
	if files.len < 1 {
		files = ['-']
	}

	sum_stream := match args.use_sysv {
		true { sysv_sum_stream }
		false { bsd_sum_stream }
	}
	block_size := match args.use_sysv {
		true { sysv_block_size }
		false { bsd_block_size }
	}

	mut f := os.File{}
	mut buf := []u8{len: buffer_length, cap: buffer_length}
	mut blocks := u64(0)
	mut sums := []Sum{}

	for file in files {
		if file == '-' {
			f = os.stdin()
		} else {
			f = os.open(file) or { panic(err) }
			defer {
				f.close()
			}
		}

		mut rd := io.new_buffered_reader(io.BufferedReaderConfig{ reader: f })
		mut checksum := 0

		for {
			res := rd.read(mut buf) or { break }
			checksum = sum_stream(buf[..res], checksum, false)

			if file == '-' {
				blocks = get_stream_block_count(res, block_size, blocks)
			}
		}
		if args.use_sysv {
			checksum = sum_stream([]u8{}, checksum, true)
		}

		if file != '-' {
			blocks = get_file_block_count(file, block_size)
		}

		file_name := match file {
			'-' { '' }
			else { ' ${file}' }
		}
		sums << Sum{checksum, blocks, file_name}
	}
	return sums
}

fn print_sysv(sums []Sum) {
	for sum in sums {
		println('${sum.checksum} ${sum.block_count}${sum.file_name}')
	}
}

fn print_bsd(mut sums []Sum) {
	if sums.len == 1 {
		sums[0].file_name = ''
	}
	for sum in sums {
		mut block_str := sum.block_count.str()
		if block_str.len <= 5 {
			block_str = rjust(block_str, 5)
		}
		checksum_str := '${sum.checksum:05}'
		println('${checksum_str} ${block_str}${sum.file_name}')
	}
}

fn parse_args() Args {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	mut use_bsd := fp.bool('', `r`, true, 'use BSD sum algorithm, use 1K blocks')
	mut use_sysv := fp.bool('sysv', `s`, false, 'use System V sum algorithm, use 512 bytes blocks')

	fnames := fp.remaining_parameters()

	// emulate original algorithm switches behavior
	if '-rs' in os.args {
		use_bsd = false
		use_sysv = true
	}
	if '-sr' in os.args {
		use_bsd = true
		use_sysv = false
	}
	return Args{use_bsd, use_sysv, fnames}
}

fn main() {
	args := parse_args()
	mut sums := calc_sums(args)

	if args.use_sysv {
		print_sysv(sums)
	} else if args.use_bsd {
		print_bsd(mut sums)
	} else {
		panic('this should never happen')
	}
}
