import strconv
import time

// A date string with no zone in it names a *local* time. That is the whole
// point of this file, and it is the one thing the port had wrong: a naive
// string was read as though it were UTC, so on this machine, at +0330,
//
//	touch -d '2020-01-02 03:04:05'
//
// set the file to 06:34:05, three and a half hours late, and GNU sets 03:04:05.
//
// The offset cannot come from time.offset(), which reports the zone now. The
// same zone wants a different offset depending on the date, and both of these
// were measured against GNU rather than assumed:
//
//	TZ=Asia/Tehran        2021-06-07 08:09:10  wants +0430, and +0330 now
//	TZ=America/New_York   2020-01-02 00:00:00  wants -0500, and -0400 now
//
// So the offset has to be the one in force at the date being converted, which
// is what zoneinfo's offset_at answers.
const unresolved = 'no local time zone could be determined'

// parse_datetime turns the argument of touch -d or -t into an absolute instant.
// compact says which flag it came from, because the compact stamp belongs to -t:
// GNU reads `-t 202001020304` as a date and `-d 202001020304` as something else
// entirely, landing in the year 2446.
//
// Everything this file recognises is rewritten into an ISO 8601 string first,
// so that one conversion at the end handles all of it. That keeps the zone logic
// in a single place instead of once per spelling.
fn parse_datetime(s string, compact bool) !i64 {
	if s.starts_with('@') {
		return epoch_seconds(s)
	}
	iso := to_iso8601(s, compact)
	if iso != none {
		return from_iso8601(iso)
	}
	return from_iso8601(s)
}

// epoch_seconds reads @1600000000 and @1600000000.5. GNU keeps only the whole
// second, since that is all a file stamp can hold.
fn epoch_seconds(s string) !i64 {
	body := s[1..]
	mut whole := body
	if idx := body.index('.') {
		whole = body[..idx]
	}
	if whole.len == 0 {
		return error('unable to parse date ${s}')
	}
	n := strconv.atoi64(whole) or { return error('unable to parse date ${s}') }
	return n
}

// to_iso8601 rewrites the spellings GNU accepts but parse_iso8601 does not, and
// returns none for anything it does not recognise so the caller can fall back.
fn to_iso8601(s string, compact bool) ?string {
	if compact {
		compact_iso := compact_stamp(s)
		if compact_iso != none {
			return compact_iso
		}
	}
	zoned := split_zone_word(s)
	if zoned != none {
		// `10:00 UTC` and `10:00 GMT+3` name today at that time in that zone.
		// Today is needed because a bare time means today at GNU, not 1970.
		zoned_clock := clock_of(zoned.rest)
		if zoned_clock == none {
			return none
		}
		y, m, d := local_today()
		stamp := '${y}-${pad2(m)}-${pad2(d)}' +
			'T${pad2(zoned_clock.hour)}:${pad2(zoned_clock.minute)}:${pad2(zoned_clock.second)}' +
			zone_suffix(zoned.offset)
		return stamp
	}
	basic := basic_date(s)
	if basic != none {
		// A bare YYYYMMDD is local midnight on that date.
		return '${basic.year}-${pad2(basic.month)}-${pad2(basic.day)}T00:00:00'
	}
	bare := clock_of(s)
	if bare != none {
		// A bare time is today at that time.
		y, m, d := local_today()
		return '${y}-${pad2(m)}-${pad2(d)}' +
			'T${pad2(bare.hour)}:${pad2(bare.minute)}:${pad2(bare.second)}'
	}
	// Month names, weekday names and the C locale's m/d/y come after the shapes
	// above, so nothing here can shadow them.
	shortened := short_time(s)
	if shortened != none {
		return shortened
	}
	worded := worded_date(s)
	if worded != none {
		return worded
	}
	return none
}

// short_time supplies the seconds that `2020-01-02 03:04` and `2020-01-02 03`
// leave out. GNU takes both; parse_iso8601 insists on HH:MM:SS.
fn short_time(s string) ?string {
	mut sep := s.index_('T')
	mut cut := sep + 1
	if sep == -1 {
		sep = s.index_(' ')
		if sep == -1 {
			return none
		}
		cut = sep + 1
	}
	date_part := s[..sep]
	// Only an ISO date, so that `1 March 2020` cannot reach here.
	if date_part.len != 10 || !date_part.contains('-') {
		return none
	}
	time_part := s[cut..]
	if time_part.count(':') == 2 {
		return none
	}
	clock := clock_of(time_part) or { return none }
	return '${date_part}T${pad2(clock.hour)}:${pad2(clock.minute)}:${pad2(clock.second)}'
}

