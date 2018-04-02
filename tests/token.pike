#include "test.h"

import TOML.Token;

int main(int argc, array(string) argv)
{
  array(Token2) tokens = ({
    Token2(T_WS, 0, " \t", 1, 1),
    Token2(T_NL, 0, "\n",  2, 1),
    Token2(T_NL, 0, "\n",  3, 1),
    Token2(T_KEY, K_QUOTED, "hello", 4, 1),
    Token2(T_WS, 0, " ", 4, 7),
    Token2(T_KEYVAL_SEP, 0, "=", 4, 8),
    Token2(T_VAL, V_STR, "world", 4, 9)
  });

  werror("%O\n", TOML.fold_whitespace(tokens));

  DONE();
  return 0;
}
