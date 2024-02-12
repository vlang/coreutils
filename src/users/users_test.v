import common
import common.testing

const supported_platform = $if windows {
	false
} $else {
	true
} // No utmp in Windows
const rig = testing.prepare_rig(util: 'users', is_supported_platform: supported_platform)

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	if !supported_platform {
		return
	}
	rig.assert_help_and_version_options_work()
}

fn test_compare() {
	if !supported_platform {
		return
	}
	rig.assert_same_results('')
	rig.assert_same_results('does_not_exist')
	// // Don't even try to compile this for Windows
	$if !windows {
		unsafe { rig.assert_same_results(cstring_to_vstring(common.utmp_file_charptr)) }
		unsafe { rig.assert_same_results(cstring_to_vstring(common.wtmp_file_charptr)) }
	}
}

fn test_call_errors() {
	if !supported_platform {
		return
	}
	rig.assert_same_exit_code('-x')
	rig.assert_same_results('a b c')
}