// month_numbers maps a month name to its number, ignoring case and an optional
// full stop: GNU takes MARCH, march and Mar. alike.
const month_numbers = {
	'january':   1
	'jan':       1
	'february':  2
	'feb':       2
	'march':     3
	'mar':       3
	'april':     4
	'apr':       4
	'may':       5
	'june':      6
	'jun':       6
	'july':      7
	'jul':       7
	'august':    8
	'aug':       8
	'september': 9
	'sep':       9
	'sept':      9
	'october':   10
	'oct':       10
	'november':  11
	'nov':       11
	'december':  12
	'dec':       12
}

// weekday_names are accepted and then ignored, the way GNU does: `Mon March 2
// 2020` gives 2020-03-02 whether or not that day was a Monday.
const weekday_names = ['sunday', 'sun', 'monday', 'mon', 'tuesday', 'tue', 'tues', 'wednesday',
	'wed', 'thursday', 'thu', 'thur', 'thurs', 'friday', 'fri', 'saturday', 'sat']

// worded_date rewrites the dates that name a month or separate their parts with
// slashes, and returns none for everything else.
//
// What GNU does, all measured:
//   March 1, 2020 / 1 March 2020 / Mar 1 2020   the month may come first or last,
//                                               with or without commas, in any
//                                               case
//   Mon March 2 2020                             a weekday name is ignored
//   1 March                                      a missing year is the current one
//   31 April 2020                                rejected, so the day is checked
//   March 2020                                   rejected, so a day is required
//   1/2/2020 and 2/1/2020                        the C locale is month first:
//                                               2 January and 1 February
//   13/2/2020                                    rejected, so a slash date's first
//                                               number must be a month and is never
//                                               read as a day
//   1/2/20                                       a two digit year
//   March 1 2020 03:04                           a time may follow
fn worded_date(s string) ?string {
	mut words := s.replace(',', ' ').split(' ').filter(it != '')
	if words.len == 0 {
		return none
	}
	// A time may trail the date. It has to carry its colons here: a bare four digit
	// token is read as a year inside a worded date, and only as HHMM when it stands
	// on its own. GNU draws that line too, since `-d 2020` is 20:20 today while
	// `March 1 2020 0304` keeps 2020 as the year and takes 0304 as the time.
	mut stamp := '00:00:00'
	if words[words.len - 1].contains(':') {
		trailing := clock_of(words[words.len - 1])
		if trailing == none {
			return none
		}
		stamp = '${pad2(trailing.hour)}:${pad2(trailing.minute)}:${pad2(trailing.second)}'
		words = words[..words.len - 1]
		if words.len == 0 {
			// A bare time after all, which to_iso8601 already handles.
			return none
		}
	}
	// A slashed date is one token and follows the C locale strictly.
	if words.len == 1 {
		if iso := slashed_date(words[0], stamp) {
			return iso
		}
	}
	mut month := 0
	mut day := 0
	mut year := 0
	for word in words {
		mut w := word.to_lower_ascii()
		if w.contains('.') {
			w = w.trim_right('.').to_lower_ascii()
		}
		if m := month_numbers[w] {
			month = m
			continue
		}
		if weekday_names.contains(w) {
			continue
		}
		n := strconv.atoi(w) or { return none }
		// Four digits are ambiguous on their own: alone they are HHMM, but after
		// a year has been taken they are another time, as
		// `March 1 2020 0304` is 03:04 on 1 March 2020.
		if word.len == 4 && all_digits(w) {
			hour := strconv.atoi(w[..2]) or { return none }
			minute := strconv.atoi(w[2..]) or { return none }
			if year != 0 && hour <= 23 && minute <= 59 {
				stamp = '${pad2(hour)}:${pad2(minute)}:00'
				continue
			}
			if year == 0 {
				year = n
				continue
			}
			return none
		}
		// A number in day range is the day. Anything else is the year, and a two
		// digit year takes its century the same way the slashed form does.
		if day == 0 && n >= 1 && n <= 31 {
			day = n
			continue
		}
		if year == 0 {
			year = if word.len == 2 { 2000 + n } else { n }
			continue
		}
		return none
	}
	if month == 0 || day == 0 {
		return none
	}
	if year == 0 {
		// No year given, so this year. Measured: `1 March` on 2026-10-03 gives
		// 2026-03-01.
		year = time.now().year
	}
	if day > days_in_month(month, year) {
		// GNU rejects 31 April rather than rolling it over into May.
		return none
	}
	return '${year}-${pad2(month)}-${pad2(day)}T${stamp}'
}

