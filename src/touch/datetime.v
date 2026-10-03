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
// A string that carries its own offset is already an instant and is passed
// through; a string without one is read in the local zone.
fn parse_datetime(s string) !i64 {
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
