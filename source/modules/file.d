module ysli.modules.file;

import std.conv;
import std.array;
import std.stdio;
import std.algorithm;
import ysli.util;
import ysli.environment;

private File[int] files;

void FileModule(Environment e) {
	e.AddFunc("open", FuncCall((string[] args, Environment env) {
		int file = files.keys.length > 0? files.keys().maxElement() + 1 : 0;

		try {
			files[file] = File(args[0], args[1]);
		}
		catch (Exception e) {
			stderr.writefln("Error: file.open: %s", e.msg);
			throw new YSLError();
		}

		env.retStack ~= [file];
	}));
	e.AddFunc("write", FuncCall((string[] args, Environment env) {
		int file = parse!int(args[0]);

		if (file !in files) {
			stderr.writefln("Error: file.write: File '%d' doesn't exist", file);
			throw new YSLError();
		}

		try {
			files[file].write(args[1]);
		}
		catch (Exception e) {
			stderr.writefln("Error: file.write: %s", e.msg);
			throw new YSLError();
		}
		files[file].flush();
	}));
	e.AddFunc("read", FuncCall((string[] args, Environment env) {
		int file = parse!int(args[0]);

		if (file !in files) {
			stderr.writefln("Error: read: File '%d' doesn't exist", file);
			throw new YSLError();
		}

		auto res = new ubyte[parse!int(args[1])];

		try {
			files[file].rawRead(res);
		}
		catch (Exception e) {
			stderr.writefln("Error: file.read: %s", e.msg);
			throw new YSLError();
		}

		Variable ret;
		foreach (ref b ; res) {
			ret ~= cast(int) b;
		}
		env.retStack ~= ret;
	}));
	e.AddFunc("tell", FuncCall((string[] args, Environment env) {
		int file = parse!int(args[0]);

		if (file !in files) {
			stderr.writefln("Error: file.tell: File '%d' doesn't exist", file);
			throw new YSLError();
		}

		env.retStack ~= [cast(Value) files[file].tell];
	}));
	e.AddFunc("seek_set", FuncCall((string[] args, Environment env) {
		int file = parse!int(args[0]);

		if (file !in files) {
			stderr.writefln("Error: file.seek_set: File '%d' doesn't exist", file);
			throw new YSLError();
		}

		files[file].seek(parse!int(args[1]), SEEK_SET);
	}));
	e.AddFunc("seek_end", FuncCall((string[] args, Environment env) {
		int file = parse!int(args[0]);

		if (file !in files) {
			stderr.writefln("Error: file.seek_end: File '%d' doesn't exist", file);
			throw new YSLError();
		}

		files[file].seek(parse!int(args[1]), SEEK_END);
	}));
	e.AddFunc("seek_cur", FuncCall((string[] args, Environment env) {
		int file = parse!int(args[0]);

		if (file !in files) {
			stderr.writefln("Error: file.seek_cur: File '%d' doesn't exist", file);
			throw new YSLError();
		}

		files[file].seek(parse!int(args[1]), SEEK_CUR);
	}));
	e.AddFunc("close", FuncCall((string[] args, Environment env) {
		int file = parse!int(args[0]);

		if (file !in files) {
			stderr.writefln("Error: file.seek_cur: File '%d' doesn't exist", file);
			throw new YSLError();
		}

		files[file].close();
		files.remove(file);
	}));
}
