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

enum RWMode {
	Current,
	Next
}

enum FunctionType {
	BuiltIn,
	Ysl
}

alias BuiltInFunc = void function(string[] args, Environment e);

enum ParamType {
	Integer,
	Other
}

struct Function {
	FunctionType  type;
	bool          giveIP;
	ParamType[][] paramSets;
	bool          enforceParams;

	union {
		BuiltInFunc func;
		Label       label;
	}

	this(BuiltInFunc pfunc, bool pgiveIP = false) {
		type   = FunctionType.BuiltIn;
		func   = pfunc;
		giveIP = pgiveIP;
	}

	this(ParamType[][] pparamSets, BuiltInFunc pfunc) {
		type          = FunctionType.BuiltIn;
		func          = pfunc;
		enforceParams = true;
		paramSets     = pparamSets;
	}

	this(Label plabel) {
		type  = FunctionType.Ysl;
		label = plabel;
	}

	bool ValidateSet(ParamType[] set, string[] args) {
		if (set.length != args.length) return false;

		foreach (i, ref param ; set) {
			final switch (param) {
				case ParamType.Integer: {
					if (!args[i].isNumeric()) return false;
					break;
				}
				case ParamType.Other: break;
			}
		}

		return true;
	}

	bool Validate(string[] args) {
		if (enforceParams) return true;

		foreach (ref set ; paramSets) {
			if (!ValidateSet(set, args)) return false;
		}

		return true;
	}
}

