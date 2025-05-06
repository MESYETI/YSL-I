module ysli.app;

import std.conv;
import std.stdio;
import std.string;
import std.algorithm;
import ysli.environment;

void main(string[] args) {
	string input;
	size_t i;
	size_t showIteration;

	// interpret
	for (i = 1; i < args.length; ++ i) {
		if (args[i].startsWith("-")) {
			switch (args[i]) {
				case "-i": {
					++ i;

					if ((i == args.length) && (!args[i].isNumeric())) {
						stderr.writefln("-i flag expects integer value");
						return;
					}

					showIteration = parse!size_t(args[i]);
					break;
				}
				default: {
					stderr.writefln("Unknown flag '%s'", args[i]);
					return;
				}
			}
		}
		else {
			input = args[i];
			break;
		}
	}

	if (input == "") {
		stderr.writefln("Error: no input file");
		return;
	}

	auto env = new Environment();
	env.LoadFile(env.current, input);

	i = 0;
	while (true) {
		env.Run();
		auto written = env.written;
		env.NextIteration();
		++ i;

		if ((showIteration != 0) && (showIteration == i)) {
			auto ip = env.current.entries.head;

			while (ip !is null) {
				writefln("%.10d: %s", ip.value.key, ip.value.value);
				ip = ip.next;
			}
			return;
		}
		if (!written) {
			return;
		}
	}
}
