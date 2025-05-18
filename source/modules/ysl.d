module ysli.modules.ysl;

import std.conv;
import std.stdio;
import std.string;
import std.exception;
import ysli.util;
import ysli.environment;

void YslModule(Environment e) {
	e.AddFunc("interpret", FuncCall((string[] args, Environment env) {
		auto line = env.PopCall();
		env.RunLine(line, args[0]);
	}, true));
	e.AddFunc("load_next", FuncCall((string[] args, Environment env) {
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
	e.AddFunc("load_end_rd", FuncCall((string[] args, Environment env) {
		auto old      = env.writeMode;
		env.writeMode = env.readMode;
		loadEnd(args, env);
		env.writeMode = old;
	}));
	e.AddFunc("load_end", FuncCall(loadEnd));
	e.AddFunc("alloc_line", FuncCall((string[] args, Environment env) {
		env.retStack ~= [env.GetWriteMap().entries.head.GetLastEntry().value.key + 10];
	}));
	e.AddFunc("new_func", FuncCall((string[] args, Environment env) {
		Label label = env.GetLine(parse!Value(args[1]));

		if (label is null) {
			stderr.writefln("Error: new_func: Line number does not exist");
			throw new YSLError();
		}

		FuncCall func = FuncCall(label);

		if (args[0] !in env.funcs) {
			env.funcs[args[0]] = [];
		}

		env.funcs[args[0]] ~= Function(null, func.Copy());
	}));
	e.AddFunc("set_at_exit", FuncCall((string[] args, Environment env) {
		if (args[0].isNumeric()) {
			auto line = env.GetLine(parse!Value(args[0]));

			if (line is null) {
				stderr.writefln("Error: set_at_exit: Line number does not exist");
				throw new YSLError();
			}

			env.atExit = new FuncCall(line);
		}
		else {
			if (args[0] !in env.funcs) {
				stderr.writefln("Error: set_at_exit: Function does not exist");
				throw new YSLError();
			}

			env.atExit = env.funcs[args[0]][$ - 1].run;
		}
	}));
}
