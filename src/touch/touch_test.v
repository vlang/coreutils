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

// A string with no zone in it is read in the zone TZ names, and this is what makes
// the rest of the file mean anything. On Windows V answers 'Local' with the zone
// the machine is set to whatever the environment says, so measured on this host at
// +0330, TZ=America/New_York still gave +0330 and every stamp below would have been
// off by the difference on any other machine.
//
//	2020-01-02 in UTC               ->  1_577_923_200
//	2020-01-02 in Asia/Tehran       ->  1_577_910_600
//	2020-01-02 in America/New_York  ->  1_577_941_200
fn test_parse_datetime_follows_tz() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	assert parse_datetime('2020-01-02', false)! == 1_577_910_600
	_ = os.setenv('TZ', 'America/New_York', true)
	assert parse_datetime('2020-01-02', false)! == 1_577_941_200
	_ = os.setenv('TZ', 'UTC', true)
	assert parse_datetime('2020-01-02', false)! == 1_577_923_200
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

// Month names, weekday names and the C locale's m/d/y. Stamps read off GNU 9.4
// under TZ=Asia/Tehran:
//	March 1 2020        -> 1583008200
//	1/2/2020            -> 1577910600
//	29 February 2020    -> 1582921800
//	March 1 2020 03:04  -> 1583019240
fn test_parse_datetime_month_names() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	// The month may come first or last, with or without commas, in any case.
	assert parse_datetime('March 1 2020', false)! == 1_583_008_200
	assert parse_datetime('1 March 2020', false)! == 1_583_008_200
	assert parse_datetime('March 1, 2020', false)! == 1_583_008_200
	assert parse_datetime('march 1, 2020', false)! == 1_583_008_200
	assert parse_datetime('MARCH 1 2020', false)! == 1_583_008_200
	// The three letter form, and the full one.
	assert parse_datetime('Mar 1 2020', false)! == 1_583_008_200
	assert parse_datetime('February 29 2020', false)! == 1_582_921_800
	assert parse_datetime('29 February 2020', false)! == 1_582_921_800
	// A time may follow.
	assert parse_datetime('March 1 2020 03:04', false)! == 1_583_019_240
	pass()
}

// A weekday name is accepted and then ignored, even when it is the wrong one:
// 2020-03-01 was a Sunday, and GNU gives 2020-03-01 for Sun, Mon and Sat alike.
fn test_parse_datetime_weekday_is_ignored() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	plain := parse_datetime('March 1 2020', false)!
	assert parse_datetime('Sun March 1 2020', false)! == plain
	assert parse_datetime('Mon March 1 2020', false)! == plain
	assert parse_datetime('Monday, March 1, 2020', false)! == plain
	pass()
}

// The C locale reads a slashed date month first, and does not fall back to
// day first when the first number cannot be a month.
fn test_parse_datetime_slashed_date() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	// 1/2/2020 is 2 January here, not 1 February.
	assert parse_datetime('1/2/2020', false)! == 1_577_910_600
	assert parse_datetime('1/2/2020', false)! == parse_datetime('2020-01-02', false)!
	// 2/1/2020 is 1 February.
	assert parse_datetime('2/1/2020', false)! == parse_datetime('2020-02-01', false)!
	// 13 cannot be a month, and GNU rejects it rather than reading 13 February.
	assert_parse_fails('13/2/2020', false)
	assert parse_datetime('1/13/2020', false)! == parse_datetime('2020-01-13', false)!
	// A two digit year, and a time may follow.
	assert parse_datetime('1/2/20', false)! == parse_datetime('2020-01-02', false)!
	assert parse_datetime('1/2/2020 03:04:05', false)! == parse_datetime('2020-01-02 03:04:05', false)!
	pass()
}

// A missing year is the current one, so the expectation has to be built rather
// than written down.
fn test_parse_datetime_missing_year_is_this_year() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	loc := time.load_location('Local') or { return }
	this_year := time.unix(time.now().unix()).in(loc) or { return }.year
	stamp := parse_datetime('1 March', false) or {
		assert false, '1 March should parse'
		return
	}
	read_back := time.unix(stamp).in(loc) or { return }
	assert read_back.year == this_year
	assert read_back.month == 3
	assert read_back.day == 1
	pass()
}

