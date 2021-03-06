// Run with: pike -M../Parser.pmod lexer.pike

#include "timer.h"

import Parser.TOML;


int main() {
  Stdio.File DATA = Stdio.File(combine_path(__DIR__, "fail.toml"), "r");
  Lexer lexer = Lexer(DATA);
  array(Token.Token) toks = ({});

  START_TIMER();

  while (Token.Token tok = lexer->lex()) {
    toks += ({ tok });
  }

  float t = GET_TIME();

  foreach (toks, Token.Token t) {
    werror("Tok: %O\n", t);
    // if (t->is_value()) {
    //   werror("::::V:A:L:::::\n%s\n", t->pike_value());
    // } else if (t->is_key()) {
    //   werror("::::K:E:Y:::::\n%O\n", t);
    // }
  }

  werror("\nTook: %.5f\n", t);

  // write("%s\n", string_to_utf8( "Name\tJos\u00E9\nLoc\tSF."));

  // Stdio.File data2 = Stdio.File(combine_path(__DIR__, "simple1.toml"), "r");
  // write("%s\n", data2->read());
}
