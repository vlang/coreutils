import common
import common.mknod as mknodmod
import os

const app_name = 'mknod'

// Settings for Utility: mknod
struct Settings {
mut:
	mode      u32
	mode_text string
	selinux   bool // -Z / --context=CTX
}

fn main() {
	settings, rest := args()!
	if rest.len == 0 {
		common.exit_with_error_message(app_name, 'missing operand')
	}
	path := rest[0]
	if rest.len < 2 {
		common.exit_with_error_message(app_name, 'missing operand after ‘${path}’')
	}
	kind := rest[1][0]

	mut dev := u64(0)
	mut mode := settings.mode

	// A FIFO takes no device numbers; the character and block devices do.
	if kind == `b` || kind == `c` {
		if rest.len < 4 {
			common.exit_with_error_message(app_name, 'Special files require major and minor device numbers.')
		}
		major := rest[2].int()
		minor := rest[3].int()
		dev = mknodmod.device_number(major, minor)
		mode |= mknodmod.type_bits(kind)
	} else if kind == `p` {
		if rest.len > 2 {
			common.exit_with_error_message(app_name, 'extra operand ‘${rest[2]}’')
		}
		mode |= mknodmod.s_ififo
	} else {
		common.exit_with_error_message(app_name, 'invalid device type ‘${kind.ascii_str()}’')
	}

	if os.exists(path) {
		common.exit_with_error_message(app_name, '${path}: File exists')
	}

	res := make_node(path, kind, mode, dev)
	if res != 0 {
		common.exit_with_error_message(app_name, 'cannot create ${quoted(path)}: Operation not permitted')
	}
}

fn quoted(s string) string {
	// GNU wraps the operand in single quotes and escapes any embedded
	// single quote as '\'' (close, escaped quote, reopen).
	return "'" + s.replace("'", "'\\''") + "'"
}

fn args() !(Settings, []string) {
	mut st := Settings{
		mode: 0o666 & ~umask_value()
	}
	mut rest := []string{}

	args := os.args[1..]
	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('mknod (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '--' {
			rest << args[i + 1..]
			break
		}
		if a.starts_with('--mode=') {
			st.mode_text = a['--mode='.len..]
			st.mode = mknodmod.parse_mode(st.mode_text)
			continue
		}
		if a.starts_with('--') {
			common.exit_with_error_message(app_name, "unrecognized option '${a}'")
		}
		if a.starts_with('-') && a.len > 1 {
			if a[1] == `m` {
				value := if a.len > 2 { a[2..] } else { args[i + 1] }
				st.mode_text = value
				st.mode = mknodmod.parse_mode(value)
				if a.len <= 2 {
					i++
				}
				continue
			}
			if a[1] == `Z` {
				st.selinux = true
				continue
			}
			common.exit_with_error_message(app_name, "invalid option -- '${a[1].ascii_str()}'")
		}
		rest << a
	}
	return st, rest
}

fn umask_value() u32 {
	// Read the actual process umask rather than assuming 0o022, which is what
	// GNU applies when no -m is given.
	return read_umask()
}

fn print_help() {
	println('Usage: mknod [OPTION]... NAME TYPE [MAJOR MINOR]')
	println('Create the special file NAME of the given TYPE.')
	println('')
	println('  -m, --mode=MODE   set file permission bits of NAME to MODE')
	println('  -Z                set the SELinux security context to the default type')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
