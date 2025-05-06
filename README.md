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

# Build
Install D from <https://dlang.org/download> (I do not advise using package manager
repositories to install D, unless you use a rolling release linux distro like Arch
Linux)
```
dub build
```
