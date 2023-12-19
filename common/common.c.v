module common

#include <locale.h>

fn C.setlocale(category int, locale &char) &char

// ref: <https://stackoverflow.com/questions/57131654/using-utf-8-encoding-chcp-65001-in-command-prompt-windows-powershell-window>
// ref: <https://stackoverflow.com/questions/388490/how-to-use-unicode-characters-in-windows-command-line>
// ref: <https://stackoverflow.com/questions/64939841/script-to-detect-if-windows-system-locale-is-using-utf-8-code-page>
// ref: <https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/setlocale-wsetlocale> @@ <https://archive.is/43ucb>

fn C.GetACP() u32 // ref: <https://learn.microsoft.com/en-us/windows/win32/api/winnls/nf-winnls-getacp> @@ <https://archive.is/kaMaR>
fn C.GetConsoleOutputCP() u32 // ref: <https://learn.microsoft.com/en-us/windows/console/getconsoleoutputcp> @@ <https://archive.is/wymp0>
fn C.GetOEMCP() u32 // ref: <https://learn.microsoft.com/en-us/windows/win32/api/winnls/nf-winnls-getoemcp> @@ <https://archive.is/Cvtvm>

fn init() {
	C.setlocale(C.LC_ALL, ''.str)
}

// is_utf8 returns whether the locale supports UTF-8 or not
pub fn is_utf8() bool {
	locale := unsafe { C.setlocale(C.LC_CTYPE, &char(0)).vstring().to_lower() }
	return locale.contains_any_substr(['utf8', 'utf-8']) || $if windows {
		C.GetACP() == 65001 || C.GetConsoleOutputCP() == 65001 || C.GetOEMCP() == 65001
	} $else {
		false
	}
}
