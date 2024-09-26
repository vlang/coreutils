import os

struct Sum {
	checksum    u16
	block_count u64
mut:
	file_name string
}

const bsd_block_size = 1024
const sysv_block_size = 512

fn main() {
	args := parse_args(os.args)
	mut sums := []Sum{}
	mut block_size := match args.sys_v {
		true { sysv_block_size }
		false { bsd_block_size }
	}

	for file in args.files {
		checksum, mut blocks, file_name := sum(file, args.sys_v)
		blocks = get_file_block_count(file, block_size)
		sums << Sum{checksum, blocks, file_name}
	}

	if args.sys_v {
		print_sysv(sums)
	} else {
		print_bsd(mut sums)
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

fn print_sysv(sums []Sum) {
	for sum in sums {
		println('${sum.checksum} ${sum.block_count}${sum.file_name}'.trim_space())
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
		println('${checksum_str} ${block_str}${sum.file_name}'.trim_space())
	}
}

fn rjust(s string, width int) string {
	if width == 0 {
		return s
	}
	return ' '.repeat(width - s.len) + s
}

fn sum(file string, sys_v bool) (u16, u64, string) {
	digest, blocks := match sys_v {
		true { sum_sys_v(file) }
		else { sum_bsd(file) }
	}

	name := if file.contains('/sum-') { '' } else { ' ${file}' }
	return digest, blocks, name
}

fn sum_bsd(file string) (u16, u64) {
	mut checksum := u16(0)
	mut blocks := u64(0)
	mut f := os.open(file) or { exit_error(err.msg()) }
	defer { f.close() }

	for {
		c := f.read_raw[u8]() or { break }
		checksum = (checksum >> 1) + ((checksum & 1) << 15)
		checksum += c
		checksum &= 0xffff
	}

	return checksum, blocks
}

fn sum_sys_v(file string) (u16, u64) {
	mut sum := u32(0)
	mut blocks := u64(0)
	mut f := os.open(file) or { exit_error(err.msg()) }
	defer { f.close() }

	for {
		c := f.read_raw[u8]() or { break }
		sum += c
	}

	r := (sum & 0xffff) + ((sum & 0xffffffff) >> 16)
	checksum := u16((r & 0xffff) + (r >> 16))
	return checksum, blocks
}
