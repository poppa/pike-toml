test:
	pike -M. tests/run.pike $(file)

run_bug:
	pike -M. -DWITH_MODULE_ROOT dev/parser.pike

run_no_bug:
	pike -M. dev/parser.pike
