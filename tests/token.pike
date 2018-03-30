#include "test.h"

import TOML.Token;

int main(int argc, array(string) argv)
{
  ASSERT_EQ(TYPE_KEY,           1 << 0);
  ASSERT_EQ(TYPE_UNQUOTED_KEY,  1 << 1);
  ASSERT_EQ(TYPE_QUOTED_KEY,    1 << 2);
  ASSERT_EQ(TYPE_DOTTED_KEY,    1 << 3);
  ASSERT_EQ(TYPE_KEYVAL_SEP,    1 << 4);
  ASSERT_EQ(TYPE_WHITESPACE,    1 << 5);
  ASSERT_EQ(TYPE_NEWLINE,       1 << 6);
  ASSERT_EQ(TYPE_STRING,        1 << 7);
  ASSERT_EQ(TYPE_M_STRING,      1 << 8);
  ASSERT_EQ(TYPE_VALUE,         TYPE_STRING | TYPE_M_STRING);
  DONE();
  return 0;
}
