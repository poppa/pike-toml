// Run with: pike -M../Parser.pmod lexer.pike
//       or: pike -M../Parser.pmod -DTOML_LEXER_DEBUG lexer.pike

#include "test.h"

Stdio.File DATA = Stdio.File(combine_path(__DIR__, "simple1.toml"));

int main() {
  TOML.Lexer lexer = TOML.Lexer(DATA);
  array(TOML.Token) toks = ({});

  START_TIMER();

  while (TOML.Token tok = lexer->lex()) {
    werror("::::::::: %O\n", tok);
    toks += ({ tok });
  }

  werror("\nTook: %O\n", GET_TIME());

  // werror("All tokens: %O\n", toks);
}
