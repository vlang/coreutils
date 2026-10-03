fn C.GetComputerNameExW(nameType int, buffer &u16, size &u32) bool

// ComputerNameDnsHostname, the one name type that carries the registered case.
const dns_hostname = 1

// win_nodename is the computer name with the case it is registered under.
//
// os.uname() reads the nodename from COMPUTERNAME, and Windows keeps that variable
// uppercased, so it answers MRLAPTOP for a machine called MRLaptop. Measured on
// this machine:
//
//	os.uname().nodename                MRLAPTOP
//	C.GetComputerNameW                 MRLAPTOP
//	C.GetComputerNameExW(DnsHostname)  MRLaptop	<- what GNU 8.32 and uutils print
//	PowerShell's own hostname           MRLaptop
//
// So it takes GetComputerNameEx with the DNS hostname type, which is the call that
// has the registered name.
//
// The buffer is read back by hand rather than through string_from_wide2, whose
// arity this compiler's builtin and this compiler's own vlib/os disagree about.
// A computer name is letters, digits and hyphens, so a code unit above 0x7f means
// this is not one, and the caller's own answer is kept rather than mangled.
fn win_nodename(fallback string) string {
	mut buf := []u16{len: 256}
	mut size := u32(256)
	if !unsafe { C.GetComputerNameExW(dns_hostname, &u16(&buf[0]), &size) } {
		return fallback
	}
	return wide_ascii(buf, int(size)) or { fallback }
}

// wide_ascii turns a UTF-16 buffer into a string, or none if it holds anything an
// ASCII conversion would change.
fn wide_ascii(buf []u16, len int) ?string {
	mut bytes := []u8{cap: len}
	for i in 0 .. len {
		c := buf[i]
		if c == 0 {
			break
		}
		if c > 0x7f {
			return none
		}
		bytes << u8(c)
	}
	return bytes.bytestr()
}
