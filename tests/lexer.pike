// Run with: pike -M../Parser.pmod lexer.pike
//       or: pike -M../Parser.pmod -DTOML_LEXER_DEBUG lexer.pike

#include "test.h"

constant DATA = #string "simple1.toml";

int main() {
  TOML.Lexer lexer = TOML.Lexer(DATA);
  array(TOML.Token) toks = ({});

  while (TOML.Token tok = lexer->lex()) {
    werror("::::::::: %O\n", tok);
    toks += ({ tok });
  }

  // werror("All tokens: %O\n", toks);
}
