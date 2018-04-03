// Run with: pike -M../Parser.pmod lexer.pike
//       or: pike -M../Parser.pmod -DTOML_LEXER_DEBUG lexer.pike

#include "test.h"

constant DATA = #string "simple1.toml";

constant P1 = "abcdefghijk";
constant P2 = #"
this is a, [[sentence]] Ok?
";

int main()
{
  TOML.Stream.Stream ps = TOML.Stream.StringStream(P1);

  ASSERT_EQ(ps->next_str(3),          "abc");
  ASSERT_EQ(ps->next_str(3),          "def");
  ASSERT_EQ(ps->next_str(4),          "ghij");
  ASSERT_EQ(ps->next_str(),           "k");
  // We should now be at the end.
  ASSERT(ps->is_eof());

  ps->rewind();

  // If we're not at 0 something is very wrong.
  ASSERT_EQ(ps->position(),           0);

  // Check that the first char is 'a'
  ASSERT_EQ(ps->current(),            'a');
  // Check that the next char is 'b' without consuming it...
  ASSERT_EQ(ps->peek(),               'b');
  // ...which means that peeking three chars would leave us at 'd'
  // abcdefghijk
  // ...^
  // 0..3
  ASSERT_EQ(ps->peek(3),              'd');
  // And if we move one further than we peek we sould be at 'e'
  // abcdefghijk
  // ....^
  // 0...4
  ASSERT_EQ(ps->move(4)->current(),   'e');
  // Look one behind
  ASSERT_EQ(ps->rearview(),           'd');
  // Look two beihind
  ASSERT_EQ(ps->rearview(2),          'c');
  // We should still be at 'e' but this will consume it.
  ASSERT_EQ(ps->next(),               'e');
  // Then we should have 'f'
  ASSERT_EQ(ps->next(),               'f');
  // abcdefghijk
  // 0.....6 since 'f' was consumed.
  ASSERT_EQ(ps->position(),           6);
  // which will leave us at "g"
  ASSERT_EQ(ps->current_str(),        "g");

  ps->set_data(P2)->trim();

  ASSERT_EQ(ps->read_to(" "),         "this");
  ASSERT_EQ(ps->current(),            ' ');

  ps->trim();

  ASSERT_EQ(ps->read_to(", ", true),  "is a, ");
  ASSERT_EQ(ps->current(2),           "[[");
  ASSERT_EQ(ps->peek_str(2),          "[s");

  DONE();

  START_TIMER();

  array(TOML.Token.Token) res = TOML.lex(DATA);
  werror("Res: %O\n", res);

  // res = TOML.fold_whitespace(res);
  // werror("Res folded: %O\n", res);
  werror("Took: %.fs\n", GET_TIME());
}
