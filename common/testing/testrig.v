module testing

import os
import regex

// TestRig contains the relevant scaffolding for tests to avoid boilerplate in
// the individual <util>_test.v files
pub struct TestRig {
pub:
	util                  string
	platform_util         string
	platform_util_path    string
	executable_under_test string
	temp_dir              string
	cmd                   CommandPair
	is_supported_platform bool
}

pub struct TestRigConfig {
pub:
	util                  string
	is_supported_platform bool = true
}

pub fn (rig TestRig) call_for_test(args string) os.Result {
	res := os.execute('${rig.executable_under_test} ${args}')
	assert res.exit_code == 0
	return res
}

pub fn (rig TestRig) clean_up() {
	if os.is_dir(rig.temp_dir) {
		os.rmdir_all(rig.temp_dir) or {}
	}
}

pub fn (rig TestRig) assert_same_results(args string) {
	cmd1_res := os.execute('${rig.platform_util_path} ${args}')
	cmd2_res := os.execute('${rig.executable_under_test} ${args}')
	// If the name of the executable appears in the returned message, shorten it to the util
	// name because the paths are different for GNU coreutil and v-coreutil
	cmd1_output := cmd1_res.output.replace(rig.platform_util_path, rig.util)
	cmd2_output := cmd2_res.output.replace(rig.executable_under_test, rig.util)
	mut noutput1 := normalise(cmd1_output)
	mut noutput2 := normalise(cmd2_output)

	$if trace_same_results ? {
		eprintln('------------------------------------')
		eprintln('>> same_results cmd1: "${rig.platform_util_path} ${args}"')
		eprintln('>> same_results cmd2: "${rig.executable_under_test} ${args}"')
		eprintln('                cmd1_res.exit_code: ${cmd1_res.exit_code}')
		eprintln('                cmd2_res.exit_code: ${cmd2_res.exit_code}')
		eprintln('                cmd1_res.output.len: ${noutput1.len} | "${noutput1}"')
		eprintln('                cmd2_res.output.len: ${noutput2.len} | "${noutput2}"')
		eprintln('        (raw) > cmd1_res.output.len: ${cmd1_res.output.len} | "${cmd1_res.output}"')
		eprintln('        (raw) > cmd2_res.output.len: ${cmd2_res.output.len} | "${cmd2_res.output}"')
	}
	if gnu_coreutils_installed {
		// aim for 1:1 output compatibility:
		assert cmd1_res.exit_code == cmd2_res.exit_code 
		assert cmd1_output == cmd2_output
	}

	match rig.util {
		'coreutils' {
			noutput1 = noutput1.replace("'coreutils ", "'")
			// noutput2 = noutput2
			$if trace_same_results ? {
				eprintln('                 (coreutils) after1: ${noutput1.len} | "${noutput1}"')
				eprintln('                 (coreutils) after2: ${noutput2.len} | "${noutput2}"')
			}
		}
		'arch' {
			// `arch` is not standardized and 'AMD64' is more commonly known as 'x86_64'
			mut re := regex.regex_opt('[aA][mM][dD]64') or { panic(err) }
			// noutput1 = noutput1
			noutput2 = re.replace(noutput2, 'x86_64')
			$if trace_same_results ? {
				eprintln('                 (arch) after1: ${noutput1.len} | "${noutput1}"')
				eprintln('                 (arch) after2: ${noutput2.len} | "${noutput2}"')
			}
		}
		'printenv' {
			assert cmd1_res.exit_code == cmd2_res.exit_code
		}
		'sleep' {
			noutput1 = noutput1.replace(': invalid float literal', '')
			// noutput2 = noutput2
			$if trace_same_results ? {
				eprintln('                (sleep) after1: ${noutput1.len} | "${noutput1}"')
				eprintln('                (sleep) after2: ${noutput2.len} | "${noutput2}"')
			}
		}
		'uname' {
			// `uname` is not standardized and 'AMD64' is more commonly known as 'x86_64'
			mut re := regex.regex_opt('[aA][mM][dD]64') or { panic(err) }
			// noutput1 = noutput1
			noutput2 = re.replace(noutput2, 'x86_64')
			$if trace_same_results ? {
				eprintln('                 (arch) after1: ${noutput1.len} | "${noutput1}"')
				eprintln('                 (arch) after2: ${noutput2.len} | "${noutput2}"')
			}
		}
		'uptime' {
			noutput1 = cmd1_res.output.all_after('load average:')
			noutput2 = cmd2_res.output.all_after('load average:')
			$if trace_same_results ? {
				eprintln('               (uptime) after1: ${noutput1.len} | "${noutput1}"')
				eprintln('               (uptime) after2: ${noutput2.len} | "${noutput2}"')
			}
		}
		else {
			// in all other cases, compare the normalised output (less strict):
		}
	}
	assert cmd1_res.exit_code == cmd2_res.exit_code 
	assert noutput1 == noutput2
}

pub fn (rig TestRig) assert_help_and_version_options_work() {
	// For now, assume that the original has --version and --help
	// and that they already work correctly.
	assert os.execute('${rig.executable_under_test} --version').exit_code == 0
	assert os.execute('${rig.executable_under_test} --help').exit_code == 0
}