class YSLError : Exception {
	this(string msg = "", string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class YSLDone : Exception {
	this() {
		super("", "", 0);
	}
}

class Environment {
	bool                       written;
	CodeMap                    current;
	CodeMap                    next;
	Label                      ip;
	Function[]                 substitutors;
	Function                   splitter;
	Variable[]                 passStack;
	Value[]                    callStack;
	Variable[]                 retStack;
	Function[][string]         globalFuncs;
	Function[][string]         funcs;
	Variable[string]           globals;
	Variable[string][]         locals;
	bool                       increment;
	Module[string]             modules;
	size_t                     iteration;
	bool                       useNamespace;
	string                     namespace;
	RWMode                     readMode;
	RWMode                     writeMode;
	Function[][string][string] sets;
	string                     currentSet;

	// vectors
	Function* atExit;

	this() {
		current       = new SortedMap!(int, string);
		next          = new SortedMap!(int, string);
		Reset();

		// global funcs
		globalFuncs["set"] = [Function((string[] args, Environment env) {
			if (args[0] !in env.sets) {
				env.sets[args[0]] = new Function[][string];
			}

			env.SwitchSet(args[0]);
		})];
	}

	void Reset() {
		sets["YSL-I"] = new Function[][string];
		SwitchSet("YSL-I");
		written       = false;
		substitutors ~= Function(&Substitutor, true);
		splitter      = Function(&Split, true);
		passStack     = [];
		callStack     = [];
		retStack      = [];
		globals       = new Variable[string];
		locals        = [];
		increment     = true;
		modules       = new Module[string];
		useNamespace  = false;
		readMode      = RWMode.Current;
		writeMode     = RWMode.Next;

		import ysli.modules.core;
		import ysli.modules.ysl;
		import ysli.modules.file;
		modules["core"] = &CoreModule;
		modules["ysl"]  = &YslModule;
		modules["file"] = &FileModule;

		// load core module
		modules["core"](this);
	}

	void SwitchSet(string set) {
		if (set !in sets) {
			sets[set] = new Function[][string];
		}
		currentSet = set;
		funcs      = sets[set];
	}

	CodeMap GetMap(RWMode mode) {
		final switch (mode) {
			case RWMode.Current: return current;
			case RWMode.Next:    return next;
		}
	}

	CodeMap GetReadMap()  => GetMap(readMode);
	CodeMap GetWriteMap() => GetMap(writeMode);

	// built in stuff
	static private void Substitutor(string[] params, Environment e) {
		Value line = e.PopCall();
		auto  str  = params[0];

		if (str.length == 0) {
			e.retStack ~= [0];
		}

		string subChars = "|!$*\\";

		if (!subChars.canFind(str[0])) {
			e.retStack ~= [0];
			return;
		}

		string operand = str[1 .. $];

		if (str[0] != '\\') {
			string newOp = e.Substitute(line, operand);
			while (newOp != operand) {
				operand = newOp;
				newOp   = e.Substitute(line, operand);
			}
		}

		switch (str[0]) {
			case '|': {
				auto code = e.GetMap(e.readMode);

				if (!operand.isNumeric()) {
					stderr.writefln("%d: | substitutor requires numeric value", line);
					stderr.writefln("got: %s", operand);
					throw new YSLError();
				}

				Value getLine = parse!Value(operand);

				if (getLine !in e.current) {
					stderr.writefln("%d: line %d does not exist", line, getLine);
					throw new YSLError();
				}

				e.retStack ~= StringToIntArray(code[getLine]);
				e.retStack ~= [1];
				break;
			}
			case '!': {
				switch (operand) {
					case "<pass>":   e.retStack ~= e.PopPass();   break;
					case "<call>":   e.retStack ~= [e.PopCall()]; break;
					case "<return>": e.retStack ~= e.PopReturn(); break;
					case "<set>":    e.retStack ~= e.currentSet.StringToIntArray(); break;
					default: {
						if (!e.VariableExists(operand)) {
							stderr.writefln(
								"Error: line %d: Unknown variable %s", line, operand
							);
							throw new YSLError();
						}

						e.retStack ~= *e.GetVariable(operand);
					}
				}
				e.retStack ~= [1];
				break;
			}
			case '$': {
				switch (operand) {
					case "<pass>": {
						e.retStack ~= e.PopPass()[0].text().StringToIntArray();
						break;
					}
					case "<call>": {
						e.retStack ~= e.PopCall().text().StringToIntArray();
						break;
					}
					case "<return>": {
						e.retStack ~= e.PopReturn()[0].text().StringToIntArray();
						break;
					}
					default: {
						if (!e.VariableExists(operand)) {
							stderr.writefln(
								"Error: line %d: Unknown variable %s", line, operand
							);
							throw new YSLError();
						}

						e.retStack ~= text((*e.GetVariable(operand))[0]).StringToIntArray();
					}
				}
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
			case '\\': {
				e.retStack ~= operand.StringToIntArray();
				e.retStack ~= [1];
				break;
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

	Label GetLine(Value line) {
		foreach (entry ; current.entries) {
			if (entry.value.key == line) {
				return entry;
			}
		}

		return null;
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

	void LoadFile(CodeMap map, string path) {
		File file = File(path, "r");

		string line;
		int    num = 10;

		while ((line = file.readln()) !is null) {
			map[num]  = line[0 .. $ - 1];
			num      += 10;
		}
	}

	void SetNamespace(string pnamespace) {
		useNamespace = true;
		namespace    = pnamespace;
	}

	void AddFunc(string name, Function func) {
		funcs[useNamespace? format("%s.%s", namespace, name) : name] ~= func;
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
				callStack ~= ip.value.key;

				foreach (ref arg ; args) {
					passStack ~= arg.StringToIntArray();
				}

				if (Jump(func.label.value.key)) return;

				stderr.writefln("Error: Couldn't call function at %d", ip.value.key);
				throw new YSLError();
			}
		}
	}

	void RunFunc(Function func, string[] args) {
		final switch (func.type) {
			case FunctionType.BuiltIn: {
				if (func.giveIP) {
					callStack ~= ip.value.key;
				}

				func.func(args, this);
				break;
			}
			case FunctionType.Ysl: {
				callStack ~= ip.value.key;

				foreach (ref arg ; args) {
					passStack ~= arg.StringToIntArray();
				}

				if (!Jump(func.label.value.key)) {
					stderr.writefln("Error: Couldn't call function at %d", ip.value.key);
					throw new YSLError();
				}

				try {
					RunFromHere();
				}
				catch (YSLDone) {
					return;
				}
			}
		}
	}

	string Substitute(Value line, string part) {
		foreach (ref substitutor ; substitutors) {
			RunFunc(substitutor, [part]);

			if (PopReturn() == [0]) {
				continue;
			}

			return PopReturn().IntArrayToString();
		}

		return part;
	}

	bool FuncExists(string func) {
		return (func in funcs) || (func in globalFuncs) || (func == "<splitter>");
	}

	Function GetFunc(Value line, string func) {
		switch (func) {
			case "<splitter>": return splitter;
			default: {		
				if ((func !in funcs) && (func !in globalFuncs)) {
					stderr.writefln("%d: Function '%s' does not exist", line, func);
					throw new YSLError();
				}

				if (func in globalFuncs) return globalFuncs[func][$ - 1];

				return funcs[func][$ - 1];
			}
		}
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
				int writeLine = parse!int(parts[0]);
				
				next[writeLine] = codeLine;
			}

			written = true;
		}
		else if (parts[0][$ - 1] == ':') {
			return; // label
		}
		else {
			if (!FuncExists(parts[0]) && (currentSet != "YSL-I")) {
				auto  map  = GetWriteMap();
				Value key  = 10;

				if (map.entries.head !is null) {
					key = map.entries.head.GetLastEntry().value.key + 10;
				}

				map[key] = code;
				written  = true;
				return;
			}

			CallFunc(GetFunc(line, parts[0]), parts[1 .. $]);
		}
	}

	void RunFromHere() {
		while (ip !is null) {
			try {
				RunLine(ip.value.key, ip.value.value);
			}
			catch (YSLDone e) {
				throw e;
			}
			catch (Exception e) {
				writefln(
					"=== EXCEPTION from line %d in iteration %d in set '%s' ===",
					ip.value.key, iteration, currentSet
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

	void Run() {
		if (current.entries.head is null) {
			stderr.writeln("Nothing to run");
			return;
		}

		ip = current.entries.head;
		RunFromHere();

		if (atExit !is null) {
			ip = current.entries.head.GetLastEntry();
			RunFunc(*atExit, []);
		}
	}

	void NextIteration() {
		current    = next;
		next       = new SortedMap!(int, string);
		iteration += 1;
		Reset();
	}
}
