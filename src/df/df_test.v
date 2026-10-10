// These tests are compiled on their own by `v test src/df/`, so the logic
// under test is imported from common/df rather than defined here.
import common.df as colondf
import common.testing

const rig = testing.prepare_rig(util: 'df')

fn mk_mount(device string, mounted string, fstype string, total u64, used u64, free u64) colondf.MountInfo {
	return colondf.MountInfo{
		device:      device
		mounted:     mounted
		fstype:      fstype
		total_bytes: total
		used_bytes:  used
		free_bytes:  free
	}
}

const fs_a = mk_mount('/dev/sdb', '/', 'ext4', 100 * 1024 * 1024, 26 * 1024 * 1024,
	74 * 1024 * 1024)
const fs_b = mk_mount('/dev/sdc', '/mnt/data', 'ext4', 20 * 1024 * 1024, 2 * 1024 * 1024,
	18 * 1024 * 1024)
const fs_zero = mk_mount('/dev/sdz', '/mnt/empty', 'tmpfs', 0, 0, 0)

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_default_columns() {
	set := colondf.parse_args([])
	out := colondf.render_table([fs_a, fs_b], set)
	// Values are 1K blocks: 100 MiB is 102400 of them.
	expected := 'Filesystem     1K-blocks  Used Available Use% Mounted on\n' +
		'/dev/sdb          102400 26624     75776  26% /\n' +
		'/dev/sdc           20480  2048     18432  10% /mnt/data'
	assert out == expected
}

fn test_print_type() {
	set := colondf.parse_args(['-T'])
	out := colondf.render_table([fs_a], set)
	expected := 'Filesystem     Type 1K-blocks  Used Available Use% Mounted on\n' +
		'/dev/sdb       ext4    102400 26624     75776  26% /'
	assert out == expected
}

fn test_human_readable() {
	set := colondf.parse_args(['-h'])
	out := colondf.render_table([fs_a], set)
	expected := 'Filesystem      Size  Used Avail Use% Mounted on\n' +
		'/dev/sdb        100M   26M   74M  26% /'
	assert out == expected
}

fn test_si_human_readable() {
	set := colondf.parse_args(['-H'])
	out := colondf.render_table([fs_a], set)
	expected := 'Filesystem      Size  Used Avail Use% Mounted on\n' +
		'/dev/sdb        105M   27M   78M  26% /'
	assert out == expected
}

fn test_human_readable_ranges() {
	set := colondf.parse_args(['-h'])
	// One decimal below ten, none at or above it.
	assert colondf.format_size(0, set) == '0'
	assert colondf.format_size(1, set) == '1'
	assert colondf.format_size(1024 * 1024, set) == '1.0M'
	assert colondf.format_size(1073741824, set) == '1.0G'
	assert colondf.format_size(1536 * 1024 * 1024, set) == '1.5G'
	assert colondf.format_size(26 * 1024 * 1024, set) == '26M'
	assert colondf.format_size(100 * 1024 * 1024, set) == '100M'

	set_si := colondf.parse_args(['-H'])
	assert colondf.format_size(100 * 1024 * 1024, set_si) == '105M'
	// --si keeps the SI lowercase k for the first unit only.
	assert colondf.format_size(132 * 1000, set_si) == '132k'
	assert colondf.format_size(128 * 1024, colondf.parse_args(['-h'])) == '128K'
}

fn test_block_size() {
	set := colondf.parse_args(['-B', '512'])
	assert set.mode == .blocks
	assert set.block_size == 512

	set2 := colondf.parse_args(['-B512'])
	assert set2.block_size == 512

	set3 := colondf.parse_args(['--block-size=1024'])
	assert set3.mode == .blocks
	assert set3.block_size == 1024

	out := colondf.render_table([fs_a], set3)
	// The device column is 14 wide, then one separator, then the label.
	assert out.starts_with('Filesystem     1024-blocks')
}

fn test_k_and_posix_modes() {
	assert colondf.parse_args(['-k']).mode == .kibibytes
	assert colondf.parse_args(['-m']).mode == .mebibytes
	assert colondf.parse_args(['-g']).mode == .gibibytes
	// -P is POSIX output: 512-byte blocks.
	p := colondf.parse_args(['-P'])
	assert p.mode == .blocks
	assert p.block_size == 512
}

fn test_clustered_short_options() {
	set := colondf.parse_args(['-hT'])
	assert set.mode == .human
	assert set.show_type

	set2 := colondf.parse_args(['-Th'])
	assert set2.mode == .human
	assert set2.show_type
}

fn test_total() {
	set := colondf.parse_args(['--total'])
	out := colondf.render_table([fs_a, fs_b], set)
	expected := 'Filesystem     1K-blocks  Used Available Use% Mounted on\n' +
		'/dev/sdb          102400 26624     75776  26% /\n' +
		'/dev/sdc           20480  2048     18432  10% /mnt/data\n' +
		'total             122880 28672     94208  23% -'
	assert out == expected
}

fn test_type_filters() {
	set := colondf.parse_args(['-t', 'ext4'])
	assert set.include_types == ['ext4']

	set2 := colondf.parse_args(['--type=ext4,tmpfs'])
	assert set2.include_types == ['ext4', 'tmpfs']

	set3 := colondf.parse_args(['-x', 'tmpfs'])
	assert set3.exclude_types == ['tmpfs']
}

fn test_double_dash_ends_options() {
	set := colondf.parse_args(['--', '-h'])
	assert set.operands == ['-h']
	// A lone '-' is a FILE (standard input here), not an option.
	set2 := colondf.parse_args(['-'])
	assert set2.operands == ['-']
}

fn test_local_flag_parses() {
	set := colondf.parse_args(['-l'])
	assert set.local
	assert colondf.parse_args(['--local']).local
}

fn test_collect_mounts_filters_unsizable() {
	// A volume the platform cannot size has no usable numbers and is hidden
	// unless --all is given.
	set := colondf.parse_args([])
	mounts := colondf.list_mounts()
	filtered := colondf.collect_mounts(set)
	assert filtered.len <= mounts.len
	for m in filtered {
		assert m.total_bytes > 0
	}
}

fn test_collect_mounts_all_shows_unsizable() {
	set := colondf.parse_args(['-a'])
	mounts := colondf.list_mounts()
	filtered := colondf.collect_mounts(set)
	assert filtered.len == mounts.len
}

fn test_collect_mounts_type_filter() {
	all_set := colondf.parse_args(['-a'])
	all := colondf.collect_mounts(all_set)
	if all.len > 0 {
		ftype := all[0].fstype
		set := colondf.parse_args(['-t', ftype])
		kept := colondf.collect_mounts(set)
		assert kept.len > 0
		for m in kept {
			assert m.fstype == ftype
		}
	}
}

fn test_zero_size_row_percentage() {
	set := colondf.parse_args(['-a'])
	out := colondf.render_table([fs_zero], set)
	// A volume whose total size is unreadable has no computable percentage.
	assert out.ends_with(' - /mnt/empty')
}

fn test_parse_block_size_rejects_non_numeric() {
	assert colondf.parse_block_size('512')? == 512
	assert colondf.parse_block_size('1K') == none
	assert colondf.parse_block_size('') == none
	assert colondf.parse_block_size('-1') == none
}
