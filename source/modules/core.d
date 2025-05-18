module ysli.modules.core;

import std.conv;
import std.math;
import std.stdio;
import std.string;
import std.algorithm;
import core.stdc.stdlib : exit;
import ysli.util;
import ysli.environment;

void CoreModule(Environment e) {
	e.AddFunc("print", FuncCall((string[] args, Environment env) {
		foreach (i, ref arg ; args) {
			writef("%s%s", arg, i == args.length - 1? "" : " ");
		}
	}));
	e.AddFunc("print_ln", FuncCall((string[] args, Environment env) {
		foreach (i, ref arg ; args) {
			writef("%s%s", arg, i == args.length - 1? "" : " ");
		}

		writeln();
	}));
	e.AddFunc("read_ln", FuncCall((string[] args, Environment env) {
		env.retStack ~= readln()[0 .. $ - 1].StringToIntArray();
	}));
	e.AddFunc("goto", FuncCall((string[] args, Environment env) {
		auto line = parse!Value(args[0]);
		if (env.Jump(line)) return;

		stderr.writefln("Error: goto: Couldn't find line %d", line);
		throw new YSLError();
	}));
	e.AddFunc("goto_inc", FuncCall((string[] args, Environment env) {
		auto line = parse!Value(args[0]);
		if (env.Jump(line)) {
			env.increment = true;
			return;
		}

		stderr.writefln("Error: goto_inc: Couldn't find line %d", line);
		throw new YSLError();
	}));
	e.AddFunc("goto_if", FuncCall((string[] args, Environment env) {
		auto line = parse!Value(args[0]);

		if (env.PopReturn()[0] == 0) {
			return;
		}
		else {
			if (env.Jump(line)) return;

			stderr.writefln("Error: goto: Couldn't find line %d", line);
			throw new YSLError();
		}
	}));
	e.AddFunc("done", FuncCall((string[] args, Environment env) {
		throw new YSLDone();
	}));
	e.AddFunc("cmp", FuncCall((string[] args, Environment env) {
		auto a = args[0];
		auto b = args[1];

		env.retStack ~= [a == b? 1 : 0];
	}));
	e.AddFunc("lt", FuncCall((string[] args, Environment env) {
		auto a = parse!Value(args[0]);
		auto b = parse!Value(args[1]);

		env.retStack ~= [a < b? 1 : 0];
	}));
	e.AddFunc("gt", FuncCall((string[] args, Environment env) {
		auto a = parse!Value(args[0]);
		auto b = parse!Value(args[1]);

		env.retStack ~= [a > b? 1 : 0];
	}));
	e.AddHybridFunc("import_g", FuncCall((string[] args, Environment env) {
		if (args[0] !in env.modules) {
			throw new YSLError(format("Module '%s' doesn't exist", args[0]));
		}

		env.modules[args[0]](env);
	}));
	e.AddHybridFunc("import", FuncCall((string[] args, Environment env) {
		if (args[0] !in env.modules) {
			throw new YSLError(format("Module '%s' doesn't exist", args[0]));
		}

		env.SetNamespace(args[0]);
		env.modules[args[0]](env);
		env.useNamespace = false;
	}));
	e.AddFunc("exit", FuncCall((string[] args, Environment env) {
		exit(0);
	}));
	e.AddFunc("var", FuncCall((string[] args, Environment env) {
		if (args.length < 2) {
			stderr.writefln("Error: var: Requires 2 arguments: variable name and operator");
			throw new YSLError();
		}

		string var = args[0];

		if (var == "return") {
			stderr.writefln("Error: var: Using disallowed variable name 'return'");
			throw new YSLError();
		}

		switch (args[1]) {
			case "=": {
				if (args.length == 2) {
					env.CreateVariable(var, []);
				}
				else if (args[2].isNumeric()) {
					int[] array;
					
					for (int i = 2; i < args.length; ++ i) {
						array ~= parse!int(args[i]);
					}

					env.CreateVariable(var, array);
				}
				else {
					env.CreateVariable(var, args[2].StringToIntArray());
				}
				break;
			}
			case "+":
			case "+=":
			case "-":
			case "-=":
			case "*":
			case "*=":
			case "/":
			case "/=":
			case "%":
			case "%=":
			case "^":
			case "^=": {
				if (!args[2].isNumeric()) {
					stderr.writefln("Error: var: %s required numerical parameter", args[1]);
					throw new YSLError();
				}
				if (!env.VariableExists(args[0])) {
					stderr.writefln("Error: var: No such variable: '%s'", args[0]);
					throw new YSLError();
				}

				int operand = parse!int(args[2]);
				switch (args[1]) {
					case "+":
					case "+=": (*env.GetVariable(args[0]))[0] += operand; break;
					case "-":
					case "-=": (*env.GetVariable(args[0]))[0] -= operand; break;
					case "*":
					case "*=": (*env.GetVariable(args[0]))[0] *= operand; break;
					case "/":
					case "/=": (*env.GetVariable(args[0]))[0] /= operand; break;
					case "%":
					case "%=": (*env.GetVariable(args[0]))[0] %= operand; break;
					case "^":
					case "^=": {
						int* value = &((*env.GetVariable(args[0]))[0]);

						*value = pow(*value, operand);
						break;
					}
					default:   assert(0);
				}
				break;
			}
			case "c":
			case "copy":
			case "f":
			case "from": {
				bool copyFull = false;

				if ((args[1] == "c") || (args[1] == "copy")) {
					copyFull = true;
				}
			
				if (args.length < 3) {
					stderr.writeln("Error: var: from operator needs 3 arguments");
					throw new YSLError();
				}

				size_t index;

				if ((args[1] == "f") || (args[1] == "from")) {
					index = args.length == 4? parse!size_t(args[3]) : 0;
				}

				if (
					(args[2] != "return") && (args[2] != "call") &&
					!env.VariableExists(args[2])
				) {
					stderr.writefln("Error: var: No such variable: '%s'", args[0]);
					throw new YSLError();
				}

				int[] value;

				if (args[2] == "return") {
					if (env.retStack.empty()) {
						stderr.writefln("Error: var: Return stack empty");
						throw new YSLError();
					}

					if (copyFull) {
						value = env.PopReturn();
					}
					else {
						value = [env.PopReturn()[index]];
					}
				}
				else if (args[2] == "call") {
					value = [env.PopCall()];
				}
				else {
					if (copyFull) {
						value = *env.GetVariable(args[2]);
					}
					else {
						value = [(*env.GetVariable(args[2]))[index]];
					}
				}

				env.CreateVariable(args[0], value);
				break;
			}
			case "p":
			case "pass": {
				if (env.passStack.empty()) {
					stderr.writefln("Error: var: Pass stack empty");
					throw new YSLError();
				}

				env.CreateVariable(args[0], env.PopPass());
				break;
			}
			case "a":
			case "append": {
				if (!args[2].isNumeric()) {
					stderr.writefln("Error: var: %s required numerical parameter", args[1]);
					throw new YSLError();
				}
			
				(*env.GetVariable(args[0])) ~= parse!int(args[2]);
				break;
			}
			case "r":
			case "remove": {
				if (args.length != 4) {
					stderr.writefln("Error: var: %s requires 2 additional parameters", args[1]);
					throw new YSLError();
				}
				if (!args[2].isNumeric() || !args[3].isNumeric()) {
					stderr.writefln("Error: var: %s required numerical parameters", args[1]);
					throw new YSLError();
				}
				if (!env.VariableExists(args[0])) {
					stderr.writefln("Error: var: No such variable: %s", args[0]);
					throw new YSLError();
				}

				size_t    index  = parse!size_t(args[2]);
				size_t    length = parse!size_t(args[3]);
				Variable* varPtr = env.GetVariable(args[0]);

				foreach (i ; 0 .. length) {
					*varPtr = (*varPtr).remove(index);
				}
				break;
			}
			case "s":
			case "set": {
				if (args.length != 4) {
					stderr.writefln("Error: var: %s requires 2 additional parameters", args[1]);
					throw new YSLError();
				}
				if (!args[2].isNumeric() || !args[3].isNumeric()) {
					stderr.writefln("Error: var: %s required numerical parameters", args[1]);
					throw new YSLError();
				}
				if (!env.VariableExists(args[0])) {
					stderr.writefln("Error: var: No such variable: %s", args[0]);
					throw new YSLError();
				}

				size_t    index  = parse!size_t(args[2]);
				Variable* varPtr = env.GetVariable(args[0]);

				if (index >= (*varPtr).length) {
					stderr.writefln(
						"Error: var: %d is too big for array of size %d", index,
						(*varPtr).length
					);
					throw new YSLError();
				}

				(*varPtr)[index] = parse!int(args[3]);
				break;
			}
			case "j":
			case "join": {
				if (!env.VariableExists(args[0])) {
					stderr.writefln("Error: var: No such variable: %s", args[0]);
					throw new YSLError();
				}

				Variable* varPtr  = env.GetVariable(args[0]);
				(*varPtr)        ~= StringToIntArray(args[2]);
				break;
			}
			default: {
				stderr.writefln("Error: var: Unknown operator %s", args[1]);
				throw new YSLError();
			}
		}
	}));
}
