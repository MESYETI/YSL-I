# YSL-I
Iterative YSL. So far, there have only been self-modifying YSLs (if you don't count
YSL-C). These YSLs allow programs to modify their own source code. This is cool because
it allows you to append new code to the end of the code map, pretty much allowing you
to extend the language, as you can use this while reading lines of code
to parse what comes after certain statements.

Iterative YSL goes all in on this idea of extendability. Instead of allowing programs
to self-modify, writes to the code map will instead write to a blank code map that is
created every "iteration". This is the "next" code map. After the program is complete,
the interpreter will throw away the "current" code map and switch to the "next" map.
A new "next" map is generated, and the cycle repeats.

## Example
`examples/iterativeCountTo10.ysl`

```
var line = 10
var i = 1
loop:
	$line print_ln $i
	var line += 10
	var i += 1
	lt $line 101
	goto_if *loop
```

This program generates a series of `print_ln` statements that print a number. You can
see the generated program with `ysli -i 1 examples/iterativeCountTo10.ysl`:

```
0000000010: print_ln 1
0000000020: print_ln 2
0000000030: print_ln 3
0000000040: print_ln 4
0000000050: print_ln 5
0000000060: print_ln 6
0000000070: print_ln 7
0000000080: print_ln 8
0000000090: print_ln 9
0000000100: print_ln 10
```

You can then run the program normally by removing the `-i 1` flag.

# Build
Install D from <https://dlang.org/download> (I do not advise using package manager
repositories to install D, unless you use a rolling release linux distro like Arch
Linux)
```
dub build
```
