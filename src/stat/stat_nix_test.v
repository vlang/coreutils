import common.testing
import os

const rig = testing.prepare_rig(util: 'stat')

fn testsuite_begin() {
	os.write_file('a', '')!
	os.write_file('b', '42')!
	os.mkdir('c')!
	os.write_file('c/a', '')!
	os.write_file('c/b', '42')!
	os.symlink('b', 'link_to_b')!
	os.symlink('c', 'link_to_c')!
	os.symlink('link_to_c', 'link_to_link_to_c')!
	os.symlink('link_to_link_to_c', 'link_to_link_to_link_to_c')!
	// os.symlink('recursive_link', 'recursive_link')!
}

fn testsuite_end() {
	os.rm('a')!
	os.rm('b')!
	os.rm('c/a')!
	os.rm('c/b')!
	os.rmdir('c')!
	os.rm('link_to_b')!
	os.rm('link_to_c')!
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

// TODO: This test struggles to resolve CacheMode enum?
// fn test_compare_stat_and_statx() ! {
// 	a := os.stat('.')!
// 	b := statx('.', false, .never)!
// 	assert a.size == b.stx_size
// 	assert a.uid == b.stx_uid
// 	assert a.gid == b.stx_gid
// 	assert a.mode == b.stx_mode
// 	assert a.inode == b.stx_ino
// 	assert a.size == b.stx_size
// }

fn test_compare() {
	// Compares including free space are risky, can change between calls esp. on tmpfs
	// rig.assert_same_results('--terse *')
	// rig.assert_same_results('-L --terse *')
	rig.assert_same_results('-f -c "%n %l %s %S %b %c" *')
	rig.assert_same_results('-c "%N" *')
	rig.assert_same_results('-c "%m:%n" *')

	rig.assert_same_results('--terse a')
	rig.assert_same_results('--terse b')
	rig.assert_same_results('--terse c')
	rig.assert_same_results('--terse c/*')
	rig.assert_same_results('--terse link_to_c')
	rig.assert_same_results('--terse link*')
	rig.assert_same_results('--terse *')
	rig.assert_same_results('--terse --dereference *')

	// TODO: Review %B
	format_test := r'%04a %A %b %d %D %f %F %g %G %h %i %m %n %N %o %-10s\t %t %T %u %U %w %W %x %X %y %Y %z %Z'
	rig.assert_same_results('--printf="${format_test}\\n" a')
	rig.assert_same_results('--format="${format_test}" a')
	rig.assert_same_results('--printf="${format_test}\\n" b')
	rig.assert_same_results('--printf="${format_test}\\n" c')
	rig.assert_same_results('--printf="${format_test}\\n" c/*')
	rig.assert_same_results('--printf="${format_test}\\n" link_to_c')
	rig.assert_same_results('--printf="${format_test}\\n" link*')
	rig.assert_same_results('--printf="${format_test}\\n" *')
	rig.assert_same_results('--printf="${format_test}\\n" --dereference *')

	// Ensure both follow GNUs behavior of using the last format specified
	rig.assert_same_results('--terse --format "abc" --format "xxx" --format "def" a')

	// Different behavior between GNU and V coreutil
	a := rig.call_orig('--format "abc" --printf "def" a')
	assert a.exit_code == 0 && a.output == 'def'
	b := rig.call_new('--format "abc" --printf "def" a')
	assert b.exit_code == 1

	// GNU 9.x has different outputs; testing against those versions will
	// cause the following to fail:
	rig.assert_same_results('a')
	rig.assert_same_results('b')
	rig.assert_same_results('c')
	rig.assert_same_results('c/*')
	rig.assert_same_results('link_to_c')
	rig.assert_same_results('link*')
	rig.assert_same_results('*')
	rig.assert_same_results('--dereference *')

	// TODO: file system id does not match between v version and GNU
	// rig.assert_same_results('-f /')	
}
