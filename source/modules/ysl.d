module ysli.modules.ysl;

import std.conv;
import std.stdio;
import std.string;
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
	e.AddFunc("new_func", Function((string[] args, Environment env) {
		Label label = env.GetLine(parse!Value(args[1]));

		if (label is null) {
			stderr.writefln("Error: new_func: Line number does not exist");
			throw new YSLError();
		}

		Function func = Function(label);

		if (args[0] !in env.funcs) {
			env.funcs[args[0]] = [];
		}

		env.funcs[args[0]] ~= func;
	}));
	e.AddFunc("copy_to_set", Function((string[] args, Environment env) {
		if (args[0] !in env.funcs) {
			stderr.writefln("Error: copy_to_set: Function '%s' doesn't exist", args[0]);
			throw new YSLError();
		}
		if (args[2] !in env.sets) {
			env.sets[args[2]] = new Function[][string];
		}
		if (env.sets[args[2]][args[1]].empty()) {
			env.sets[args[2]][args[1]] = [] ;
		}

		env.sets[args[2]][args[1]] ~= env.funcs[args[0]];
	}));
	e.AddFunc("set_at_exit", Function((string[] args, Environment env) {
		if (args[0].isNumeric()) {
			auto line = env.GetLine(parse!Value(args[0]));

			if (line is null) {
				stderr.writefln("Error: set_at_exit: Line number does not exist");
				throw new YSLError();
			}

			env.atExit = new Function(line);
		}
		else {
			if (args[0] !in env.funcs) {
				stderr.writefln("Error: set_at_exit: Function does not exist");
				throw new YSLError();
			}

			env.atExit = &env.funcs[args[0]][$ - 1];
		}
	}));
	e.AddFunc("map_empty?", Function((string[] args, Environment env) {
		env.retStack ~= [env.GetWriteMap().entries.head is null? 1 : 0];
	}));
	e.AddFunc("map_end", Function((string[] args, Environment env) {
		auto map = env.GetWriteMap();

		if (map.entries is null) {
			stderr.writefln("Error: map_end: Map is empty");
			throw new YSLError();
		}

		env.retStack ~= [map.entries.head.GetLastEntry().value.key];
	}));
	e.AddFunc("pop", Function((string[] args, Environment env) {
		switch (args[0]) {
			case "pass":   env.PopPass();   break;
			case "call":   env.PopCall();   break;
			case "return": env.PopReturn(); break;
			default: {
				stderr.writefln("ysl.pop: Stack '%s' doesn't exist", args[0]);
				throw new YSLError();
			}
		}
	}));
	e.AddFunc("goto_set", Function((string[] args, Environment env) {
		auto line = parse!Value(args[0]);
		if (env.Jump(line)) {
			if (args[1] !in env.sets) {
				stderr.writefln("Error: goto_comp: Set '%s' doesn't exist", args[1]);
				throw new YSLError();
			}
			env.SwitchSet(args[1]);
			return;
		};

		stderr.writefln("Error: goto_comp: Couldn't find line %d", line);
		throw new YSLError();
	}));
	e.AddFunc("goto_inc_set", Function((string[] args, Environment env) {
		auto line = parse!Value(args[0]);
		if (env.Jump(line)) {
			env.increment = true;
			if (args[1] !in env.sets) {
				stderr.writefln("Error: goto_comp: Set '%s' doesn't exist", args[1]);
				throw new YSLError();
			}
			env.SwitchSet(args[1]);
			return;
		}

		stderr.writefln("Error: goto_inc_comp: Couldn't find line %d", line);
		throw new YSLError();
	}));
}
