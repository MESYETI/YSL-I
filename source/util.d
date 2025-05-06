module ysli.util;

string IntArrayToString(int[] arr) {
	string ret;

	foreach (ref ch ; arr) {
		ret ~= cast(char) ch;
	}

	return ret;
}

int[] StringToIntArray(string str) {
	int[] ret;

	foreach (ref ch ; str) {
		ret ~= cast(int) ch;
	}

	return ret;
}

int[] StringArrayToIntArray(ref string[] arr) {
	int[] ret;

	foreach (ref str ; arr) {
		foreach (ref ch ; str) {
			ret ~= ch;
		}
		ret ~= 0;
	}

	return ret;
}

string[] IntArrayToStringArray(int[] arr) {
	string   reading;
	string[] ret;

	foreach (ref ch ; arr) {
		switch (ch) {
			case '\0': {
				ret     ~= reading;
				reading  = "";
				break;
			}
			default: {
				reading ~= ch;
				break;
			}
		}
	}

	return ret;
}