// GNU checks the day against the month rather than rolling it over, and needs a
// day at all: `March 2020` is an error there too.
fn test_parse_datetime_rejects_impossible_dates() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	assert_parse_fails('31 April 2020', false)
	assert_parse_fails('30 February 2020', false)
	assert_parse_fails('March 2020', false)
	// 29 February is fine in a leap year and not otherwise.
	assert parse_datetime('29 February 2020', false)! != 0
	assert_parse_fails('29 February 2021', false)
	pass()
}

// A bare four digit number is HHMM on its own, but a year once a year is taken.
// Both were measured: `-d 2020` is 20:20 today, and `March 1 2020 0304` is 03:04
// on 1 March 2020.
fn test_parse_datetime_four_digits_are_ambiguous() {
	p(@METHOD)
	saved := pin_zone(tehran)
	defer {
		_ = os.setenv('TZ', saved, true)
	}
	if !zone_available() {
		return
	}
	midnight := parse_datetime('00:00', false)!
	assert parse_datetime('2020', false)! == midnight + (20 * 3600 + 20 * 60)
	assert parse_datetime('0304', false)! == midnight + (3 * 3600 + 4 * 60)
	assert parse_datetime('March 1 2020 0304', false)! == parse_datetime('2020-03-01 03:04', false)!
	pass()
}

// The relative items GNU resolves against the clock. Measured at GNU 9.4, and
// identical in UTC, Asia/Tehran and America/New_York, because a bare item is a
// plain number of seconds and consults no zone at all:
//
//	yesterday  -86400		tomorrow    +86400
//	-1 day     -86400		1 day ago   -86400
//	last day   -86400		next day    +86400
//	2 hours ago -7200		2 hours     +7200
//	last week  -604800		next week   +604800
//	+2 weeks   +1209600		1 fortnight +1209600
//
// The comparison is a window rather than an equality because both sides read the
// clock as they run: parse_datetime calls time.now() and so does the expectation,
// and the second between those two calls is not a disagreement with GNU.
//
// Each zone is entered through a control that has to hold before the deltas are
// read, because a relative item looks the same in every zone. If TZ stopped being
// honoured the deltas below would carry on passing and prove nothing, and the one
// assertion that would notice is a local midnight.
const zone_midnights = {
	'UTC':              1_577_923_200
	'Asia/Tehran':      1_577_910_600
	'America/New_York': 1_577_941_200
}

fn test_parse_datetime_relative_items() {
	p(@METHOD)
	for zone, midnight in zone_midnights {
		saved := pin_zone(zone)
		assert parse_datetime('2020-01-02', false)! == midnight, 'TZ ${zone} not in force'
		assert_relative_delta('yesterday', -86_400)
		assert_relative_delta('tomorrow', 86_400)
		assert_relative_delta('-1 day', -86_400)
		assert_relative_delta('1 day ago', -86_400)
		assert_relative_delta('last day', -86_400)
		assert_relative_delta('next day', 86_400)
		assert_relative_delta('this day', 0)
		assert_relative_delta('2 hours ago', -7_200)
		assert_relative_delta('2 hours', 7_200)
		assert_relative_delta('-30 minutes', -1_800)
		assert_relative_delta('last week', -604_800)
		assert_relative_delta('next week', 604_800)
		assert_relative_delta('+2 weeks', 1_209_600)
		assert_relative_delta('1 fortnight', 1_209_600)
		assert_relative_delta('1 fortnight ago', -1_209_600)
		assert_relative_delta('now', 0)
		assert_relative_delta('today', 0)
		assert_relative_delta('last second', -1)
		_ = os.setenv('TZ', saved, true)
	}
	pass()
}

// `ago` negates the item it follows and leaves the rest of the string alone, which
// is the opposite of negating the whole thing. Measured at GNU 9.4:
//
//	1 day 2 hours ago   +79200	a day forward and two hours back
//	2 hours 1 day ago   -79200	the same two items the other way round
//	1 day 1 day         +172800	two items, no direction word, both positive
//	next day next week   +691200
fn test_parse_datetime_ago_negates_only_its_own_item() {
	p(@METHOD)
	assert_relative_delta('1 day 2 hours ago', 79_200)
	assert_relative_delta('2 hours 1 day ago', -79_200)
	assert_relative_delta('1 day 1 day', 172_800)
	assert_relative_delta('next day next week', 691_200)
	pass()
}

