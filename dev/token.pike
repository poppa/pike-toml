#include "test.h"

import TOML.Token;

int main(int argc, array(string) argv)
{
  array(Token) tokens = ({
    Token(T_WS, 0, " \t", 1, 1),
    Token(T_NL, 0, "\n",  2, 1),
    Token(T_NL, 0, "\n",  3, 1),
    Token(T_KEY, K_QUOTED, "hello", 4, 1),
    Token(T_WS, 0, " ", 4, 7),
    Token(T_KEYVAL_SEP, 0, "=", 4, 8),
    Token(T_VAL, V_STR, "world", 4, 9)
  });

  ASSERT_EQ(sizeof(TOML.fold_whitespace(tokens)), 3);

  DONE();

  return 0;
}
