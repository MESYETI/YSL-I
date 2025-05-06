/// module for a sorted map class
module ysli.sortedMap;

import std.format;
import ysli.list;

/// exception used for sorted map errors
class SortedMapException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

struct MapEntry(T1, T2) {
	T1 key;
	T2 value;
}

/// sorted map class
class SortedMap(T1, T2) {
	/// linked list of entries
	List!(MapEntry!(T1, T2)) entries;

	this() {
		entries = new List!(MapEntry!(T1, T2));
	}

	/// overrides in keyword
	T2* opBinaryRight(string op: "in")(T1 key) {
		foreach (e ; entries) {
			if (e.value.key == key) {
				return &e.value.value;
			}
		}

		return null;
	}

	/// overrides index
	T2 opIndex(T1 key) {
		auto ret = key in this;

		if (ret is null) {
			throw new SortedMapException("Key not found in sorted map");
		}

		return *ret;
	}

	/// overrides assigning to index
	void opIndexAssign(T2 value, T1 key) {
		foreach (e ; entries) {
			if (e.value.key == key) {
				e.value.value = value;
				return;
			}
		}
	
		auto entry = MapEntry!(T1, T2)(key, value);

		if (entries.head is null) {
			entries.head = new ListNode!(MapEntry!(T1, T2))(entry);
			return;
		}

		foreach (e ; entries) {
			if (e.value.key > key) {
				e.InsertBefore(entries, entry);
				return;
			}
		}

		entries ~= entry;
	}

	/// overrides foreach loops
	int opApply(scope int delegate(T1 key, ref T2 value) dg) {
		foreach (e ; entries) {
			int result = dg(e.value.key, e.value.value);

			if (result) {
				return result;
			}
		}

		return 0;
	}
}
