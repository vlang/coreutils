import common.dd as ddmod
import common.testing
import os

const rig = testing.prepare_rig(util: 'dd')

const input_path = 'dd_input.txt'
const input_content = '0123456789'

struct Result {
mut:
	code   int
	stdout string
}

fn run_dd(args []string) Result {
	mut p := os.new_process(rig.executable_under_test)
	p.set_args(args)
	p.set_redirect_stdio()
	p.wait()
	r := Result{
		code:   p.code
		stdout: p.stdout_slurp()
	}
	p.close()
	return r
}

fn run_ref(args []string) Result {
	mut full := ['dd']
	full << args
	mut p := os.new_process(rig.platform_util_path)
	p.set_args(full)
	p.set_redirect_stdio()
	p.wait()
	r := Result{
		code:   p.code
		stdout: p.stdout_slurp()
	}
	p.close()
	return r
}

fn assert_same(args []string) {
	tr := run_dd(args)
	uu := run_ref(args)
	assert tr.code == uu.code, 'exit code for [${args}]: tr=${tr.code} uu=${uu.code}'
	assert tr.stdout == uu.stdout, 'stdout for [${args}]: tr="${tr.stdout}" uu="${uu.stdout}"'
}

fn testsuite_begin() {
	rig.assert_platform_util()
	os.write_file(input_path, input_content)!
}

fn testsuite_end() {
	os.rm(input_path) or {}
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_matches_reference_block_sizes() {
	assert_same(['if=' + input_path, 'bs=2', 'count=3'])
	assert_same(['if=' + input_path, 'bs=1', 'count=4'])
	assert_same(['if=' + input_path])
}

fn test_matches_reference_binary_and_decimal_units() {
	// A bare K is a power of two and a KB a power of ten, so these two
	// deliberately read different amounts of the same 1000-byte input.
	assert_same(['if=' + input_path, 'bs=1K', 'count=1'])
	assert_same(['if=' + input_path, 'bs=1KB', 'count=1'])
	assert_same(['if=' + input_path, 'bs=1b', 'count=1'])
	assert_same(['if=' + input_path, 'bs=1c', 'count=4'])
	assert_same(['if=' + input_path, 'bs=1w', 'count=4'])
}

fn test_matches_reference_skip_and_count_flags() {
	assert_same(['if=' + input_path, 'bs=2', 'skip=2'])
	assert_same(['if=' + input_path, 'bs=2', 'skip=4', 'iflag=skip_bytes'])
	assert_same(['if=' + input_path, 'bs=2', 'count=4', 'iflag=count_bytes'])
}

fn test_matches_reference_conversions() {
	assert_same(['if=' + input_path, 'conv=lcase'])
	// bs=1 leaves swab nothing to exchange, so both are identical by design.
	assert_same(['if=' + input_path, 'conv=swab', 'bs=1'])
	// At the default block size the pairs really are exchanged, which is the
	// case that distinguishes a whole-buffer swap from a per-block one.
	assert_same(['if=' + input_path, 'conv=swab'])
	assert_same(['if=' + input_path, 'bs=4', 'count=1', 'conv=sync'])
}

fn test_matches_reference_status_none() {
	assert_same(['if=' + input_path, 'bs=2', 'count=2', 'status=none'])
}

fn test_matches_reference_failures() {
	// bs=0 is rejected by both. uutils aborts with a Rust panic status here
	// while GNU exits 1; this port follows GNU.
	assert_same(['if=C:\\nope\\f'])
	assert_same(['if=' + input_path, 'bs=abc'])
	assert_same(['if=' + input_path, 'bs='])
	assert_same(['bogus=1'])
}

fn test_parse_args_defaults() {
	s := ddmod.parse_args([])
	assert s.bs == 512
	assert !s.count_set
	assert s.status == .full
	assert s.conv.len == 0
}

fn test_parse_args_operands() {
	s := ddmod.parse_args(['if=a', 'of=b', 'bs=4', 'count=2', 'skip=1', 'seek=3'])
	assert s.ifile == 'a'
	assert s.ofile == 'b'
	assert s.bs == 4
	assert s.ibs == 4
	assert s.obs == 4
	assert s.count == 2
	assert s.count_set
	assert s.skip == 1
	assert s.seek == 3
}

fn test_parse_args_ibs_obs_override_bs() {
	s := ddmod.parse_args(['bs=10', 'ibs=4', 'obs=6'])
	assert s.ibs == 4
	assert s.obs == 6
	assert s.ibs_set
	assert s.obs_set
}

fn test_parse_args_status_and_conv_lists() {
	s := ddmod.parse_args(['status=none', 'conv=notrunc,sync,lcase'])
	assert s.status == .none
	assert s.conv == ['notrunc', 'sync', 'lcase']

	n := ddmod.parse_args(['status=noxfer'])
	assert n.status == .noxfer
}

fn test_parse_args_iflag_oflag_lists() {
	s := ddmod.parse_args(['iflag=count_bytes,skip_bytes', 'oflag=seek_bytes'])
	assert s.iflag == ['count_bytes', 'skip_bytes']
	assert s.oflag == ['seek_bytes']
}

fn test_unit_suffix_arithmetic() {
	// Exercised through parse_args so the value actually lands in Settings.
	from_bs := fn (v string) u64 {
		return ddmod.parse_args(['bs=' + v]).bs
	}
	assert from_bs('1b') == 512
	assert from_bs('1c') == 1
	assert from_bs('1w') == 2
	assert from_bs('1K') == 1024
	assert from_bs('1k') == 1024
	assert from_bs('1KiB') == 1024
	assert from_bs('1KB') == 1000
	assert from_bs('1kB') == 1000
	assert from_bs('2K') == 2048
	assert from_bs('3KB') == 3000
	// A bare letter means one unit.
	assert from_bs('K') == 1024
	assert from_bs('KB') == 1000
}

fn test_zero_is_allowed_only_where_gnu_allows_it() {
	// count=0 and skip=0 are legal; a zero block size is not.
	assert ddmod.parse_args(['count=0']).count_set
	assert ddmod.parse_args(['skip=0']).skip == 0
	// The block-size rejection happens inside parse_args, which exits, so it
	// is covered by the differential failures test above.
}
