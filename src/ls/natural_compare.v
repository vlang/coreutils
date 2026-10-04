import math

// natural_compare orders the way GNU's -v does: a run of digits weighs as a
// number rather than character by character, so log17.txt sorts before log9.txt.
// Anything else falls back to compare_strings, so a name with no digits in it
// orders exactly as it would without -v.
fn natural_compare(a &string, b &string) int {
	pa := split(a)
	pb := split(b)
	// Only the shared prefix has to be walked: if every part of it compares
	// equal then the name with fewer parts has run out and comes first.
	shared := math.min(pa.len, pb.len)

	for i in 0 .. shared {
		if pa[i].is_int() && pb[i].is_int() {
			result := pa[i].int() - pb[i].int()
			if result != 0 {
				return result
			}
		} else {
			result := compare_strings(pa[i], pb[i])
			if result != 0 {
				return result
			}
		}
	}
	return pa.len - pb.len
}

// split breaks a name into alternating runs of digits and of everything else, so
// log17.txt becomes ['log', '17', '.txt'] and 9.txt becomes ['9', '.txt'].
fn split(a &string) []string {
	mut result := []string{}
	mut start := 0
	// Whether the character before this one was a digit. Starting false is what
	// stops a leading run from emitting an empty first part.
	mut prev_digit := false
	s := a.runes()
	for i in 0 .. s.len {
		is_digit := s[i] >= `0` && s[i] <= `9`
		if is_digit != prev_digit {
			result << s[start..i].string()
			start = i
		}
		prev_digit = is_digit
	}
	result << s[start..].string()
	return result
}
