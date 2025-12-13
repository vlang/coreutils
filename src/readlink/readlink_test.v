import common.testing
import os

const rig = testing.prepare_rig(util: 'readlink')

fn testsuite_begin() {
	rig.assert_platform_util()
	os.write_file('a', '')!
	os.write_file('b', '42')!
	os.mkdir('c')!
	os.write_file('c/a', '')!
	os.write_file('c/b', '42')!
	os.symlink('b', 'link_to_b')!
	os.symlink('c', 'link_to_c')!
	os.symlink('link_to_c', 'link_to_link_to_c')!
	os.symlink('link_to_link_to_c', 'link_to_link_to_link_to_c')!
	os.symlink('recursive_link', 'recursive_link')!

	$if !windows {
		os.chdir('c')!
		os.symlink('..', 'c_up')!
		os.symlink('.', 'c_same')!
		os.chdir('..')!
	}
}

fn testsuite_end() {
	$if !windows {
		os.rm('link_to_link_to_link_to_c')!
		os.rm('link_to_link_to_c')!
		os.rm('link_to_c')!
		os.rm('link_to_b')!
		os.rm('recursive_link')!
		os.rm('c/c_up')!
		os.rm('c/c_same')!
	}
	os.rm('c/b')!
	os.rm('c/a')!
	os.rmdir('c')!
	os.rm('b')!
	os.rm('a')!
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_compare() {
	rig.assert_same_results('')
	rig.assert_same_results('.')
	rig.assert_same_results('..')
	rig.assert_same_results('-fv .')
	rig.assert_same_results('-fv ..')
	rig.assert_same_results('-ev .')
	rig.assert_same_results('-ev ..')
	rig.assert_same_results('-mv .')
	rig.assert_same_results('-mv ..')
	rig.assert_same_results('-ev a')
	rig.assert_same_results('-ev b')
	rig.assert_same_results('-mv a')
	rig.assert_same_results('-ev link_to_a')
	rig.assert_same_results('-ev link_to_b')
	$if !windows {
		// Error message does not match in Windows and POSIX
		rig.assert_same_results('-v does_not_exist/neither_does_this')
		rig.assert_same_results('link_to_b')
		rig.assert_same_results('link_to_c')
		rig.assert_same_results('link_to_link_to_c')
		rig.assert_same_results('-fv link_to_link_to_c')
		rig.assert_same_results('-fv recursive_link')
		rig.assert_same_results('-fv link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('-ev link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('-ev link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/does_not_exist')
		rig.assert_same_results('-mv link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('-mv link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/does_not_exist/neither_does_this')
		rig.assert_same_results('link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/b')
	}
}
