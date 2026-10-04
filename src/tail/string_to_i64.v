// convert strings like 10K to i164
const block = i64(512)

// binary (IEC) multipliers, i.e. GNU's suffix without the extra i
// **1
const kilo = i64(1024)

// **2
const mega = kilo * kilo

// **3
const giga = mega * kilo

// **4
const terra = giga * kilo

// **5
const peta = terra * kilo

// **6
const exa = peta * kilo

// **7
const zetta = exa * kilo

// decimal (SI) multipliers
const kilobyte = i64(1000)
const megabyte = kilobyte * kilobyte
const gigabyte = megabyte * kilobyte
const terrabyte = gigabyte * kilobyte
const petabyte = terrabyte * kilobyte
const exabyte = petabyte * kilobyte
const zettabyte = exabyte * kilobyte

fn string_to_i64(s string) ?i64 {
	if s.len == 0 {
		return none
	}

	mut index := 0
	for index < s.len {
		match true {
			s[index].is_digit() {}
			s[index] == `+` && index == 0 {}
			s[index] == `-` && index == 0 {}
			else { break }
		}

		index += 1
	}

	number := s[0..index].i64()
	suffix := if index < s.len { s[index..] } else { 'c' }

	multiplier := match suffix.to_lower() {
		'b' { block }
		'k' { kilo }
		'kb' { kilobyte }
		'kib' { kilo }
		'm' { mega }
		'mb' { megabyte }
		'mib' { mega }
		'g' { giga }
		'gb' { gigabyte }
		'gib' { giga }
		't' { terra }
		'tb' { terrabyte }
		'tib' { terra }
		'p' { peta }
		'pb' { petabyte }
		'pib' { peta }
		'e' { exa }
		'eb' { exabyte }
		'eib' { exa }
		// oddball formats found in __xstrtol source
		'c' { 1 }
		'w' { 2 }
		else { return none }
	}

	result := number * multiplier
	if number != 0 && result / number != multiplier {
		// the multiplication wrapped around
		return none
	}
	return result
}
