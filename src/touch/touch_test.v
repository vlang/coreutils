module main

import os
import time

// The expectations in this file were read off GNU touch 9.4, not derived from
// the code under test. The previous version computed them with
// time.parse_iso8601(date).unix(), which is the very call the implementation
// makes, so it agreed with the code by construction and could not have caught
// the bug it existed to guard. Every stamp below is a literal measured under
// TZ=Asia/Tehran, a zone whose offset differs by a full hour between summer and
// winter, which is what makes it worth testing on.
//
//	2022-12-01T11:00:01  ->  1669879801
//	2022-12-01T11:50:02  ->  1669882802
//	2023-01-01T20:00:35  ->  1672590635
//
// A zone with no rules available would make these meaningless, so the tests say
// so rather than quietly passing.
const tehran = 'Asia/Tehran'

fn temp_file_name() string {
	dir := os.temp_dir()
	file := '${dir}/t${time.ticks()}'
	return file
}

fn p(msg string) {
	println(msg)
}

fn pass() {
	assert true
}

// pin_zone sets TZ for the duration of a test and hands back what to restore.
// The zone has to be forced: on a machine whose own zone happens to be UTC the
// whole bug this file guards is invisible.
fn pin_zone(zone string) string {
	saved := os.getenv('TZ')
	_ = os.setenv('TZ', zone, true)
	return saved
}

fn zone_available() bool {
	time.load_location('Local') or {
		p('no local zone information on this machine, skipping the ${tehran} assertions')
		return false
	}
	return true
}

fn test_touch_one_file_no_options() {
	p(@METHOD)
	file := temp_file_name()
	assert !os.exists(file)
	touch(['touch', file])
	assert os.exists(file)
	os.rm(file)!
	pass()
}

fn test_touch_two_files_no_options() {
	p(@METHOD)
	file1 := temp_file_name()
	file2 := file1 + 'x'
	assert !os.exists(file1)
	assert !os.exists(file2)
	touch(['touch', file1, file2])
	assert os.exists(file1)
	assert os.exists(file2)
	os.rm(file1)!
	os.rm(file2)!
	pass()
}

fn test_touch_no_create_option() {
	p(@METHOD)
	file := temp_file_name()
	touch(['touch', '-c', file])
	assert !os.exists(file)
	pass()
}

// A string with no zone in it names a local time. Read as UTC it lands three
// and a half hours late here, which is what these five used to do.
fn test_parse_datetime_naive_string_is_local() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	// A date with no time is local midnight, not UTC midnight.
	assert parse_datetime('2020-01-02', false)! == 1_577_910_600
	assert parse_datetime('2020-01-02 03:04:05', false)! == 1_577_921_645
	assert parse_datetime('2020-01-02T03:04:05', false)! == 1_577_921_645
	assert parse_datetime('2020-02-29 12:00:00', false)! == 1_582_965_000
	assert parse_datetime('2025-01-01 00:00:00', false)! == 1_735_677_000
	pass()
}

// The offset that applies is the one in force at that date, not the one in force
// now. Tehran is +0430 in June and +0330 in October, so subtracting the current
// offset puts this one an hour out: 08:09:10 - 4:30 = 03:39:10 UTC.
fn test_parse_datetime_uses_the_offset_at_that_date() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	assert parse_datetime('2021-06-07 08:09:10', false)! == 1_623_037_150
	// And the same zone in its other period, to show both are in play.
	assert parse_datetime('2020-01-02 03:04:05', false)! == 1_577_921_645
	pass()
}

// A string that says its zone is already an instant and must not be shifted.
fn test_parse_datetime_leaves_an_explicit_zone_alone() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	assert parse_datetime('2020-01-02T03:04:05Z', false)! == 1_577_934_245
	// +03:30 is the zone's own offset in January, so this lands where the naive
	// spelling of the same wall clock does. It has to get there on its own.
	assert parse_datetime('2020-01-02T03:04:05+03:30', false)! == 1_577_921_645
	pass()
}

fn test_has_explicit_zone() {
	p(@METHOD)
	assert has_explicit_zone('2020-01-02T03:04:05Z')
	assert has_explicit_zone('2020-01-02T03:04:05z')
	assert has_explicit_zone('2020-01-02T03:04:05+03:30')
	assert has_explicit_zone('2020-01-02T03:04:05-05:00')
	assert has_explicit_zone('2020-01-02 03:04:05Z')
	assert has_explicit_zone('2020-01-02 03:04:05+0330')

	assert !has_explicit_zone('2020-01-02 03:04:05')
	assert !has_explicit_zone('2020-01-02T03:04:05')
	// The date carries two hyphens and no time part at all.
	assert !has_explicit_zone('2020-01-02')
	assert !has_explicit_zone('2020-01-02 03:04:05.678')
	pass()
}

// @1600000000 is an instant already, so no zone logic applies and the fraction
// is dropped, since a file stamp holds whole seconds. Read off GNU:
//	@1600000000 -> 1600000000  @0 -> 0  @1600000000.5 -> 1600000000
fn test_parse_datetime_epoch() {
	p(@METHOD)
	assert parse_datetime('@1600000000', false)! == 1_600_000_000
	assert parse_datetime('@0', false)! == 0
	assert parse_datetime('@1600000000.5', false)! == 1_600_000_000
	pass()
}

