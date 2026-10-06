import common.testing
import os

const rig = testing.prepare_rig(util: 'realpath')

fn testsuite_begin() {
	rig.assert_platform_util()
	os.write_file('a', '')!
	os.write_file('b', '42')!
	os.mkdir('c')!
	os.write_file('c/a', '')!
	os.write_file('c/b', '42')!

	$if !windows {
		os.symlink('b', 'link_to_b')!
		os.symlink('c', 'link_to_c')!
		os.symlink('link_to_c', 'link_to_link_to_c')!
		os.symlink('link_to_link_to_c', 'link_to_link_to_link_to_c')!
		os.symlink('recursive_link', 'recursive_link')!
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
	rig.assert_same_exit_code('')
	rig.assert_same_results('.')
	rig.assert_same_results('..')
	rig.assert_same_results('-e .')
	rig.assert_same_results('-e ..')
	rig.assert_same_results('-m .')
	rig.assert_same_results('-m ..')
	rig.assert_same_results('-e a')
	rig.assert_same_results('-e b')
	rig.assert_same_results('-m a')
	rig.assert_same_results('-e .')
	rig.assert_same_results('-m .')
	rig.assert_same_results('-e ..')
	rig.assert_same_results('-m ..')
	rig.assert_same_results('-e a')
	rig.assert_same_results('-e b')
	rig.assert_same_results('-m a')
	rig.assert_same_results('-m b')
	rig.assert_same_results('-e c')
	rig.assert_same_results('-m c')
	rig.assert_same_results('-e c/a')
	rig.assert_same_results('-m c/a')
	rig.assert_same_results('-e c/b')
	rig.assert_same_results('-m c/b')
	rig.assert_same_results('-e does_not_exist')
	rig.assert_same_results('-m does_not_exist')
	rig.assert_same_results('-e does_not_exist/neither_does_this')
	rig.assert_same_results('-m does_not_exist/neither_does_this')
	rig.assert_same_results('-q does_not_exist')
	rig.assert_same_results('-q does_not_exist/neither_does_this')
	rig.assert_same_results('-s .')
	rig.assert_same_results('-s ..')
	rig.assert_same_results('-s a')
	rig.assert_same_results('-s b')
	rig.assert_same_results('-s c')
	rig.assert_same_results('-s c/a')
	rig.assert_same_results('-s c/b')
	rig.assert_same_results('-s does_not_exist')
	rig.assert_same_results('--strip .')
	rig.assert_same_results('--strip a')
	rig.assert_same_results('--no-symlinks .')
	rig.assert_same_results('--no-symlinks a')
	rig.assert_same_results('-z .')
	rig.assert_same_results('-z a')
	rig.assert_same_results('-z does_not_exist')
	rig.assert_same_results('--relative-to=. .')
	rig.assert_same_results('--relative-to=. a')
	rig.assert_same_results('--relative-to=. c')
	rig.assert_same_results('--relative-to=. c/a')
	rig.assert_same_results('--relative-to=c c/a')
	rig.assert_same_results('--relative-to=c c/b')
	rig.assert_same_results('--relative-to=. ..')
	rig.assert_same_results('--relative-base=. .')
	rig.assert_same_results('--relative-base=. a')
	rig.assert_same_results('--relative-base=. c')
	rig.assert_same_results('--relative-base=. c/a')
	rig.assert_same_results('--relative-base=c c/a')
	rig.assert_same_results('--relative-base=c c/b')
	rig.assert_same_results('--relative-base=. ..')
	rig.assert_same_results('-L .')
	rig.assert_same_results('-L ..')
	rig.assert_same_results('-L a')
	rig.assert_same_results('-L c/a')
	rig.assert_same_results('-P .')
	rig.assert_same_results('-P ..')
	rig.assert_same_results('-P a')
	rig.assert_same_results('-P c/a')
	rig.assert_same_results('-Le .')
	rig.assert_same_results('-Le ..')
	rig.assert_same_results('-Le a')
	rig.assert_same_results('-Le c/a')
	rig.assert_same_results('-Pe .')
	rig.assert_same_results('-Pe ..')
	rig.assert_same_results('-Pe a')
	rig.assert_same_results('-Pe c/a')
	rig.assert_same_results('-Lm .')
	rig.assert_same_results('-Lm ..')
	rig.assert_same_results('-Lm a')
	rig.assert_same_results('-Lm c/a')
	rig.assert_same_results('-Pm .')
	rig.assert_same_results('-Pm ..')
	rig.assert_same_results('-Pm a')
	rig.assert_same_results('-Pm c/a')
	$if !windows {
		rig.assert_same_results('-e link_to_b')
		rig.assert_same_results('-e link_to_c')
		rig.assert_same_results('-e link_to_link_to_c')
		rig.assert_same_results('-m link_to_b')
		rig.assert_same_results('-m link_to_c')
		rig.assert_same_results('-m link_to_link_to_c')
		rig.assert_same_results('-e link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('-m link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('-e link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/does_not_exist')
		rig.assert_same_results('-m link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/does_not_exist/neither_does_this')
		rig.assert_same_results('link_to_b')
		rig.assert_same_results('link_to_c')
		rig.assert_same_results('link_to_link_to_c')
		rig.assert_same_results('link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/b')
		rig.assert_same_results('-s link_to_b')
		rig.assert_same_results('-s link_to_c')
		rig.assert_same_results('-s link_to_link_to_c')
		rig.assert_same_results('-L link_to_c/c_up')
		rig.assert_same_results('-P link_to_c/c_up')
		rig.assert_same_results('-L link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('-P link_to_link_to_c/c_same/c_same/c_up/link_to_c/c_up/a')
		rig.assert_same_results('--relative-to=. link_to_b')
		rig.assert_same_results('--relative-to=. link_to_c')
		rig.assert_same_results('--relative-to=. link_to_link_to_c')
		rig.assert_same_results('--relative-base=. link_to_b')
		rig.assert_same_results('--relative-base=. link_to_c')
		rig.assert_same_results('--relative-base=. link_to_link_to_c')
	}
}
