import os
import v.mathutil
import encoding.base64
import encoding.base32

fn main() {
	options := get_options()
	for file in options.files {
		if options.decode {
			lines := os.read_lines(file) or { exit_error(err.msg()) }
			content := lines.join('')
			print(decode(content, options))
		} else {
			content := os.read_bytes(file) or { exit_error(err.msg()) }
			print_encoded(encode(content, options), options)
		}
	}
}

fn encode(content []u8, options Options) string {
	return match true {
		options.base64 { base64.encode(content) }
		options.base64url { base64.url_encode(content) }
		options.base32 { base32.encode_to_string(content) }
		options.base32hex { base32hex_encode_to_string(content) }
		options.base16 { base16_encode(content) }
		options.base2msbf { base2msbf_encode(content) }
		options.base2lsbf { base2lsbf_encode(content) }
		options.z85 { z85_encode(content) }
		else { exit_error('must specify encoding option') }
	}
}

fn decode(content string, options Options) string {
	return match true {
		options.base64 { base64.decode_str(content) }
		options.base64url { base64.url_decode_str(content) }
		options.base32 { base32.decode_string_to_string(content) or { exit_error(err.msg()) } }
		options.base32hex { base32hex_decode_to_string(content) }
		options.base16 { base16_decode(content) }
		options.base2msbf { base2msbf_decode(content) }
		options.base2lsbf { base2lsbf_decode(content) }
		options.z85 { z85_decode(content) }
		else { exit_error('must specify encoding option') }
	}
}

fn print_encoded(encoded string, options Options) {
	if options.wrap == 0 {
		println(encoded)
		return
	}
	for start := 0; start < encoded.len; start += options.wrap {
		end := mathutil.min(start + options.wrap, encoded.len)
		// safe to use string slicing because all chars
		// are in printable ascii
		println(encoded[start..end])
	}
}

