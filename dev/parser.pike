// Run with: pike -M../Parser.pmod parser.pike
//       or: pike -M../Parser.pmod -DTOML_PARSER_DEBUG parser.pike

#include "test.h"


int main() {
  TOML.Parser parser = TOML.Parser();

  START_TIMER();

  mapping res = parser->parse_file(combine_path(__DIR__, "Cargo.toml"));
  werror("Res: %O\n", res);


  werror("\nTook: %O\n", GET_TIME());

  // werror("All tokens: %O\n", toks);
}
