module common

#include <locale.h>

fn C.setlocale(category int, locale &char) &char

fn init() {
	C.setlocale(C.LC_ALL, ''.str)
}

// is_utf8 returns whether the locale supports UTF-8 or not
pub fn is_utf8() bool {
	locale := unsafe { C.setlocale(C.LC_CTYPE, &char(0)).vstring().to_lower() }
	return locale.contains_any_substr(['utf8', 'utf-8'])
}
