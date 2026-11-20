module main

import common
import os

fn main() {
	args := os.args[1..]
	if args.len == 0 {
		print_banner()
		exit(1)
	}

	sub := args[0]
	sibling := os.dir(os.executable())
	exe := os.join_path(sibling, '${sub}${os.file_ext(os.executable())}')

	if !os.exists(exe) {
		eprintln('${sub}: function/utility not found')
		exit(1)
	}

	// Everything after the sub-utility name is handed through untouched, so
	// the sub-utility's own option parsing decides what it means.
	mut p := os.new_process(exe)
	p.set_args(args[1..])
	p.wait()
	code := p.code
	p.close()
	exit(code)
}

// print_banner writes the multi-call usage line. GNU prints this for no
// operand at all, which is also where the exit status comes from.
fn print_banner() {
	println('coreutils ${common.version} (multi-call binary)')
	println('')
	println('Usage: coreutils [function [arguments...]]')
}
