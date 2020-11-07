// Run with: pike -M. parser.pike

#include "timer.h"

import Parser.TOML;

int main() {
  START_TIMER();
  mapping res = parse_file(combine_path(__DIR__, "simple1.toml"));
  float t = GET_TIME();
  werror("Res: %O\n", res);
  werror("\nTook: %O\n", t);
}
