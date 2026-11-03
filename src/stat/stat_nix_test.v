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

// The test runner passes literal argument arrays, so expand fixture globs here.
// Require a match so the successful-file comparisons cannot silently test errors.
fn assert_same_stat_results(options string) {
	mut args := []string{}
	for arg in testing.split_args(options) {
		if arg.contains('*') {
			matches := os.glob(arg) or { panic(err) }
			assert matches.len > 0, arg
			// os.glob marks directories with '/', unlike an ordinary shell '*'.
			args << matches.map(os.quoted_path(it.trim_right(os.path_separator)))
		} else {
			args << os.quoted_path(arg)
		}
	}
	rig.assert_same_results(args.join(' '))
}

fn test_missing_operands_report_failure() {
	for flags in ['', '-f'] {
		for operands in ['does_not_exist', 'a does_not_exist b'] {
			result := rig.call_new('${flags} ${operands}')
			assert result.exit_code == 1
			assert result.output.contains('does_not_exist')
			rig.assert_same_exit_code('${flags} ${operands}')
		}
	}
}

fn test_compare() {
	// Compares including free space are risky, can change between calls esp. on tmpfs
	// assert_same_stat_results('--terse *')
	// assert_same_stat_results('-L --terse *')
	assert_same_stat_results('-f -c "%n %l %s %S %b %c" *')
	assert_same_stat_results('-c "%N" *')
	assert_same_stat_results('-c "%m:%n" *')

	assert_same_stat_results('--terse a')
	assert_same_stat_results('--terse b')
	assert_same_stat_results('--terse c')
	assert_same_stat_results('--terse c/*')
	assert_same_stat_results('--terse link_to_c')
	assert_same_stat_results('--terse link*')
	assert_same_stat_results('--terse *')
	assert_same_stat_results('--terse --dereference *')

	// TODO: Review %B
	format_test := r'%04a %A %b %d %D %f %F %g %G %h %i %m %n %N %o %-10s\t %t %T %u %U %w %W %x %X %y %Y %z %Z'
	assert_same_stat_results('--printf="${format_test}\\n" a')
	assert_same_stat_results('--format="${format_test}" a')
	assert_same_stat_results('--printf="${format_test}\\n" b')
	assert_same_stat_results('--printf="${format_test}\\n" c')
	assert_same_stat_results('--printf="${format_test}\\n" c/*')
	assert_same_stat_results('--printf="${format_test}\\n" link_to_c')
	assert_same_stat_results('--printf="${format_test}\\n" link*')
	assert_same_stat_results('--printf="${format_test}\\n" *')
	assert_same_stat_results('--printf="${format_test}\\n" --dereference *')

	// Ensure both follow GNUs behavior of using the last format specified
	assert_same_stat_results('--terse --format "abc" --format "xxx" --format "def" a')

	// Different behavior between GNU and V coreutil
	a := rig.call_orig('--format "abc" --printf "def" a')
	assert a.exit_code == 0 && a.output == 'def'
	b := rig.call_new('--format "abc" --printf "def" a')
	assert b.exit_code == 1

	// GNU 9.x has different outputs; testing against those versions will
	// cause the following to fail:
	assert_same_stat_results('a')
	assert_same_stat_results('b')
	assert_same_stat_results('c')
	assert_same_stat_results('c/*')
	assert_same_stat_results('link_to_c')
	assert_same_stat_results('link*')
	assert_same_stat_results('*')
	assert_same_stat_results('--dereference *')

	// TODO: file system id does not match between v version and GNU
	// assert_same_stat_results('-f /')
}
