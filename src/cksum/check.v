module main

import os
import encoding.base64

// A parsed line of a checksum list. GNU only accepts its own tagged form,
// `DIGEST-NAME (file) = digest`; the untagged output of cksum is not accepted as
// input to --check.
struct CheckLine {
	algorithm Algorithm
	bits      int
	file      string
	value     string
}

struct CheckStats {
mut:
	parsed          int
	verified        int
	failed          int
	unreadable      int
	badly_formatted int
}

// algorithm_from_tag maps the digest name written by cksum onto an algorithm.
// BLAKE2b carries its digest length, as in "BLAKE2b-256".
fn algorithm_from_tag(name string) ?Algorithm {
	for alg in [
		Algorithm.md5,
		.sha1,
		.sha224,
		.sha256,
		.sha384,
		.sha512,
		.sm3,
	] {
		if name == alg.tag(alg.bit_length()) {
			return alg
		}
	}
	if name == 'BLAKE2b' {
		return .blake2b
	}
	if name.starts_with('BLAKE2b-') {
		bits := name[8..].int()
		if bits >= blake2b_min_bits && bits <= blake2b_max_bits && bits % 8 == 0 {
			return .blake2b
		}
	}
	return none
}

fn check_files(settings Settings) {
	mut files := settings.files.clone()
	if files.len == 0 {
		files << '-'
	}

	// The digest to use comes from the first line of the list, unless --algorithm
	// named one explicitly, in which case only lines with that name are accepted.
	mut wanted := settings.algorithm
	mut wanted_known := settings.algorithm_given

	mut stats := CheckStats{}

	for list in files {
		lines := if list == '-' {
			os.get_lines()
		} else {
			os.read_lines(list) or {
				// An unreadable list is fatal on its own; it is not one of the
				// files the list points at, so it does not count towards the
				// "could not be read" warning.
				eprintln('${app_name}: ${list}: ${os.error_posix().msg()}')
				continue
			}
		}

		mut parsed := 0
		for i, line in lines {
			entry := parse_check_line(line) or {
				if settings.warn {
					eprintln('${app_name}: ${list}: ${i + 1}: improperly formatted ${wanted.warning_name()} checksum line')
				}
				stats.badly_formatted++
				continue
			}
			if wanted_known && entry.algorithm != wanted {
				// A list that does not name the requested digest has no properly
				// formatted lines as far as GNU is concerned.
				if settings.warn {
					eprintln('${app_name}: ${list}: ${i + 1}: improperly formatted ${wanted.warning_name()} checksum line')
				}
				stats.badly_formatted++
				continue
			}
			if !wanted_known {
				wanted = entry.algorithm
				wanted_known = true
			}
			parsed++
			stats.parsed++

			// GNU escapes the file name in every message it prints about a
			// listed file, marked the same way as in a list.
			escaped := escape_name(entry.file)
			name := escaped.text
			mark := escaped.marker

			if os.is_dir(entry.file) || !os.exists(entry.file) {
				if !settings.ignore_missing {
					eprintln('${app_name}: ${quote_name(entry.file)}: ${no_such_file_message()}')
					eprintln('${mark}${name}: FAILED open or read')
					stats.unreadable++
				}
				continue
			}

			data := os.read_bytes(entry.file) or {
				if !settings.ignore_missing {
					eprintln('${quote_name(entry.file)}: FAILED open or read')
					stats.unreadable++
				}
				continue
			}

			sum := checksum(entry.algorithm, data, entry.bits) or { continue }
			if matches(sum, entry.value) {
				stats.verified++
				if !settings.quiet && !settings.status {
					println('${mark}${name}: OK')
				}
			} else {
				stats.failed++
				if !settings.status {
					println('${mark}${name}: FAILED')
				}
			}
		}

		if parsed == 0 && !settings.status {
			eprintln('${app_name}: ${list}: no properly formatted checksum lines found')
		}
	}

	if stats.verified == 0 && stats.unreadable == 0 && stats.badly_formatted == 0
		&& settings.ignore_missing {
		// Everything on the list was skipped, so nothing was actually checked.
		for list in files {
			eprintln('${app_name}: ${list}: no file was verified')
		}
		exit(1)
	}

	if stats.unreadable > 0 && !settings.status {
		plural := if stats.unreadable == 1 { 'file' } else { 'files' }
		eprintln('${app_name}: WARNING: ${stats.unreadable} listed ${plural} could not be read')
	}
	if stats.badly_formatted > 0 && stats.parsed > 0 && !settings.status {
		plural := if stats.badly_formatted == 1 { 'line is' } else { 'lines are' }
		eprintln('${app_name}: WARNING: ${stats.badly_formatted} ${plural} improperly formatted')
	}
	if stats.parsed == 0 {
		// Nothing in the input was usable, which is an error even without
		// --strict.
		exit(1)
	}

	if stats.failed > 0 {
		if !settings.status {
			plural := if stats.failed == 1 {
				'checksum did NOT match'
			} else {
				'checksums did NOT match'
			}
			eprintln('${app_name}: WARNING: ${stats.failed} computed ${plural}')
		}
		exit(1)
	}
	if stats.unreadable > 0 || (stats.badly_formatted > 0 && settings.strict) {
		exit(1)
	}
}

