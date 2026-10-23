import common.ptx as ptxmod
import os
import io

fn main() {
	set := ptxmod.parse_args(os.args[1..])

	mut data := []u8{}
	if set.operands.len == 0 {
		data = read_stdin()
	} else {
		for operand in set.operands {
			if operand == '-' {
				data << read_stdin()
				continue
			}
			if !os.exists(operand) {
				eprintln('ptx: ${operand}: No such file or directory')
				exit(1)
			}
			data << read_file(operand)
		}
	}

	mut entries := ptxmod.build_entries(data.bytestr(), set)
	ptxmod.sort_entries(mut entries)
	rows := ptxmod.render(entries, set)
	if rows.len > 0 {
		println(rows.join('\n'))
	}
}

// read_file is a one-line wrapper so the array-returning call sits at the top
// level of a function, where codegen handles it.
fn read_file(path string) []u8 {
	return os.read_file_array(path)
}

// read_stdin drains standard input in explicit chunks. io.read_all is not used
// here because it stops early on this platform, which produced a single
// truncated row instead of the whole index.
fn read_stdin() []u8 {
	mut out := []u8{}
	mut chunk := []u8{len: 64 * 1024}
	mut f := os.stdin()
	for {
		n := f.read(mut chunk) or { break }
		if n == 0 {
			break
		}
		out << chunk[..n]
	}
	return out
}