// The words are read in any case, and `hence` is accepted without changing the
// sign. Both measured at GNU 9.4.
fn test_parse_datetime_relative_words_are_case_insensitive() {
	p(@METHOD)
	assert_relative_delta('Yesterday', -86_400)
	assert_relative_delta('YESTERDAY', -86_400)
	assert_relative_delta('Next Week', 604_800)
	assert_relative_delta('2 HOURS AGO', -7_200)
	assert_relative_delta('1 day hence', 86_400)
	pass()
}

// Whole months are the one item whose number of seconds depends on the day of the
// month, so the arithmetic is pinned on its own here and the wiring is checked by
// the test below it. GNU normalises the overflow rather than clamping it, so
// 31 January is 2 March and not 29 February.
fn test_add_months_carries_an_over_long_day() {
	p(@METHOD)
	mut year := 0
	mut month := 0
	mut day := 0
	year, month, day = add_months(2020, 1, 31, 1)
	assert year == 2020 && month == 3 && day == 2
	year, month, day = add_months(2020, 3, 31, -1)
	assert year == 2020 && month == 3 && day == 2
	year, month, day = add_months(2020, 3, 31, 1)
	assert year == 2020 && month == 5 && day == 1
	year, month, day = add_months(2020, 2, 29, 12)
	assert year == 2021 && month == 3 && day == 1
	// A year is twelve months, and a month before 1970 keeps its own month rather
	// than wrapping, which is what floor division is for.
	year, month, day = add_months(1969, 12, 31, -12)
	assert year == 1968 && month == 12 && day == 31
	pass()
}

// `last month` has to land a calendar month back and keep the time of day, and a
// month is between 28 and 31 days. The day of the month is left to add_months
// above, because on the 31st the two readings of it differ and only one is right.
fn test_parse_datetime_month_items_move_the_month() {
	p(@METHOD)
	before := time.now().unix()
	got := parse_datetime('last month', false)!
	after := time.now().unix()
	landed := time.unix(got)
	now := time.unix(before)
	assert landed.hour == now.hour && landed.minute == now.minute
	if now.month == 1 {
		assert landed.month == 12 && landed.year == now.year - 1
	} else {
		assert landed.month == now.month - 1 && landed.year == now.year
	}
	assert got <= after && got >= after - 31 * 86400
	assert got >= before - 31 * 86400 && got <= before - 28 * 86400
	pass()
}

// Spellings and combinations that read like the ones GNU takes and that it
// rejects. Each was measured, and each has to stay rejected: accepting one would
// be a wrong answer rather than a missing feature.
fn test_parse_datetime_rejects_relative_words_gnu_rejects() {
	p(@METHOD)
	assert_parse_fails('previous day', false)
	assert_parse_fails('last 2 days', false)
	assert_parse_fails('next 2 weeks', false)
	assert_parse_fails('1 day from now', false)
	assert_parse_fails('1 day after', false)
	assert_parse_fails('1 day before', false)
	assert_parse_fails('ago', false)
	assert_parse_fails('hence', false)
	assert_parse_fails('from now', false)
	assert_parse_fails('last', false)
	assert_parse_fails('2 weeks yonder', false)
	// -t reads the compact stamp and nothing else, so the relative items are not
	// in its vocabulary even though they are in -d's.
	assert_parse_fails('yesterday', true)
	assert_parse_fails('+2 weeks', true)
	pass()
}

// assert_relative_delta checks a relative item against a measured number of
// seconds. parse_datetime reads the clock itself, so the result can only be pinned
// to the second between the two reads: got - want has to land between them.
fn assert_relative_delta(form string, want i64) {
	before := time.now().unix()
	got := parse_datetime(form, false) or { panic('${form} was rejected') }
	after := time.now().unix()
	landed := got - want
	assert landed >= before && landed <= after, '${form}: ${got} - ${want} = ${landed}, outside [${before}, ${after}]'
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
