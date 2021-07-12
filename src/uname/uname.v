import os
import common

fn main() {
	mut exit_code := 0
	mut fp := common.flag_parser(os.args)
	fp.application('uname')
	fp.description('Print certain system information.')
	fp.description('With no `options`, same as `-s`.')
	opt_all := fp.bool('all', `a`, false, 'print all information, except omit -p and -i if unknown')
	mut opt_map := map{
		`s`: fp.bool('kernel-name', `s`, true, 'print the kernel name')
		`n`: fp.bool('nodename', `n`, false, 'print the network node hostname')
		`r`: fp.bool('kernel-release', `r`, false, 'print the kernel release')
		`v`: fp.bool('kernel-version', `v`, false, 'print the kernel version')
		`m`: fp.bool('machine', `m`, false, 'print the machine hardware name')
		/*`p`: fp.bool('processor', `p`, false, 'print the processor type (non-portable)')
		`i`: fp.bool('hardware-platform', `i`, false, 'print the hardware pltfoarm (non-portable)')
		`o`: fp.bool('operating-system', `o`, false, 'print the operating system')*/
	}
	fp.remaining_parameters()
	// Main functionality
	uname := os.uname()
	mut result := []string{}
	for addr, b in opt_map {
		if b || opt_all {
			match addr {
				`s` {
					result << uname.sysname
				}
				`n` {
					result << uname.nodename
				}
				`r` {
					result << uname.release
				}
				`v` {
					result << uname.version
				}
				`m` {
					result << uname.machine
				}
				/*`p` {
					result << '<processor>'
				}
				`i` {
					result << '<hardware-platform>'
				}
				`o` {
					result << '<operating-system>'
				}*/
				else {}
			}
		}
	}
	if result.len > 0 {
		println(result.join(' '))
	}
	exit(exit_code)
}
