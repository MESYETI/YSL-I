module ysli.split;

import std.stdio;
import std.string;
import core.stdc.stdlib;
import ysli.util;
import ysli.environment;

char EscapeToChar(char ch) {
	switch (ch) {
		case '0': return 0;
		case 'n': return '\n';
		case 'r': return '\r';
		case 'e': return '\x1b';
		default:  return 255;
	}
}

void Split(string[] params, Environment e) {
	auto     line = e.PopCall();
	auto     str = params[0];
	string[] ret;
	string   reading;
	bool     inString;

	for (size_t i = 0; i < str.length; ++ i) {
		if (inString) {
			switch (str[i]) {
				case '"': {
					ret      ~= reading;
					reading   = "";
					inString  = false;
					continue;
				}
				case '\\': {
					++ i;

					if (i >= str.length) {
						stderr.writefln(
							"ERROR: (Line %d) Unexpected end of line interpreting escape",
							line
						);
						throw new YSLError();
					}

					char ch = EscapeToChar(str[i]);

					if (ch == 255) {
						stderr.writefln("ERROR: Invalid escape %c", ch);
						throw new YSLError();
					}

					reading ~= ch;
					break;
				}
				default: reading ~= str[i];
			}
		}
		else {
			switch (str[i]) {
				case '"': {
					inString = true;
					break;
				}
				case ' ':
				case '\t': {
					if (reading.strip() == "") {
						reading = "";
						break;
					}

					ret     ~= reading;
					reading  = "";
					break;
				}
				default: {
					reading ~= str[i];
					break;
				}
			}
		}
	}

	if (reading.strip() != "") {
		ret ~= reading;
	}

	e.retStack ~= StringArrayToIntArray(ret);
}
