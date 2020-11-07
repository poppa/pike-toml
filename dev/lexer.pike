// Run with: pike -M../Parser.pmod lexer.pike
//       or: pike -M../Parser.pmod -DTOML_LEXER_DEBUG lexer.pike

#include "timer.h"

Stdio.File DATA = Stdio.File(combine_path(__DIR__, "Cargo.toml"));

int main() {
  Parser.TOML.Lexer lexer = Parser.TOML.Lexer(DATA);
  array(Parser.TOML.Token.Token) toks = ({});

  START_TIMER();

  while (Parser.TOML.Token.Token tok = lexer->lex()) {
    werror("::::::::: %O\n", tok);
    toks += ({ tok });
  }

  werror("\nTook: %O\n", GET_TIME());

  // werror("All tokens: %O\n", toks);
}