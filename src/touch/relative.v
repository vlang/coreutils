module main

import strconv
import time

// The relative items GNU resolves against the clock: yesterday, 2 hours ago,
// next week, -1 day, +2 weeks. Every rule here was measured against GNU 9.4
// rather than read out of its manual, and two of them are the opposite of what
// the shape of the input suggests:
//
//   - A bare item is a plain number of seconds, not a shift of the wall clock.
//     Under TZ=America/New_York at 18:00:18 EDT, `+1 month` moved by exactly
//     2678400 and landed at 17:00:00 EST; adding a month to local time would have
//     made it 18:00 EST, an hour later. Every day, week and month item read the
//     same in UTC, Asia/Tehran and America/New_York, which is only possible if
//     the zone is not consulted at all.
//
//   - `ago` negates the item it follows and leaves the rest alone, so
//     `1 day 2 hours ago` is +22 hours and `2 hours 1 day ago` is -22. Negating
//     the whole string would give -26 for the first, which is not what GNU prints.
//
// A signed count carries its sign and nothing else: `-1 day` is -86400. Given an
// explicit base date GNU's signed items also shift by an hour per count, so
// `-2 weeks` after a date is +7 days +2 hours; that is a different path in GNU's
// parser and this file deliberately does not implement it.

// rel_units are the spellings GNU takes, and the two it does not: `1 y`, `1 yr`
// and `1 M` are all invalid, while `1 mon` parses as a weekday name and is
// ignored, which worded_date already handles.
const rel_units = {
	'sec':        RelUnit.second
	'secs':       RelUnit.second
	'second':     RelUnit.second
	'seconds':    RelUnit.second
	'min':        RelUnit.minute
	'mins':       RelUnit.minute
	'minute':     RelUnit.minute
	'minutes':    RelUnit.minute
	'hour':       RelUnit.hour
	'hours':      RelUnit.hour
	'day':        RelUnit.day
	'days':       RelUnit.day
	'week':       RelUnit.week
	'weeks':      RelUnit.week
	'fortnight':  RelUnit.fortnight
	'fortnights': RelUnit.fortnight
	'month':      RelUnit.month
	'months':     RelUnit.month
	'year':       RelUnit.year
	'years':      RelUnit.year
}

enum RelUnit {
	second
	minute
	hour
	day
	week
	fortnight
	month
	year
}

// A RelItem is one item's contribution, kept in three units so that the months
// can be applied to the calendar before the rest is added as seconds. That order
// is the difference between 31 January +1 month being 2 March and being 1 March.
struct RelItem {
	months  int
	days    int
	seconds i64
}

fn (item RelItem) negated() RelItem {
	return RelItem{
		months:  -item.months
		days:    -item.days
		seconds: -item.seconds
	}
}

// relative_date answers with an absolute instant, or none when the string is not a
// relative item. Only the bare forms are here: `2020-01-02 tomorrow` is a GNU
// spelling this does not read, and no test claims otherwise.
fn relative_date(s string) ?i64 {
	words := s.split_any(' \t').filter(it != '')
	if words.len == 0 {
		return none
	}
	mut items := []RelItem{}
	mut i := 0
	for i < words.len {
		word := words[i].to_lower_ascii()
		// `previous` reads like `last` and is refused outright: GNU takes `last day`
		// and rejects `previous day`.
		if word == 'previous' {
			return none
		}
		match word {
			// `today` and `now` both name this instant. Measured with the clock at
			// 01:31:18, `date -d today` returned that second and not midnight, which is
			// the opposite of what a date word suggests.
			'now', 'today' {
				items << RelItem{}
				i++
			}
			'yesterday' {
				items << RelItem{
					days: -1
				}
				i++
			}
			'tomorrow' {
				items << RelItem{
					days: 1
				}
				i++
			}
			'ago', 'hence' {
				if items.len == 0 {
					return none
				}
				// `hence` is measured to be a no-op, so only `ago` changes anything.
				if word == 'ago' {
					items[items.len - 1] = items[items.len - 1].negated()
				}
				i++
			}
			'last', 'next', 'this' {
				// A count may not follow the direction word: `last 2 days` and
				// `next 2 weeks` are both invalid at GNU.
				if i + 1 >= words.len {
					return none
				}
				unit := rel_unit(words[i + 1]) or { return none }
				count := if word == 'last' {
					-1
				} else if word == 'next' {
					1
				} else {
					0
				}
				items << scaled(unit, count)
				i += 2
			}
			else {
				mut sign := 1
				mut digits := word
				if digits.starts_with('+') {
					digits = digits[1..]
				} else if digits.starts_with('-') {
					sign = -1
					digits = digits[1..]
				}
				// A bare number is an hour of the day, which clock_of already reads,
				// so it is not a count here, and a count with no unit is incomplete.
				if !all_digits(digits) || i + 1 >= words.len {
					return none
				}
				count := strconv.atoi(digits) or { return none }
				unit := rel_unit(words[i + 1]) or { return none }
				items << scaled(unit, sign * count)
				i += 2
			}
		}
	}
	mut months := 0
	mut days := 0
	mut seconds := i64(0)
	for item in items {
		months += item.months
		days += item.days
		seconds += item.seconds
	}
	return shifted(time.now().unix(), months, days, seconds)
}

