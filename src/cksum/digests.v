module main

import crypto.blake2b
import crypto.md5
import crypto.sha1
import crypto.sha256
import crypto.sha512

// The checksums cksum can compute.
//
// sysv, bsd and crc produce a number and are printed in decimal. They have no
// printable digest form, so they never get the tagged output form and
// --base64 does not apply to them. The rest are byte digests, printed as hex,
// base64 or raw.
//
// GNU's --help text also lists crc32b, sha2 and sha3, but cksum in coreutils
// 9.4 rejects all three with "invalid argument for --algorithm", so they are
// not offered here either.
enum Algorithm {
	sysv
	bsd
	crc
	md5
	sha1
	sha224
	sha256
	sha384
	sha512
	blake2b
	sm3
}

// algorithm_names is the list GNU prints after an invalid --algorithm, in
// GNU's order.
const algorithm_names = ['bsd', 'sysv', 'crc', 'md5', 'sha1', 'sha224', 'sha256', 'sha384', 'sha512',
	'blake2b', 'sm3']

const blake2b_min_bits = 8
const blake2b_max_bits = 512

// EscapedName is a file name rendered so that a checksum list stays one record
// per line, together with the marker GNU puts at the start of such a line.
struct EscapedName {
	text   string
	marker string
}

// Spelled out rather than written as a raw string, because a raw string cannot
// hold a single backslash: `\\` is two of them.
const backslash = '\\'
const newline = '\n'

// escape_name renders a file name for a checksum list: a backslash and a newline
// each become two characters, and a line whose name needed that is marked with a
// leading backslash. --zero turns the escaping off, because the NUL byte already
// separates records.
fn escape_name(name string) EscapedName {
	mut out := []u8{}
	mut changed := false
	for c in name {
		if c == backslash[0] {
			out << backslash[0]
			out << backslash[0]
			changed = true
		} else if c == newline[0] {
			out << backslash[0]
			out << `n`
			changed = true
		} else {
			out << c
		}
	}
	return EscapedName{
		text:   out.bytestr()
		marker: if changed { backslash } else { '' }
	}
}

// unescape_name is the inverse of escape_name. A backslash that introduces
// neither a backslash nor a newline is kept as it stands, so that a name written
// without escaping still names the same file.
fn unescape_name(name string) string {
	mut out := []u8{}
	mut i := 0
	for i < name.len {
		c := name[i]
		if c == backslash[0] && i + 1 < name.len {
			next := name[i + 1]
			if next == backslash[0] {
				out << backslash[0]
				i += 2
				continue
			}
			if next == `n` {
				out << newline[0]
				i += 2
				continue
			}
		}
		out << c
		i++
	}
	return out.bytestr()
}

// Checksum is the result of checksumming one input. Numeric holds a 16 or 32 bit
// value for the numeric algorithms and digest holds the bytes for the rest.
struct Checksum {
	numeric u32
	digest  []u8
}

fn parse_algorithm(name string) !Algorithm {
	return match name {
		'sysv' { Algorithm.sysv }
		'bsd' { Algorithm.bsd }
		'crc' { Algorithm.crc }
		'md5' { Algorithm.md5 }
		'sha1' { Algorithm.sha1 }
		'sha224' { Algorithm.sha224 }
		'sha256' { Algorithm.sha256 }
		'sha384' { Algorithm.sha384 }
		'sha512' { Algorithm.sha512 }
		'blake2b' { Algorithm.blake2b }
		'sm3' { Algorithm.sm3 }
		else { return error(invalid_algorithm(name)) }
	}
}

fn invalid_algorithm(value string) string {
	mut lines := ['invalid argument ‘${value}’ for ‘--algorithm’', 'Valid arguments are:']
	for name in algorithm_names {
		lines << '  - ‘${name}’'
	}
	return lines.join('\n')
}

// is_numeric reports whether the algorithm produces a number rather than a byte
// digest.
fn (a Algorithm) is_numeric() bool {
	return a in [Algorithm.sysv, .bsd, .crc]
}

// bit_length is the digest length in bits, or 0 for the numeric algorithms.
fn (a Algorithm) bit_length() int {
	return match a {
		.md5 { 128 }
		.sha1 { 160 }
		.sha224 { 224 }
		.sha256 { 256 }
		.sha384 { 384 }
		.sha512 { 512 }
		.blake2b { blake2b_max_bits }
		.sm3 { 256 }
		else { 0 }
	}
}

