import common.dd as ddmod
import os

fn main() {
	set := ddmod.parse_args(os.args[1..])
	report, code := ddmod.run(set)
	if code == 0 {
		print_summary(report, set)
	}
	exit(code)
}

// print_summary writes the three lines GNU writes on completion, or the two
// that omit the byte total under status=noxfer, or nothing at all under
// status=none. The elapsed time and rate are not printed because they are not
// reproducible.
fn print_summary(report ddmod.Report, set ddmod.Settings) {
	if set.status == .none {
		return
	}
	if set.status == .noxfer {
		eprintln('${report.records_in}+${report.partial_in} records in')
		eprintln('${report.records_out}+${report.partial_out} records out')
		return
	}
	eprintln('${report.records_in}+${report.partial_in} records in')
	eprintln('${report.records_out}+${report.partial_out} records out')
	eprintln('${report.bytes} bytes copied')
}