// rel_unit looks a word up with `in` first on purpose. A map read of a key that is
// not there yields the zero value without running an `or` block, and the zero
// value of RelUnit is `.second`: that turned every unrecognised word into one
// second, so `-d '1 March'` parsed as a second from now instead of failing.
fn rel_unit(word string) ?RelUnit {
	key := word.to_lower_ascii()
	if !(key in rel_units) {
		return none
	}
	return rel_units[key]
}

fn scaled(unit RelUnit, count int) RelItem {
	mut months := 0
	mut days := 0
	mut seconds := i64(0)
	match unit {
		.second {
			seconds = i64(count)
		}
		.minute {
			seconds = i64(count) * 60
		}
		.hour {
			seconds = i64(count) * 3600
		}
		.day {
			days = count
		}
		.week {
			days = count * 7
		}
		.fortnight {
			days = count * 14
		}
		.month {
			months = count
		}
		.year {
			months = count * 12
		}
	}
	return RelItem{
		months:  months
		days:    days
		seconds: seconds
	}
}

// shifted moves an instant by whole months, then whole days, then seconds.
//
// Everything after the months is plain arithmetic on the epoch, which is what the
// measurements call for: a bare `-1 day` is -86400 even in a zone that changes its
// offset that night, so there is nothing here for the time zone to say.
fn shifted(epoch i64, months int, days int, seconds i64) i64 {
	utc := time.unix(epoch)
	year, month, day := add_months(utc.year, utc.month, utc.day, months)
	return days_from_civil(year, month, day) * 86400 + i64(utc.hour) * 3600 +
		i64(utc.minute) * 60 + i64(utc.second) + i64(days) * 86400 + seconds
}

// add_months moves a date by whole months and carries an over-long day into the
// next month rather than clamping it to the last day of the one before. The
// table, from GNU 9.4:
//
//	2020-01-31 +1  ->  2020-03-02		31 February is 2 March
//	2020-03-31 -1  ->  2020-03-02		and 31 February again, going back
//	2020-03-31 +1  ->  2020-05-01		31 April is 1 May
//	2020-02-29 +12 ->  2021-03-01		29 February 2021 is 1 March
fn add_months(year int, month int, day int, count int) (int, int, int) {
	total := year * 12 + (month - 1) + count
	// Floor division, so a date before 1970 keeps its month instead of wrapping.
	// V's / truncates towards zero, which is why the correction is spelled out.
	mut y := total / 12
	mut m := total % 12 + 1
	if total < 0 && total % 12 != 0 {
		y -= 1
		m += 12
	}
	mut d := day
	for {
		month_len := days_in_month(m, y)
		if d <= month_len {
			break
		}
		d -= month_len
		m++
		if m > 12 {
			m = 1
			y++
		}
	}
	return y, m, d
}

// days_from_civil counts days from 1970-01-01 in the proleptic Gregorian calendar.
// It is here so that a bare relative item needs no Location: the answer is a
// number of seconds, and a time zone has no part in it.
fn days_from_civil(year int, month int, day int) int {
	mut y := year
	if month <= 2 {
		y -= 1
	}
	era := (if y >= 0 { y } else { y - 399 }) / 400
	year_of_era := y - era * 400 // [0, 399]
	shifted_month := (month + 9) % 12 // March is 0
	day_of_year := (153 * shifted_month + 2) / 5 + day - 1 // [0, 365]
	day_of_era := year_of_era * 365 + year_of_era / 4 - year_of_era / 100 +
		day_of_year // [0, 146096]
	return era * 146097 + day_of_era - 719468
}
