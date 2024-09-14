module main

fn test_encode_base64() {
	options := Options{
		base64: true
	}
	assert encode([]u8{}, options) == ''
	assert encode('f'.bytes(), options) == 'Zg=='
	assert encode('fo'.bytes(), options) == 'Zm8='
	assert encode('foo'.bytes(), options) == 'Zm9v'
	assert encode('foob'.bytes(), options) == 'Zm9vYg=='
	assert encode('fooba'.bytes(), options) == 'Zm9vYmE='
	assert encode('foobar'.bytes(), options) == 'Zm9vYmFy'
}

fn test_decode_base64() {
	options := Options{
		base64: true
		decode: true
	}
	assert decode('Zm9vYmFy', options) == 'foobar'
	assert decode('Zm9vYmE=', options) == 'fooba'
	assert decode('ViBpbiBiYXNlIDY0', options) == 'V in base 64'
}

// ------------

fn test_encode_base64url() {
	options := Options{
		base64url: true
	}
	assert encode([]u8{}, options) == ''
	assert encode('f'.bytes(), options) == 'Zg'
	assert encode('fo'.bytes(), options) == 'Zm8'
	assert encode('foo'.bytes(), options) == 'Zm9v'
	assert encode('foob'.bytes(), options) == 'Zm9vYg'
	assert encode('fooba'.bytes(), options) == 'Zm9vYmE'
	assert encode('foobar'.bytes(), options) == 'Zm9vYmFy'
}

fn test_decode_base64url() {
	options := Options{
		base64url: true
		decode:    true
	}
	assert decode('Zg', options) == 'f'
	assert decode('Zm8', options) == 'fo'
	assert decode('Zm9v', options) == 'foo'
	assert decode('Zm9vYg', options) == 'foob'
	assert decode('Zm9vYmE', options) == 'fooba'
	assert decode('Zm9vYmFy', options) == 'foobar'
}

// ------------

fn test_encode_base32() {
	options := Options{
		base32: true
	}
	assert encode([]u8{}, options) == ''
	assert encode('f'.bytes(), options) == 'MY======'
	assert encode('fo'.bytes(), options) == 'MZXQ===='
	assert encode('foo'.bytes(), options) == 'MZXW6==='
	assert encode('foob'.bytes(), options) == 'MZXW6YQ='
	assert encode('fooba'.bytes(), options) == 'MZXW6YTB'
	assert encode('foobar'.bytes(), options) == 'MZXW6YTBOI======'
}

fn test_decode_base32() {
	options := Options{
		base32: true
		decode: true
	}
	assert decode('MY======', options) == 'f'
	assert decode('MZXQ====', options) == 'fo'
	assert decode('MZXW6===', options) == 'foo'
	assert decode('MZXW6YQ=', options) == 'foob'
	assert decode('MZXW6YTB', options) == 'fooba'
	assert decode('MZXW6YTBOI======', options) == 'foobar'
}

// ------------

fn test_encode_base32hex() {
	options := Options{
		base32hex: true
	}
	assert encode([]u8{}, options) == ''
	assert encode('f'.bytes(), options) == 'CO======'
	assert encode('fo'.bytes(), options) == 'CPNG===='
	assert encode('foo'.bytes(), options) == 'CPNMU==='
	assert encode('foob'.bytes(), options) == 'CPNMUOG='
	assert encode('fooba'.bytes(), options) == 'CPNMUOJ1'
	assert encode('foobar'.bytes(), options) == 'CPNMUOJ1E8======'
}

fn test_decode_base32hex() {
	options := Options{
		base32hex: true
		decode:    true
	}
	assert decode('CO======', options) == 'f'
	assert decode('CPNG====', options) == 'fo'
	assert decode('CPNMU===', options) == 'foo'
	assert decode('CPNMUOG=', options) == 'foob'
	assert decode('CPNMUOJ1', options) == 'fooba'
	assert decode('CPNMUOJ1E8======', options) == 'foobar'
}

// ------------

fn test_encode_base16() {
	options := Options{
		base16: true
	}
	assert encode([]u8{}, options) == ''
	assert encode('f'.bytes(), options) == '66'
	assert encode('fo'.bytes(), options) == '666F'
	assert encode('foo'.bytes(), options) == '666F6F'
	assert encode('foob'.bytes(), options) == '666F6F62'
	assert encode('fooba'.bytes(), options) == '666F6F6261'
	assert encode('foobar'.bytes(), options) == '666F6F626172'
}

fn test_decode_base16() {
	options := Options{
		base16: true
	}
	assert decode('66', options) == 'f'
	assert decode('666F', options) == 'fo'
	assert decode('666F6F', options) == 'foo'
	assert decode('666F6F62', options) == 'foob'
	assert decode('666F6F6261', options) == 'fooba'
	assert decode('666F6F626172', options) == 'foobar'
}

// ------------

fn test_encode_base2lbsf() {
	options := Options{
		base2lsbf: true
	}
	assert encode('foobar'.bytes(), options) == '011001101111011011110110010001101000011001001110'
}

fn test_dncode_base2lbsf() {
	options := Options{
		base2lsbf: true
		decode:    true
	}
	assert decode('011001101111011011110110010001101000011001001110', options) == 'foobar'
}

// ------------

fn test_encode_base2mbsf() {
	options := Options{
		base2msbf: true
	}
	assert encode('foobar'.bytes(), options) == '011001100110111101101111011000100110000101110010'
}

fn test_decode_base2mbsf() {
	options := Options{
		base2msbf: true
		decode:    true
	}
	assert decode('011001100110111101101111011000100110000101110010', options) == 'foobar'
}

// ------------

fn test_encode_z85() {
	options := Options{
		z85: true
	}
	// from the specification (https://rfc.zeromq.org/spec/32/)
	assert encode([u8(0x86), 0x4F, 0xD2, 0x6F, 0xB5, 0x59, 0xF7, 0x5B], options) == 'HelloWorld'
}

fn test_decode_z85() {
	options := Options{
		z85:    true
		decode: true
	}
	assert decode('HelloWorld', options).bytes() == [u8(0x86), 0x4F, 0xD2, 0x6F, 0xB5, 0x59, 0xF7,
		0x5B]
}
