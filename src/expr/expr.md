# expr

## differences between GNU and V versions

The main difference is that V's regex is not the same as the
regex used by expr, so some patterns will not work as expected.

This is unlikely to change until a regex module is created that
is compatible with the regex used by expr.
