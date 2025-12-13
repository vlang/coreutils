import common.testing
import os

const rig = testing.prepare_rig(util: 'tac')
const cmd = rig.cmd

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

const tac_test_data = [
	'#01 foo0 bar0 foo1 bar1',
	'#02 bar0 foo1 bar1 foo1',
	'#03 foo0 bar0 foo1 bar1',
	'#04',
	'#05 foo0 bar0 foo1 bar1',
	'#06 foo0 bar0 foo1 bar1',
	'#07 bar0 foo1 bar1 foo0',
]

const tac_test_files = {
	'vanilla':      'vanilla.txt'
	'no_final_lf':  'no_final_lf.txt'
	'seq':          'seq.txt'
	'seq_ellipsis': 'seq_ellipsis.txt'
}

fn call_for_test(args string) os.Result {
	res := os.execute('${rig.executable_under_test} ${args}')
	assert res.exit_code == 0
	return res
}

fn run_for_all(args string) {
	for tf, path in tac_test_files {
		eprintln('   >>>>>  Now testing: ${tf}  <<<<<   ')
		rig.assert_same_results('${args} ${path}')
	}
}

fn test_vanilla() {
	run_for_all('')
}

fn test_sep_before() {
	run_for_all('-b')
}

fn test_diff_sep() {
	run_for_all('-s 1')
}

fn test_different_sep_before() {
	run_for_all('-b -s 1')
}

fn test_ellipsis_sep() {
	run_for_all('-s "..."')
}

fn test_regex_sep() {
	run_for_all('-r -s "\\.\\.\\."')
}

fn test_regex_sep_before() {
	run_for_all('-b -r -s "\\.\\.\\."')
}

fn test_multiple() {
	rig.assert_same_results('${tac_test_files['vanilla']} ${tac_test_files['seq']}')
}

fn test_multiple_sep_before() {
	rig.assert_same_results('-b ${tac_test_files['vanilla']} ${tac_test_files['seq']}')
}

fn test_file_does_not_exist() {
	rig.assert_same_results('no_such_file.txt')
}

fn make_test_file(path string, sep string) ! {
	mut f := os.create(path)!
	for i := 0; i <= 100; i++ {
		f.write_string('${i}${sep}')!
	}
	f.close()
}

fn testsuite_begin() {
	rig.assert_platform_util()
	os.write_file(tac_test_files['vanilla'], tac_test_data.join('\n'))!
	os.write_file(tac_test_files['no_final_lf'], tac_test_data.join('\n') + '\n')!
	make_test_file(tac_test_files['seq'], '\n')!
	make_test_file(tac_test_files['seq_ellipsis'], '...')!
}

fn testsuite_end() {
	for _, path in tac_test_files {
		os.rm(path)!
	}
}
