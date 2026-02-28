import v.mathutil

// compares strings with embedded numbers (e.g. log17.txt)
fn natural_compare(a &string, b &string) int {
	pa := split(a)
	pb := split(b)
	max := mathutil.min(pa.len, pb.len)

	for i := 0; i < max; i++ {
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

enum State {
	init
	digit
	non_digit
}

fn split(a &string) []string {
	mut result := []string{}
	mut start := 0
	mut state := State.init
	s := a.runes()

	for i := 0; i < s.len; i++ {
		if s[i] >= `0` && s[i] <= `9` {
			if state == State.non_digit {
				result << s[start..i].string()
				start = i
			}
			state = State.digit
		} else {
			if state == State.digit {
				result << s[start..i].string()
				start = i
			}
			state = State.non_digit
		}
	}
	result << s[start..].string()
	return result
}
