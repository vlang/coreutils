import os
import common

const app_name = 'pathchk'
// GNU takes NAME_MAX from the filesystem, which is 255 on most but is not always:
// the WSL filesystem this was measured on reports 14, and there a 26 character name
// is rejected where this accepts it. V exposes no pathconf, so the POSIX value is
// used and the difference is limited to filesystems with a smaller NAME_MAX.
const name_max = 255
const path_max = 4096

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Check whether file names are valid or portable.')
	portable := fp.bool('portable', `p`, false, 'check for most portable file names')
	strict := fp.bool('no-empty', `P`, false, 'check for empty and leading dash names')
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	fp.allow_unknown_args()
	if help {
		println(fp.usage())
		return
	}
	if version {
		println('${app_name} ${common.coreutils_version()}')
		return
	}
	fp.finalize()!

	operands := fp.remaining_parameters()
	if operands.len == 0 {
		// GNU reports a missing operand rather than doing nothing.
		eprintln('${app_name}: missing operand')
		eprintln("Try '${app_name} --help' for more information.")
		exit(1)
	}
	mut failed := false
	for path in operands {
		if !check(path, portable, strict) {
			failed = true
		}
	}
	if failed {
		exit(1)
	}
}

fn check(path string, portable bool, strict bool) bool {
	// An empty path is a stat failure in the default mode, but -P reports it as an
	// empty component instead, so the two are told apart here.
	if path == '' && !strict {
		eprintln("${app_name}: '': No such file or directory")
		return false
	}
	if path.len > path_max {
		eprintln("${app_name}: limit ${path_max} exceeded by length ${path.len} of file name '${path}'")
		return false
	}
	components := path.split('/')
	for i, comp in components {
		// The leading slash of an absolute path splits into an empty first
		// component, which is not the empty name -P is looking for.
		if i == 0 && comp == '' && path.starts_with('/') {
			continue
		}
		if portable && !is_portable(comp) {
			eprintln("${app_name}: non-portable character in file name '${path}'")
			return false
		}
		if strict && comp == '' {
			eprintln('${app_name}: empty file name')
			return false
		}
		if strict && comp.starts_with('-') {
			eprintln("${app_name}: leading '-' in a component of file name '${path}'")
			return false
		}
		if comp.len > name_max {
			eprintln("${app_name}: limit ${name_max} exceeded by length ${comp.len} of file name '${comp}'")
			return false
		}
	}
	return true
}

fn is_portable(comp string) bool {
	for c in comp {
		if !((c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `.`
			|| c == `_` || c == `-`) {
			return false
		}
	}
	return true
}
