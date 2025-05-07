module ysli.modules.ysl;

import std.stdio;
import std.exception;
import ysli.util;
import ysli.environment;

void YslModule(Environment e) {
	e.AddFunc("interpret", Function((string[] args, Environment env) {
		auto line = env.PopCall();
		env.RunLine(line, args[0]);
	}, true));
	e.AddFunc("load_next", Function((string[] args, Environment env) {
		env.next    = new CodeMap();
		env.written = true;
		env.LoadFile(env.next, args[0]);
	}));
	static auto loadEnd = (string[] args, Environment env) {
		int lineNum = 10;

		auto code = env.GetWriteMap();

		if (code.entries.head !is null) {
			lineNum = code.entries.head.GetLastEntry().value.key + 10;
		}

		File file;

		try {
			file = File(args[0], "r");
		}
		catch (ErrnoException) {
			stderr.writefln("Error: load_end: No such file '%s'", args[0]);
			throw new YSLError();
		}

		string line;
		while ((line = file.readln()) !is null) {
			code[lineNum]  = line[0 .. $ - 1];
			lineNum       += 10;
		}
	};
	e.AddFunc("load_end_rd", Function((string[] args, Environment env) {
		auto old      = env.writeMode;
		env.writeMode = env.readMode;
		loadEnd(args, env);
		env.writeMode = old;
	}));
	e.AddFunc("load_end", Function(loadEnd));
	e.AddFunc("alloc_line", Function((string[] args, Environment env) {
		env.retStack ~= [env.GetWriteMap().entries.head.GetLastEntry().value.key + 10];
	}));
}
