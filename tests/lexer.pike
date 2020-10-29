// Run with: pike -M../Parser.pmod lexer.pike
//       or: pike -M../Parser.pmod -DTOML_LEXER_DEBUG lexer.pike

#include "test.h"

constant DATA = #string "Cargo.toml";

int main() {
  TOML.Lexer lexer = TOML.Lexer(DATA);

  while (TOML.Token tok = lexer->lex()) {
    werror("> lexing: %O\n", tok);
  }
}
