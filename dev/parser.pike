// Run with: pike -M../Parser.pmod parser.pike
//       or: pike -M../Parser.pmod -DTOML_PARSER_DEBUG parser.pike

#include "timer.h"


int main() {
  // TOML.Parser parser = TOML.Parser();

  START_TIMER();

  mapping res = Parser.TOML.Parser()->parse_file(combine_path(__DIR__, "simple1.toml"));
  werror("Res: %O\n", res);


  werror("\nTook: %O\n", GET_TIME());

  // werror("All tokens: %O\n", toks);
}