fn base32hex_encode_to_string(content []u8) string {
	norm_to_hex := [u8(`Q`), `R`, `S`, `T`, `U`, `V`, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e,
		0x3f, 0x40, `0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `A`, `B`, `C`, `D`, `E`,
		`F`, `G`, `H`, `I`, `J`, `K`, `L`, `M`, `N`, `O`, `P`]

	b32 := base32.encode(content)
	mut buf := []u8{len: b32.len, init: 0}
	for i, c in b32 {
		buf[i] = norm_to_hex[c - 0x32]
	}
	return buf.bytestr()
}

fn base32hex_decode_to_string(content string) string {
	hex_to_norm := [u8(`A`), `B`, `C`, `D`, `E`, `F`, `G`, `H`, `I`, `J`, 0x3a, 0x3b, 0x3c, 0x3d,
		0x3e, 0x3f, 0x40, `K`, `L`, `M`, `N`, `O`, `P`, `Q`, `R`, `S`, `T`, `U`, `V`, `W`, `X`,
		`Y`, `Z`, `2`, `3`, `4`, `5`, `6`, `7`]
	mut buf := []u8{len: content.len, init: 0}
	for i, c in content {
		buf[i] = hex_to_norm[c - 0x30]
	}
	return base32.decode_to_string(buf) or { exit_error(err.msg()) }
}

const base16_codes = [`0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `A`, `B`, `C`, `D`, `E`,
	`F`]

fn base16_encode(content []u8) string {
	mut buffer := []u8{len: content.len * 2, init: 0}
	mut idx := 0
	for c in content {
		buffer[idx] = base16_codes[c >> 4]
		buffer[idx + 1] = base16_codes[c & 0x0F]
		idx += 2
	}
	return buffer.bytestr()
}

fn base16_decode(content string) string {
	mut buffer := []u8{len: content.len / 2, init: 0}
	mut idx := 0
	for i := 0; i < content.len; i += 2 {
		u := base16_codes.index(content[i])
		l := base16_codes.index(content[i + 1])
		buffer[idx] = u8(u) << 4 | u8(l)
		idx += 1
	}
	return buffer.bytestr()
}

fn base2msbf_encode(content []u8) string {
	mut buffer := []u8{len: content.len * 8, init: 0}
	mut idx := 0
	for c in content {
		buffer[idx + 0] = emit(c & 0b10000000)
		buffer[idx + 1] = emit(c & 0b01000000)
		buffer[idx + 2] = emit(c & 0b00100000)
		buffer[idx + 3] = emit(c & 0b00010000)
		buffer[idx + 4] = emit(c & 0b00001000)
		buffer[idx + 5] = emit(c & 0b00000100)
		buffer[idx + 6] = emit(c & 0b00000010)
		buffer[idx + 7] = emit(c & 0b00000001)
		idx += 8
	}
	return buffer.bytestr()
}

fn base2msbf_decode(content string) string {
	if content.len % 8 != 0 {
		exit_error('content length must be a multiple of 8')
	}
	mut idx := 0
	mut buffer := []u8{len: content.len / 8, init: 0}
	for i := 0; i < content.len; i += 8 {
		b7 := if content[i + 0] == `1` { 0b10000000 } else { 0b0 }
		b6 := if content[i + 1] == `1` { 0b01000000 } else { 0b0 }
		b5 := if content[i + 2] == `1` { 0b00100000 } else { 0b0 }
		b4 := if content[i + 3] == `1` { 0b00010000 } else { 0b0 }
		b3 := if content[i + 4] == `1` { 0b00001000 } else { 0b0 }
		b2 := if content[i + 5] == `1` { 0b00000100 } else { 0b0 }
		b1 := if content[i + 6] == `1` { 0b00000010 } else { 0b0 }
		b0 := if content[i + 7] == `1` { 0b00000001 } else { 0b0 }

		buffer[idx] = u8(b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0)
		idx += 1
	}
	return buffer.bytestr()
}

fn base2lsbf_encode(content []u8) string {
	mut buffer := []u8{len: content.len * 8, init: 0}
	mut idx := 0
	for c in content {
		buffer[idx + 0] = emit(c & 0b00000001)
		buffer[idx + 1] = emit(c & 0b00000010)
		buffer[idx + 2] = emit(c & 0b00000100)
		buffer[idx + 3] = emit(c & 0b00001000)
		buffer[idx + 4] = emit(c & 0b00010000)
		buffer[idx + 5] = emit(c & 0b00100000)
		buffer[idx + 6] = emit(c & 0b01000000)
		buffer[idx + 7] = emit(c & 0b10000000)
		idx += 8
	}
	return buffer.bytestr()
}

fn base2lsbf_decode(content string) string {
	if content.len % 8 != 0 {
		exit_error('content length must be a multiple of 8')
	}
	mut idx := 0
	mut buffer := []u8{len: content.len / 8, init: 0}
	for i := 0; i < content.len; i += 8 {
		b7 := if content[i + 0] == `1` { 0b00000001 } else { 0b0 }
		b6 := if content[i + 1] == `1` { 0b00000010 } else { 0b0 }
		b5 := if content[i + 2] == `1` { 0b00000100 } else { 0b0 }
		b4 := if content[i + 3] == `1` { 0b00001000 } else { 0b0 }
		b3 := if content[i + 4] == `1` { 0b00010000 } else { 0b0 }
		b2 := if content[i + 5] == `1` { 0b00100000 } else { 0b0 }
		b1 := if content[i + 6] == `1` { 0b01000000 } else { 0b0 }
		b0 := if content[i + 7] == `1` { 0b10000000 } else { 0b0 }

		buffer[idx] = u8(b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0)
		idx += 1
	}
	return buffer.bytestr()
}

fn emit(val u8) u8 {
	return if val > 0 { `1` } else { `0` }
}

const z85_codes = [`0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `a`, `b`, `c`, `d`, `e`, `f`,
	`g`, `h`, `i`, `j`, `k`, `l`, `m`, `n`, `o`, `p`, `q`, `r`, `s`, `t`, `u`, `v`, `w`, `z`, `y`,
	`z`, `A`, `B`, `C`, `D`, `E`, `F`, `G`, `H`, `I`, `J`, `K`, `L`, `M`, `N`, `O`, `P`, `Q`, `R`,
	`S`, `T`, `U`, `V`, `W`, `X`, `Y`, `Z`, `.`, `-`, `:`, `+`, `=`, `^`, `!`, `/`, `*`, `?`, `&`,
	`<`, `>`, `(`, `)`, `[`, `]`, `{`, `}`, `@`, `%`, `$`, `#`]

fn z85_encode(content []u8) string {
	if content.len % 4 != 0 {
		exit_error('invalid input (length must be multiple of 4 characters)')
	}

	mut start := 0
	mut buf := []u8{len: (content.len / 4) * 5, init: 0}
	for i := 0; i < content.len; i += 4 {
		mut frame := u32(0)
		frame |= u32(content[i + 0]) << 24
		frame |= u32(content[i + 1]) << 16
		frame |= u32(content[i + 2]) << 8
		frame |= u32(content[i + 3])

		// Convert into 5 characters, dividing by 85 and taking the remainder
		mut divisor := u32(52200625) // 85 * 85 * 85 * 85;
		for j := 0; j < 5; j++ {
			divisible := (frame / divisor) % 85
			buf[start + j] = z85_codes[divisible]
			frame -= divisible * divisor
			divisor /= 85
		}
		start += 5
	}

	return buf.bytestr()
}

const base256 = [u8(0x00), 0x44, 0x00, 0x54, 0x53, 0x52, 0x48, 0x00, 0x4B, 0x4C, 0x46, 0x41, 0x00,
	0x3F, 0x3E, 0x45, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x40, 0x00, 0x49,
	0x42, 0x4A, 0x47, 0x51, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
	0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x4D, 0x00,
	0x4E, 0x43, 0x00, 0x00, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15,
	0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x4F, 0x00,
	0x50, 0x00, 0x00]

fn z85_decode(content string) string {
	if content.len % 5 != 0 {
		exit_error('invalid input (length must be multiple of 5 characters)')
	}

	mut buf := []u8{len: (content.len / 5) * 4, init: 0}
	mut idx := 0
	mut val := u32(0)

	for i := 0; i < content.len; i += 5 {
		val = base256[(content[i + 0] - 32) & 127]
		val = val * 85 + base256[(content[i + 1] - 32) & 127]
		val = val * 85 + base256[(content[i + 2] - 32) & 127]
		val = val * 85 + base256[(content[i + 3] - 32) & 127]
		val = val * 85 + base256[(content[i + 4] - 32) & 127]

		buf[idx] = u8(val >> 24)
		val = val << 8 >> 8
		idx += 1

		buf[idx] = u8(val >> 16)
		val = val << 16 >> 16
		idx += 1

		buf[idx] = u8(val >> 8)
		val = val << 24 >> 24
		idx += 1

		buf[idx] = u8(val)
		idx += 1
	}
	return buf.bytestr()
}
