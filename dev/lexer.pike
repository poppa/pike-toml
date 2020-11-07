// Run with: pike -M../Parser.pmod lexer.pike

#include "timer.h"

import Parser.TOML;

Stdio.File DATA = Stdio.File(combine_path(__DIR__, "Cargo.toml"));

int main() {
  Lexer lexer = Lexer(DATA);
  array(Token.Token) toks = ({});

  START_TIMER();

  while (Token.Token tok = lexer->lex()) {
    toks += ({ tok });
  }

  float t = GET_TIME();

  foreach (toks, Token.Token t) {
    werror("::::::::: %O\n", t);
  }

  werror("\nTook: %O\n", t);
}
