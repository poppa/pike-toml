// Run with: pike -M../Parser.pmod parser.pike
//       or: pike -M../Parser.pmod -DTOML_PARSER_DEBUG parser.pike

#include "test.h"


int main() {
  TOML.Parser parser = TOML.Parser();

  // START_TIMER();

  parser->parse_file(combine_path(__DIR__, "simple1.toml"));


  // werror("\nTook: %O\n", GET_TIME());

  // werror("All tokens: %O\n", toks);
}
