module main

import os
import rand
import common

// A port of GNU coreutils' randint/randperm (gl/lib/randint.c and
// gl/lib/randperm.c).
//
// This has to consume the --random-source bytes in exactly the same order and
// quantity as GNU does, otherwise the same file produces a different
// permutation. The algorithm below is a direct translation, including the way
// leftover entropy is carried across calls, because that carry is observable:
// shuf -i 1-5 over a one byte source still consumes a single byte, and only
// because randnum/randmax keep the unused bits.
struct RandintSource {
mut:
	// randnum is a buffered random integer, uniformly distributed over
	// 0..=randmax. If randmax is 0 then randnum must be 0.
	randnum u64
	randmax u64
	// The --random-source file, or none to draw from the system PRNG.
	source      ?os.File
	source_name string
}

fn new_randint_source(source_name string) &RandintSource {
	mut s := &RandintSource{}
	if source_name.len > 0 {
		s.source = os.open(source_name) or {
			common.exit_with_error_message(app_name,
				'${source_name}: ${posix_msg()}')
		}
		s.source_name = source_name
	}
	return s
}

// fill puts buf.len random bytes into buf.
fn (mut s RandintSource) fill(mut buf []u8) {
	if mut f := s.source {
		// GNU reads exactly the requested number of bytes and reports end of
		// file once the source runs dry.
		n := f.read(mut buf) or {
			if err == os.Eof{} {
				common.exit_with_error_message(app_name,
					'‘${s.source_name}’: end of file')
			}
			common.exit_with_error_message(app_name, '‘${s.source_name}’: read error')
		}
		if n < buf.len {
			common.exit_with_error_message(app_name, '‘${s.source_name}’: end of file')
		}
	} else {
		rand.read(mut buf)
	}
}

// genmax consumes random bytes to produce a value uniformly distributed over
// 0..=limit. This is randint_genmax() in GNU's randint.c.
fn (mut s RandintSource) genmax(limit u64) u64 {
	mut randnum := s.randnum
	mut randmax := s.randmax
	choices := limit + 1
	for {
		if randmax < limit {
			// Work out how many bytes are needed to cover the new limit.
			mut count := 0
			mut rmax := randmax
			for {
				rmax = (rmax << 8) + 255
				count++
				if !(rmax < limit) {
					break
				}
			}
			mut buf := []u8{len: count}
			s.fill(mut buf)

			// Append the bytes to randnum, and 255 to randmax, until randmax
			// covers the limit. Up to 8 bits of information are dropped here,
			// which GNU accepts as not worth the extra bookkeeping.
			count = 0
			for {
				randnum = (randnum << 8) + u64(buf[count])
				randmax = (randmax << 8) + 255
				count++
				if !(randmax < limit) {
					break
				}
			}
		}

		if randmax == limit {
			s.randnum = 0
			s.randmax = 0
			return randnum
		}

		// limit < randmax, so randnum % choices is only fair while randnum
		// stays inside an integral multiple of choices. Outside that range the
		// attempt is discarded, but the partial randomness is kept so no byte
		// is thrown away for nothing.
		excess_choices := randmax - limit
		unusable_choices := excess_choices % choices
		last_usable_choice := randmax - unusable_choices
		reduced_randnum := randnum % choices
		if randnum <= last_usable_choice {
			s.randnum = randnum / choices
			s.randmax = excess_choices / choices
			return reduced_randnum
		}
		randnum = reduced_randnum
		randmax = unusable_choices - 1
	}
	panic('unreachable')
}

// choose returns a value uniformly distributed over 0..=n-1, matching GNU's
// randint_choose(), which is genmax(n - 1).
fn (mut s RandintSource) choose(n u64) u64 {
	return s.genmax(n - 1)
}

// randperm_new returns the first h elements of a random permutation of
// 0..=n-1, matching GNU's randperm_new().
//
// GNU switches to a hash based "sparse" representation for large, sparse
// permutations. That is purely a memory optimisation: it performs the same
// swaps in the same order, so the permutation is identical and is not needed
// here.
fn randperm_new(mut s RandintSource, h int, n int) []u64 {
	if h == 0 {
		return []u64{}
	}
	if h == 1 {
		return [s.choose(u64(n))]
	}
	mut v := []u64{len: n, init: 0}
	for i in 0 .. n {
		v[i] = u64(i)
	}
	for i in 0 .. h {
		j := i + int(s.choose(u64(n - i)))
		v[i], v[j] = v[j], v[i]
	}
	return v[..h]
}