// slashed_date reads the C locale's m/d/y, where the first number must be a
// month: 13/2/2020 is an error at GNU, not 13 February.
fn slashed_date(word string, stamp string) ?string {
	parts := word.split('/')
	if parts.len != 3 {
		return none
	}
	month := strconv.atoi(parts[0]) or { return none }
	day := strconv.atoi(parts[1]) or { return none }
	if month < 1 || month > 12 || day < 1 {
		return none
	}
	mut year := 0
	if parts[2].len == 4 {
		year = strconv.atoi(parts[2]) or { return none }
	} else if parts[2].len == 2 {
		// Measured: 1/2/20 is 2020-01-02, so the century comes from the first two.
		year = 2000 + (strconv.atoi(parts[2]) or { return none })
	} else {
		return none
	}
	if day > days_in_month(month, year) {
		return none
	}
	return '${year}-${pad2(month)}-${pad2(day)}T${stamp}'
}

// days_in_month is a local copy rather than a reach into time, which keeps this
// file's idea of a calendar in one place.
fn days_in_month(month int, year int) int {
	if month == 2 {
		leap := (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
		return if leap { 29 } else { 28 }
	}
	if month == 4 || month == 6 || month == 9 || month == 11 {
		return 30
	}
	return 31
}

struct Clock {
	hour   int
	minute int
	second int
}

// compact_stamp reads -t's [[CC]YY]MMDDhhmm[.ss]. GNU rejects fourteen digits, so
// the seconds only exist as the fractional part:
//
//	202001020304     ->  2020-01-02 03:04
//	2001020304       ->  2020-01-02 03:04, the century supplied from the first two
//	20200102030405   ->  invalid date format at GNU
fn compact_stamp(s string) ?string {
	mut body := s
	mut second := 0
	if idx := s.index('.') {
		body = s[..idx]
		frac := s[idx + 1..]
		if frac.len != 2 || !all_digits(frac) {
			return none
		}
		second = strconv.atoi(frac) or { return none }
	}
	if (body.len != 10 && body.len != 12) || !all_digits(body) {
		return none
	}
	year := if body.len == 12 {
		strconv.atoi(body[..4]) or { return none }
	} else {
		// Two digit year: GNU reads 20 as 2020, so the century is the one the
		// number is nearest to, which for every year since 1970 is 2000 +.
		2000 + (strconv.atoi(body[..2]) or { return none })
	}
	rest := body[body.len - 8..]
	month := strconv.atoi(rest[..2]) or { return none }
	day := strconv.atoi(rest[2..4]) or { return none }
	hour := strconv.atoi(rest[4..6]) or { return none }
	minute := strconv.atoi(rest[6..8]) or { return none }
	if month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59
		|| second > 60 {
		return none
	}
	return '${year}-${pad2(month)}-${pad2(day)}T${pad2(hour)}:${pad2(minute)}:${pad2(second)}'
}

// split_zone_word pulls a trailing UTC or GMT, with an optional signed hour
// count, off the end of a bare time. The offset is seconds east of UTC, which is
// the opposite sign to the way the suffix is written.
struct Zoned {
	offset int
	rest   string
}

fn split_zone_word(s string) ?Zoned {
	words := s.split(' ')
	if words.len < 2 {
		return none
	}
	last := words[words.len - 1]
	mut base := ''
	for prefix in ['GMT', 'UTC'] {
		if last.starts_with(prefix) {
			base = prefix
			break
		}
	}
	if base == '' {
		return none
	}
	mut hours := 0
	zone_rest := last[base.len..]
	if zone_rest.len > 0 {
		if zone_rest[0] != `+` && zone_rest[0] != `-` {
			return none
		}
		n := strconv.atoi(zone_rest[1..]) or { return none }
		hours = if zone_rest[0] == `-` { -n } else { n }
	}
	// Drop the word and the space in front of it. The parentheses matter: V
	// parses `s[:s.len - last.len]` as `s[:s.len]` followed by arithmetic.
	cut := s.len - last.len - 1
	return Zoned{
		offset: hours * 3600
		rest:   s[..cut]
	}
}

fn zone_suffix(offset int) string {
	if offset == 0 {
		return 'Z'
	}
	sign := if offset < 0 { '-' } else { '+' }
	magnitude := if offset < 0 { -offset } else { offset }
	return '${sign}${pad2(magnitude / 3600)}:${pad2((magnitude % 3600) / 60)}'
}

// clock_of reads a bare time of day: 5 is 05:00, 0304 is 03:04, and 03:04 and
// 03:04:05 are themselves. Returns none for anything longer, which keeps a
// twelve digit compact stamp out of this path.
fn clock_of(s string) ?Clock {
	if s.contains(':') {
		parts := s.split(':')
		if parts.len < 2 || parts.len > 3 {
			return none
		}
		hour := strconv.atoi(parts[0]) or { return none }
		minute := strconv.atoi(parts[1]) or { return none }
		mut second := 0
		if parts.len == 3 {
			second = strconv.atoi(parts[2]) or { return none }
		}
		if hour > 23 || minute > 59 || second > 60 {
			return none
		}
		return Clock{
			hour:   hour
			minute: minute
			second: second
		}
	}
	if all_digits(s) && (s.len == 1 || s.len == 2) {
		hour := strconv.atoi(s) or { return none }
		if hour > 23 {
			return none
		}
		return Clock{
			hour:   hour
			minute: 0
			second: 0
		}
	}
	if s.len == 4 && all_digits(s) {
		hour := strconv.atoi(s[..2]) or { return none }
		minute := strconv.atoi(s[2..]) or { return none }
		if hour > 23 || minute > 59 {
			return none
		}
		return Clock{
			hour:   hour
			minute: minute
			second: 0
		}
	}
	return none
}

// BasicDate is YYYYMMDD, which parse_iso8601 rejects because it expects the
// dashes.
struct BasicDate {
	year  int
	month int
	day   int
}

fn basic_date(s string) ?BasicDate {
	if s.len != 8 || !all_digits(s) {
		return none
	}
	date := BasicDate{
		year:  strconv.atoi(s[..4]) or { return none }
		month: strconv.atoi(s[4..6]) or { return none }
		day:   strconv.atoi(s[6..]) or { return none }
	}
	if date.month < 1 || date.month > 12 || date.day < 1 || date.day > 31 {
		return none
	}
	return date
}

fn local_today() (int, int, int) {
	now := time.unix(time.now().unix()).local()
	return now.year, now.month, now.day
}

fn all_digits(s string) bool {
	if s.len == 0 {
		return false
	}
	for ch in s {
		if ch < `0` || ch > `9` {
			return false
		}
	}
	return true
}

fn pad2(n int) string {
	return if n < 10 { '0${n}' } else { n.str() }
}

// from_iso8601 resolves an ISO string, converting a zone-less one from local
// wall clock to an instant.
fn from_iso8601(s string) !i64 {
	parsed := time.parse_iso8601(s) or { return error('unable to parse date ${s}') }
	if has_explicit_zone(s) {
		return parsed.unix()
	}
	loc := time.load_location('Local') or { return error(unresolved) }
	return local_wall_clock(loc, parsed)
}

// local_wall_clock converts a parsed Time whose calendar fields are local wall
// time into an absolute instant.
//
// parsed.unix() read those fields as if they were UTC, which is the value to
// correct. Subtracting the zone offset at *that* value is one step from the
// answer, and a second step settles it: when the first guess lands on the far
// side of a DST transition the offset it used was the wrong one. Two steps
// agree everywhere except inside the transition hour itself, where GNU also
// has to pick one and there is nothing to check against.
fn local_wall_clock(loc &time.Location, parsed time.Time) i64 {
	naive := parsed.unix()
	mut guess := naive
	for _ in 0 .. 2 {
		offset := loc.offset_at(guess) or { break }
		next := naive - i64(offset)
		if next == guess {
			break
		}
		guess = next
	}
	return guess
}

// has_explicit_zone reports whether the string says which zone it is in, which
// is the difference between an instant and a wall clock reading.
//
// The zone can only appear at the end of the time part, and the date has already
// been split off, so a sign inside the time token can only be a zone: times are
// written with ':' and '.', never with '+' or '-'. That makes the length and
// digit checks unnecessary, and getting them wrong is how `+03:30` came to be
// read as unzoned for one round.
fn has_explicit_zone(s string) bool {
	mut tp := s.index_('T')
	if tp == -1 {
		tp = s.index_(' ')
		if tp == -1 {
			return false
		}
	} else {
		// Step over the T, or the token below still starts with it.
		tp++
	}
	token := s[tp..].split(' ').last()
	if token.len < 2 {
		return false
	}
	if token.contains('+') || token.contains('-') {
		return true
	}
	last := token[token.len - 1]
	return last == `Z` || last == `z`
}
