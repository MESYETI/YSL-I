module ysli.environment;

import std.conv;
import std.stdio;
import std.string;
import std.algorithm;
import core.stdc.stdlib : exit;
import ysli.list;
import ysli.util;
import ysli.split;
import ysli.sortedMap;

alias Value    = int;
alias CodeMap  = SortedMap!(Value, string);
alias Label    = ListNode!(MapEntry!(Value, string));
alias Variable = Value[];
alias Module   = void function(Environment e);

enum FunctionType {
	BuiltIn,
	Ysl
}

alias BuiltInFunc = void function(string[] args, Environment e);

struct Function {
	FunctionType type;
	bool         giveIP;

	union {
		BuiltInFunc func;
		Label       label;
	}

	this(BuiltInFunc pfunc, bool pgiveIP = false) {
		type   = FunctionType.BuiltIn;
		func   = pfunc;
		giveIP = pgiveIP;
	}

	this(Label plabel) {
		type  = FunctionType.Ysl;
		label = plabel;
	}
}

class YSLError : Exception {
	this(string msg = "", string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class Environment {
	bool               written;
	CodeMap            current;
	CodeMap            next;
	Label              ip;
	Function[]         substitutors;
	Function           splitter;
	Variable[]         passStack;
	Value[]            callStack;
	Variable[]         retStack;
	Function[][string] funcs;
	Variable[string]   globals;
	Variable[string][] locals;
	bool               increment;
	Module[string]     modules;
	size_t             iteration;

	this() {
		current       = new SortedMap!(int, string);
		next          = new SortedMap!(int, string);
		Reset();
	}

	void Reset() {
		written       = false;
		substitutors ~= Function(&Substitutor, true);
		splitter      = Function(&Split, true);
		passStack     = [];
		callStack     = [];
		retStack      = [];
		funcs         = new Function[][string];
		globals       = new Variable[string];
		locals        = [];
		increment     = true;
		modules       = new Module[string];

		import ysli.modules.core;
		modules["core"] = &CoreModule;

		// load core module
		modules["core"](this);
	}

	// built in stuff
	static private void Substitutor(string[] params, Environment e) {
		Value line = e.PopCall();
		auto  str  = params[0];

		if (str.length == 0) {
			e.retStack ~= [0];
		}

		string subChars = "|!$*";

		if (!subChars.canFind(str[0])) {
			e.retStack ~= [0];
			return;
		}

		string operand = str[1 .. $];
		string newOp = e.Substitute(line, operand);
		while (newOp != operand) {
			operand = newOp;
			newOp   = e.Substitute(line, operand);
		}

		switch (str[0]) {
			case '|': {

				if (!operand.isNumeric()) {
					stderr.writefln("%d: | substitutor requires numeric value", line);
					throw new YSLError();
				}

				Value getLine = parse!Value(operand);

				if (getLine !in e.current) {
					stderr.writefln("%d: line %d does not exist", line, getLine);
					throw new YSLError();
				}

				e.retStack ~= StringToIntArray(e.current[getLine]);
				e.retStack ~= [1];
				break;
			}
			case '!': {
				if (!e.VariableExists(operand)) {
					stderr.writefln(
						"Error: line %d: Unknown variable %s", line, operand
					);
					throw new YSLError();
				}

				e.retStack ~= *e.GetVariable(operand);
				e.retStack ~= [1];
				break;
			}
			case '$': {
				if (!e.VariableExists(operand)) {
					stderr.writefln(
						"Error: line %d: Unknown variable %s", line, operand
					);
					throw new YSLError();
				}

				e.retStack ~= text((*e.GetVariable(operand))[0]).StringToIntArray();
				e.retStack ~= [1];
				break;
			}
			case '*': {
				Label start = e.current.entries.head;

				if (start is null) {
					goto errorNoLabel;
				}

				if (operand[0] == '.') {
					auto it2 = start;

					while (it2.previous !is null) {
						it2 = it2.previous;

						if (
							(it2.value.value.length > 0) &&
							(it2.value.value[$ - 1] == ':') &&
							(it2.value.value[0] != '.')
						) {
							break;
						}
					}

					start = it2;
				}
				
				for (auto it = start; it !is null; it = it.next) {
					if (it.value.value.strip().empty()) {
						continue;
					}
					
					if (it.value.value.strip()[$ - 1] == ':') {
						string thisLabel = it.value.value.strip()[0 .. $ - 1];

						if (thisLabel == operand) {
							e.retStack ~= text(it.value.key).StringToIntArray();
							e.retStack ~= [1];
							return;
						}
					}
				}

				errorNoLabel:
				stderr.writefln(
					"Error: line %d: Couldn't find label '%s'", line, operand
				);
				throw new YSLError();
			}
			default: {
				assert(0);
			}
		}
	}

	Variable PopPass() {
		if (passStack.length == 0) {
			throw new YSLError("Pass stack: stack underflow");
		}

		auto ret = passStack[$ - 1];
		passStack = passStack[0 .. $ - 1];
		return ret;
	}

	Value PopCall() {
		if (callStack.length == 0) {
			throw new YSLError("Call stack: stack underflow");
		}

		auto ret = callStack[$ - 1];
		callStack = callStack[0 .. $ - 1];
		return ret;
	}

	Variable PopReturn() {
		if (retStack.length == 0) {
			throw new YSLError("Pass stack: stack underflow");
		}

		auto ret = retStack[$ - 1];
		retStack = retStack[0 .. $ - 1];
		return ret;
	}

	bool LocalExists(string name) {
		if (locals.empty()) {
			return false;
		}
		
		return (name in locals[$ - 1]) !is null;
	}

	Value[]* GetLocal(string name) {
		return &locals[$ - 1][name];
	}

	bool GlobalExists(string name) {
		return (name in globals) !is null;
	}

	Value[]* GetGlobal(string name) {
		return &globals[name];
	}

	bool VariableExists(string name) {
		return LocalExists(name) || GlobalExists(name);
	}

	Value[]* GetVariable(string name) {
		if (LocalExists(name)) {
			return GetLocal(name);
		}

		return GetGlobal(name);
	}

	void CreateVariable(string name, int[] value) {
		if ((callStack.length == 0) || GlobalExists(name)) {
			globals[name] = value;
		}
		else {
			locals[$ - 1][name] = value;
		}
	}

	bool Jump(int line) {
		foreach (entry ; current.entries) {
			if (entry.value.key == line) {
				ip        = entry;
				increment = false;
				return true;
			}
		}

		return false;
	}

	void LoadFile(string path) {
		current = new SortedMap!(int, string);

		File file = File(path, "r");

		string line;
		int    num = 10;

		while ((line = file.readln()) !is null) {
			current[num]  = line[0 .. $ - 1];
			num          += 10;
		}
	}

	void AddFunc(string name, Function func) {
		funcs[name] ~= func;
	}

	void CallFunc(Function func, string[] args) {
		final switch (func.type) {
			case FunctionType.BuiltIn: {
				if (func.giveIP) {
					callStack ~= ip.value.key;
				}

				func.func(args, this);
				break;
			}
			case FunctionType.Ysl: {
				assert(0); // TODO
			}
		}
	}

	string Substitute(Value line, string part) {
		foreach (ref substitutor ; substitutors) {
			CallFunc(substitutor, [part]);

			if (PopReturn() == [0]) {
				continue;
			}

			return PopReturn().IntArrayToString();
		}

		return part;
	}

	void RunLine(Value line, string code) {
		CallFunc(splitter, [code]);
		auto parts = PopReturn().IntArrayToStringArray();

		if (parts.length == 0) {
			return;
		}

		foreach (ref part ; parts) {
			part = Substitute(line, part);
		}

		if (parts[0].isNumeric()) {
			if (parts.length == 1) {
				next[parse!int(parts[0])] = "";
				// TODO: delete the line
			}
			else {
				string codeLine = parts[1 .. $].join(" ");
				
				next[parse!int(parts[0])] = codeLine;
			}

			written = true;
		}
		else if (parts[0][$ - 1] == ':') {
			return; // label
		}
		else {
			if (parts[0] !in funcs) {
				stderr.writefln("%d: Function '%s' does not exist", line, parts[0]);
				throw new YSLError();
			}

			CallFunc(funcs[parts[0]][$ - 1], parts[1 .. $]);
		}
	}

	void Run() {
		if (current.entries.head is null) {
			stderr.writeln("Nothing to run");
			return;
		}

		ip = current.entries.head;

		while (ip !is null) {
			try {
				RunLine(ip.value.key, ip.value.value);
			}
			catch (Exception e) {
				writefln(
					"=== EXCEPTION from line %d in iteration %d ===", ip.value.key,
					iteration
				);
				writeln(e);
				exit(1);
			}

			if (increment) {
				ip = ip.next;
			}
			increment = true;
		}
	}

	void NextIteration() {
		current    = next;
		next       = new SortedMap!(int, string);
		iteration += 1;
		Reset();
	}
}
