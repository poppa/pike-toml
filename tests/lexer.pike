#include "test.h"

constant DATA = #"
################################################################################
## Table

# Tables (also known as hash tables or dictionaries) are collections of
# key/value pairs. They appear in square brackets on a line by themselves.

[table]

key = \"value\" # Yeah, you can do this.";

constant P1 = "abcdefghijk";
constant P2 = #"
this is a, [[sentence]] Ok?
";

int main()
{
  TOML.StringStream ps = TOML.StringStream(P1);

  ASSERT(ps->next_str(3) == "abc");
  ASSERT(ps->next_str(3) == "def");
  ASSERT(ps->next_str(4) == "ghij");
  ASSERT(ps->next_str()  == "k");
  // We should now be at the end.
  ASSERT(ps->is_eol());

  ps->rewind();

  // If we're not at 0 something is very wrong.
  ASSERT(ps->position()         == 0);

  // Check that the first char is 'a'
  ASSERT(ps->current()          == 'a');
  // Check that the next char is 'b' without consuming it...
  ASSERT(ps->peek()             == 'b');
  // ...which means that peeking three chars would leave us at 'd'
  // abcdefghijk
  // ...^
  // 0..3
  ASSERT(ps->peek(3)            == 'd');
  // And if we move one further than we peek we sould be at 'e'
  // abcdefghijk
  // ....^
  // 0...4
  ASSERT(ps->move(4)->current() == 'e');
  // Look one behind
  ASSERT(ps->rearview()         == 'd');
  // Look two beihind
  ASSERT(ps->rearview(2)        == 'c');
  // We should still be at 'e' but this will consume it.
  ASSERT(ps->next()             == 'e');
  // The we should have 'f'
  ASSERT(ps->next()             == 'f');
  // abcdefghijk
  // 0.....6 since 'f' was consumed.
  ASSERT(ps->position()         == 6);
  // which will leave us at "g"
  ASSERT(ps->current_str()      == "g");

  ps->set_data(P2)->trim();

  ASSERT(ps->read_to(" ")        == "this");
  ASSERT(ps->current()           ==  ' ');
  ps->trim();
  ASSERT(ps->read_to(", ", true) == "is a, ");
  ASSERT(ps->current(2)          == "[[");
  ASSERT(ps->peek_str(2)         == "[s");

  DONE("All Done: ");

  TOML.lex(DATA);
}