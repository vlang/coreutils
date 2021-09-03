import os
import common

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('uname')
	fp.description('Print certain system information.')
	fp.description('With no `options`, same as `-s`.')
	opt_all := fp.bool('all', `a`, false, 'print all information, except omit -p and -i if unknown')
	mut opt_map := {
		`s`: fp.bool('kernel-name', `s`, false, 'print the kernel name')
		`n`: fp.bool('nodename', `n`, false, 'print the network node hostname')
		`r`: fp.bool('kernel-release', `r`, false, 'print the kernel release')
		`v`: fp.bool('kernel-version', `v`, false, 'print the kernel version')
		`m`: fp.bool('machine', `m`, false, 'print the machine hardware name')
		/*`p`: fp.bool('processor', `p`, false, 'print the processor type (non-portable)')
		`i`: fp.bool('hardware-platform', `i`, false, 'print the hardware pltfoarm (non-portable)')
		`o`: fp.bool('operating-system', `o`, false, 'print the operating system')*/
	}
	if os.args.len == 1 {
		opt_map[`s`] = true // default output
	}
	remaining := fp.remaining_parameters()
	unkown := remaining.filter(it[0] != `-`) // uname x
	if unkown.len > 0 {
		common.exit_with_error_message(fp.application_name, 'Expected no arguments, but given $unkown.len')
	}
	// uname -sxv
	outer: for flag in remaining.filter(it[0] == `-`) {
		for c in flag[1..] {
			if c !in opt_map.keys() {
				common.exit_with_error_message(fp.application_name, 'Unknown flag `$c.ascii_str()`')
			}
		}
	}
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
				// the original gets processor & hardware platform from
				// - `sysinfo()` in `sys/systeminfo.h`, or
				// - `sysctl()` in  `sys/sysctl.h`
				/*`p` {
					result << uname.machine // Not sure
				}*/
				/*`i` {
					result << uname.machine // Not sure
				}*/
				// the original prints `HOST_OPERATING_SYSTEM` which is in `config.h`
				/*`o` {
					result << '<operating-system>'
				}*/
				else {}
			}
		}
	}
	if result.len > 0 {
		println(result.join(' '))
	}
}