// tag is the name used in the tagged output form, for example "MD5". BLAKE2b
// carries its digest length unless that is the maximum.
fn (a Algorithm) tag(bits int) string {
	return match a {
		.md5 { 'MD5' }
		.sha1 { 'SHA1' }
		.sha224 { 'SHA224' }
		.sha256 { 'SHA256' }
		.sha384 { 'SHA384' }
		.sha512 { 'SHA512' }
		.blake2b {
			if bits == blake2b_max_bits {
				'BLAKE2b'
			} else {
				'BLAKE2b-${bits}'
			}
		}
		.sm3 { 'SM3' }
		else { '' }
	}
}

// accepts_length reports whether --length may be combined with the algorithm.
// GNU only allows it for BLAKE2b, whose digest length is variable.
fn (a Algorithm) accepts_length() bool {
	return a == .blake2b
}

// warning_name is how the algorithm is spelled in a --check warning about a
// malformed line. The numeric algorithms never get a tagged form, but GNU still
// names them there.
fn (a Algorithm) warning_name() string {
	name := a.tag(a.bit_length())
	if name.len > 0 {
		return name
	}
	return match a {
		.sysv { 'SYSV' }
		.bsd { 'BSD' }
		.crc { 'CRC' }
		else { 'unknown' }
	}
}

fn checksum(alg Algorithm, data []u8, bits int) !Checksum {
	if alg.is_numeric() {
		return Checksum{
			numeric: match alg {
				.sysv { sysv_checksum(data) }
				.bsd { bsd_checksum(data) }
				else { crc_checksum(data) }
			}
		}
	}
	return Checksum{
		digest: byte_digest(alg, data, bits)
	}
}

fn byte_digest(alg Algorithm, data []u8, bits int) []u8 {
	return match alg {
		.md5 { md5.sum(data) }
		.sha1 { sha1.sum(data) }
		.sha224 { sha256.sum224(data) }
		.sha256 { sha256.sum256(data) }
		.sha384 { sha512.sum384(data) }
		.sha512 { sha512.sum512(data) }
		.sm3 { sm3_sum(data) }
		.blake2b {
			mut d := blake2b.new_digest(u8(bits / 8), []u8{}) or { panic(err) }
			d.write(data) or { panic(err) }
			d.checksum()
		}
		else { [] }
	}
}

// sysv_checksum is the classic System V sum: add every byte, then fold the
// carry back into the low half three times. Verified against GNU for inputs
// from 0 to 256 bytes.
fn sysv_checksum(data []u8) u32 {
	mut s := u64(0)
	for b in data {
		s += u64(b)
	}
	for _ in 0 .. 3 {
		s = (s & 0xffff) + ((s >> 16) & 0xffff)
	}
	return u32(s % 0x1_0000)
}

// bsd_checksum is the BSD sum: the accumulator is rotated right one bit before
// each byte is added. Verified against GNU over the same inputs.
fn bsd_checksum(data []u8) u32 {
	mut s := u32(0)
	for b in data {
		s = (s >> 1) | ((s & 1) << 15)
		s = (s + u32(b)) & 0xffff
	}
	return s
}

fn be_u32(data []u8, i int) u32 {
	return u32(data[i]) << 24 | u32(data[i + 1]) << 16 | u32(data[i + 2]) << 8 | u32(data[i + 3])
}

// crc_checksum is the POSIX CRC-32. Eight bytes are folded at a time through
// crctab, then the length is folded in, and the result is inverted.
fn crc_checksum(data []u8) u32 {
	mut crc := u64(0)
	mut i := 0
	for i + 8 <= data.len {
		crc ^= u64(be_u32(data, i))
		second := u64(be_u32(data, i + 4))
		crc = crctab[7][(crc >> 24) & 0xff] ^ crctab[6][(crc >> 16) & 0xff] ^
			crctab[5][(crc >> 8) & 0xff] ^ crctab[4][crc & 0xff] ^
			crctab[3][(second >> 24) & 0xff] ^ crctab[2][(second >> 16) & 0xff] ^
			crctab[1][(second >> 8) & 0xff] ^ crctab[0][second & 0xff]
		i += 8
	}
	for i < data.len {
		crc = (crc << 8) ^ u64(crctab[0][((crc >> 24) ^ u64(data[i])) & 0xff])
		i++
	}
	mut length := u64(data.len)
	for length > 0 {
		crc = (crc << 8) ^ u64(crctab[0][((crc >> 24) ^ length) & 0xff])
		length >>= 8
	}
	return u32(~crc & 0xffff_ffff)
}