fn no_such_file_message() string {
	return os.error_posix().msg()
}

// matches reports whether a computed checksum is the one recorded in the list.
// GNU accepts a hexadecimal list with or without --base64, so both are tried.
fn matches(sum Checksum, value string) bool {
	if sum.digest.hex() == value {
		return true
	}
	return base64.encode(sum.digest) == value
}

// digest_form_ok reports whether the recorded digest has a length and alphabet
// that the named algorithm could have produced. GNU rejects anything else as an
// improperly formatted line, which is also why a list written by "cksum -z",
// whose lines end in a NUL byte, is not accepted here.
fn digest_form_ok(value string, bits int) bool {
	return is_hex(value, bits / 4) || is_base64(value, bits / 8)
}

// is_hex reports whether s is exactly n hexadecimal digits.
fn is_hex(s string, n int) bool {
	if s.len != n {
		return false
	}
	for c in s {
		if !((c >= `0` && c <= `9`) || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)) {
			return false
		}
	}
	return true
}

// is_base64 reports whether s is the padded base64 encoding of n bytes.
fn is_base64(s string, n int) bool {
	if s.len != 4 * ((n + 2) / 3) {
		return false
	}
	for c in s {
		if !((c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`)
			|| c == `+` || c == `/` || c == `=`) {
			return false
		}
	}
	return true
}

// parse_check_line accepts `DIGEST-NAME (file) = digest`, optionally preceded by
// the backslash that marks an escaped file name.
fn parse_check_line(line string) ?CheckLine {
	mut trimmed := line.trim_space()
	if trimmed.len > 0 && trimmed[0] == backslash[0] {
		trimmed = trimmed[1..]
	}
	open := trimmed.index(' (') or { -1 }
	if open < 0 {
		return none
	}
	eq := trimmed.index(') = ') or { -1 }
	if eq < 0 {
		return none
	}
	name := trimmed[..open].trim_space()
	file := trimmed[open + 2..eq]
	value := trimmed[eq + 4..].trim_space()
	if name.len == 0 || file.len == 0 || value.len == 0 {
		return none
	}
	algorithm := algorithm_from_tag(name) or { return none }
	bits := if algorithm == .blake2b && name != 'BLAKE2b' {
		name[8..].int()
	} else {
		algorithm.bit_length()
	}
	if !digest_form_ok(value, bits) {
		return none
	}
	return CheckLine{
		algorithm: algorithm
		bits:      bits
		file:      unescape_name(file)
		value:     value
	}
}
