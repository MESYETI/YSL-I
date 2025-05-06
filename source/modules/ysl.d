module ysli.modules.ysl;

import ysli.util;
import ysli.environment;

void YslModule(Environment e) {
	e.AddFunc("interpret", Function((string[] args, Environment env) {
		auto line = env.PopCall();
		env.RunLine(line, args[0]);
	}, true));
}