// -t's compact stamp is [[CC]YY]MMDDhhmm[.ss]. GNU rejects fourteen digits, so
// the seconds only exist as the fractional part, and a ten digit reading takes
// the century from the first two. All four were read off GNU under Tehran.
fn test_parse_datetime_compact_stamp() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	// The compact reading is the same wall clock as the spelled out one, and the
	// two digit year resolves to 2020 rather than 1920.
	spelled := parse_datetime('2020-01-02 03:04:00', false)!
	assert parse_datetime('202001020304', true)! == spelled
	assert parse_datetime('2001020304', true)! == spelled
	// Fourteen digits is not a stamp.
	assert_parse_fails('20200102030405', true)
	// The compact reading belongs to -t only. Under -d GNU reads the same digits
	// as something else entirely and lands in the year 2446, so -d must not
	// quietly accept them as a date.
	assert_parse_fails('202001020304', false)
	pass()
}

// A bare time means today at that time, not 1970. The date therefore has to come
// from the local zone, which is what local_today reads. The expectations are
// built from the same local date rather than hard coded, because "today" moves.
fn test_parse_datetime_bare_time_is_today() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	loc := time.load_location('Local') or { return }
	today := time.unix(time.now().unix()).in(loc) or { return }
	midnight := parse_datetime('00:00', false)!
	day := parse_datetime('00:00:00', false)!
	assert midnight == day
	// 5 is 05:00, and 0304 is 03:04.
	assert parse_datetime('5', false)! == midnight + 5 * 3600
	assert parse_datetime('0304', false)! == midnight + (3 * 3600 + 4 * 60)
	assert parse_datetime('03:04', false)! == parse_datetime('0304', false)!
	assert parse_datetime('03:04:05', false)! == parse_datetime('0304', false)! + 5
	// And it is today's date, not a fixed one: read the result back into the zone
	// and compare the calendar fields with today.
	read_back := time.unix(midnight).in(loc) or { return }
	assert read_back.year == today.year
	assert read_back.month == today.month
	assert read_back.day == today.day
	assert read_back.hour == 0
	pass()
}

// A bare YYYYMMDD is local midnight on that date. Measured under Tehran:
//	20200102 -> 1577910600
fn test_parse_datetime_basic_date() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	assert parse_datetime('20200102', false)! == 1_577_910_600
	assert parse_datetime('20200102', false)! == parse_datetime('2020-01-02', false)!
	pass()
}

// A zone word after a bare time names today at that time in that zone, so the
// suffix's sign is the opposite of what it looks like. Measured under Tehran,
// where the local offset is +0330:
//	10:00 UTC     -> 2026-10-03 13:30 local
//	10:00 GMT+3   -> 2026-10-03 10:30 local
//	10:00 UTC-2   -> 2026-10-03 15:30 local
fn test_parse_datetime_zone_word() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	plain := parse_datetime('10:00', false)!
	utc := parse_datetime('10:00 UTC', false)!
	assert utc - plain == 3 * 3600 + 30 * 60
	assert parse_datetime('10:00 GMT', false)! == utc
	// GMT+3 is three hours ahead of UTC, so it lands three hours earlier than UTC.
	assert utc - parse_datetime('10:00 GMT+3', false)! == 3 * 3600
	// UTC-2 is two hours behind UTC.
	assert parse_datetime('10:00 UTC-2', false)! - utc == 2 * 3600
	pass()
}

fn assert_parse_fails(s string, compact bool) {
	parse_datetime(s, compact) or { return }
	assert false, 'expected ${s} to be rejected'
}

fn test_touch_create_with_d_option() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	file := temp_file_name()
	touch(['touch', '-d', '2022-12-01T11:00:01', file])
	stat := os.lstat(file)!
	assert stat.atime == 1_669_879_801
	assert stat.mtime == 1_669_879_801
	os.rm(file)!
	pass()
}

fn test_touch_create_with_a_d_option() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	file := temp_file_name()
	touch(['touch', '-a', '-d', '2022-12-01T11:00:01', file])
	stat := os.lstat(file)!
	assert stat.atime == 1_669_879_801
	assert stat.mtime != 1_669_879_801
	os.rm(file)!
	pass()
}

fn test_touch_create_with_m_d_option() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	file := temp_file_name()
	touch(['touch', '-m', '-d', '2022-12-01T11:00:01', file])
	stat := os.lstat(file)!
	assert stat.atime != 1_669_879_801
	assert stat.mtime == 1_669_879_801
	os.rm(file)!
	pass()
}

fn test_touch_with_reference_file() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	rfile := temp_file_name()
	touch(['touch', '-d', '2022-12-01T11:00:01', rfile])
	touch(['touch', '-a', '-d', '2022-12-01T11:50:02', rfile])

	file := rfile + 'x'
	touch(['touch', '-r', rfile, file])

	stat := os.lstat(file)!
	assert stat.atime == 1_669_882_802
	assert stat.mtime == 1_669_879_801

	os.rm(file)!
	os.rm(rfile)!
	pass()
}

fn test_touch_no_reference_option() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	file := temp_file_name()
	touch(['touch', '-d', '2022-12-01T11:00:01', file])

	// confirm correct start state
	stat := os.lstat(file)!
	assert stat.atime == 1_669_879_801
	assert stat.mtime == 1_669_879_801

	if os.user_os() == 'windows' {
		eprintln('skip symlink checks on windows, they need administrative permissions')
		return
	}

	link := file + 'lnk'
	os.symlink(file, link)!

	// touch the symlink
	touch(['touch', '-h', '-d', '2023-01-01T20:00:35', link])

	// check original file
	fstat := os.lstat(file)!
	assert fstat.atime == 1_669_879_801
	assert fstat.mtime == 1_669_879_801

	// lstat does not 'follow' links
	lstat := os.lstat(link)!
	assert lstat.atime == 1_672_590_635
	assert lstat.mtime == 1_672_590_635

	os.rm(link)!
	os.rm(file)!
	pass()
}
