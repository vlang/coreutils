import common
import common.testing

const rig = testing.prepare_rig(util: 'users')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_compare() {
	rig.assert_same_results('')
	rig.assert_same_results('does_not_exist')
	unsafe { rig.assert_same_results(cstring_to_vstring(common.utmp_file_charptr)) }
	unsafe { rig.assert_same_results(cstring_to_vstring(common.wtmp_file_charptr)) }
}

fn test_call_errors() {
	rig.assert_same_exit_code('-x')
	rig.assert_same_results('a b c')
}
