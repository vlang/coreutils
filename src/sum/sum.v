import os

const app_name = 'sum'

struct Args {
	sys_v bool
	files []string
}

fn main() {
	args := parse_args(os.args)

	for file in args.files {
		println(sum(file, args.sys_v))
	}
}

fn sum(file string, sys_v bool) string {
	digest, blocks := match sys_v {
		true { sum_sys_v(file) }
		else { sum_bsd(file) }
	}

	name := if file.contains('/sum-') { '' } else { file }
	return '${digest:5} ${blocks:5} ${name}'
}

fn sum_bsd(file string) (u16, int) {
	mut count := 0
	mut checksum := u16(0)
	mut f := os.open(file) or { exit_error(err.msg()) }
	defer { f.close() }

	for {
		c := f.read_raw[u8]() or { break }
		checksum = (checksum >> 1) + ((checksum & 1) << 15)
		checksum += c
		checksum &= 0xffff
		count += 1
	}

	blocks := count / 1024 + 1
	return checksum, blocks
}

fn sum_sys_v(file string) (u16, int) {
	mut sum := u32(0)
	mut count := u32(0)
	mut f := os.open(file) or { exit_error(err.msg()) }
	defer { f.close() }

	for {
		c := f.read_raw[u8]() or { break }
		sum += c
		count += 1
	}

	r := (sum & 0xffff) + ((sum & 0xffffffff) >> 16)
	checksum := u16((r & 0xffff) + (r >> 16))
	blocks := count / 512 + 1
	return checksum, blocks
}
