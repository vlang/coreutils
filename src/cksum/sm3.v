module main

// SM3, the Chinese national cryptographic hash (GB/T 32905-2016). GNU's cksum
// accepts `-a sm3`, and V's standard library has no SM3, so it is implemented
// here. Verified against GNU cksum's output.

const sm3_iv = [u32(0x7380166f), 0x4914b2b9, 0x172442d7, 0xda8a0600, 0xa96f30bc, 0x163138aa,
	0xe38dee4d, 0xb0fb0e4e]

fn sm3_rotl(x u32, n u32) u32 {
	return (x << n) | (x >> (32 - n))
}

fn sm3_p0(x u32) u32 {
	return x ^ sm3_rotl(x, 9) ^ sm3_rotl(x, 17)
}

fn sm3_p1(x u32) u32 {
	return x ^ sm3_rotl(x, 15) ^ sm3_rotl(x, 23)
}

fn sm3_ff(j int, x u32, y u32, z u32) u32 {
	return if j < 16 { x ^ y ^ z } else { (x & y) | (x & z) | (y & z) }
}

fn sm3_gg(j int, x u32, y u32, z u32) u32 {
	return if j < 16 { x ^ y ^ z } else { (x & y) | (~x & z) }
}

fn sm3_compress(mut v []u32, block []u8) {
	// w holds 68 words, of which only 0..15 and 64..67 are used directly; the
	// rest is the expanded message schedule.
	mut w := []u32{len: 68}
	for j in 0 .. 16 {
		w[j] = be_u32(block, j * 4)
	}
	for j in 16 .. 68 {
		w[j] = sm3_p1(w[j - 16] ^ w[j - 9] ^ sm3_rotl(w[j - 3], 15)) ^ sm3_rotl(w[j - 13], 7) ^
			w[j - 6]
	}

	mut a := v[0]
	mut b := v[1]
	mut c := v[2]
	mut d := v[3]
	mut e := v[4]
	mut f := v[5]
	mut g := v[6]
	mut h := v[7]

	for j in 0 .. 64 {
		t := if j < 16 { u32(0x79cc4519) } else { u32(0x7a879d8a) }
		a12 := sm3_rotl(a, 12)
		ss1 := sm3_rotl(a12 + e + sm3_rotl(t, u32(j) % 32), 7)
		ss2 := ss1 ^ a12
		// TT1 takes the expanded word W'[j] = W[j] ^ W[j+4]; TT2 takes W[j].
		tt1 := sm3_ff(j, a, b, c) + d + ss2 + (w[j] ^ w[j + 4])
		tt2 := sm3_gg(j, e, f, g) + h + ss1 + w[j]
		d = c
		c = sm3_rotl(b, 9)
		b = a
		a = tt1
		h = g
		g = sm3_rotl(f, 19)
		f = e
		e = sm3_p0(tt2)
	}

	v[0] ^= a
	v[1] ^= b
	v[2] ^= c
	v[3] ^= d
	v[4] ^= e
	v[5] ^= f
	v[6] ^= g
	v[7] ^= h
}

fn sm3_sum(data []u8) []u8 {
	// Pad the same way SHA-256 does: 0x80, zeroes up to 56 bytes mod 64, then
	// the message length in bits as a big endian u64.
	mut msg := data.clone()
	msg << 0x80
	for msg.len % 64 != 56 {
		msg << 0
	}
	bits := u64(data.len) * 8
	for i in 0 .. 8 {
		msg << u8(bits >> u32(56 - 8 * i))
	}

	mut v := sm3_iv.clone()
	for i in 0 .. msg.len / 64 {
		sm3_compress(mut v, msg[i * 64..i * 64 + 64])
	}

	mut res := []u8{len: 32}
	for i in 0 .. 8 {
		res[i * 4] = u8(v[i] >> 24)
		res[i * 4 + 1] = u8(v[i] >> 16)
		res[i * 4 + 2] = u8(v[i] >> 8)
		res[i * 4 + 3] = u8(v[i])
	}
	return res
}
