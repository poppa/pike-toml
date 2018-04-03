// Note:
//  o We don't care about \r or \r\n here since the input is normalized to
//    only \n

#include "toml.h"
#include "lexer.h"

import .Spec;
import .Token;
inherit .Stream.StringStream;

protected s8 curr_value;
protected s8 curr_key;
protected int(0..) rows;
protected int(0..) col;

protected array(Token) tokens = ({});

protected int(1..) current_lineno()
{
  return rows + 1;
}

protected int(1..) current_column()
{
  return col + 1;
}

protected void push_token(Type type, s8 text, int _col, int _row)
{
  tokens += ({ Token(type, text, _row, _col) });
}

protected variant void push_token(Type type, s8 text, int _col)
{
  push_token(type, text, _col, CURR_LINENO());
}

protected variant void push_token(Type type, s8 text)
{
  push_token(type, text, CURR_COL(), CURR_LINENO());
}

protected int count_escapes_behind()
{
  int n = 0, step = 1;

  while (rearview(step++) == '\\') {
    n += 1;
  }

  return n;
}

protected void eat_nl_only(void|bool no_add_token)
{
  int start = cursor;
  ::eat('\n');
  int n = cursor - start;

  while (n--) {
    if (!no_add_token) {
      // push_token(TYPE_NEWLINE, "\n");
      PUSH_FOLD_TOKEN(TYPE_NEWLINE, "\n");
    }

    rows += 1;
    col = 0;
  }
}

protected void eat_nl()
{
  eat_nl_only();
  eat_ws();
  eat_comments();
}

protected void eat_ws()
{
 if (WS[CURRENT()]) {
    int(0..) s = cursor;
    ::eat(WS);
    int diff = cursor - s;

    // push_token(TYPE_WHITESPACE, data[s .. cursor - 1]);
    PUSH_FOLD_TOKEN(TYPE_WHITESPACE, data[s .. cursor - 1]);

    col += diff;
  }
}

protected void eat_ws_nl()
{
  if (WS[CURRENT()]) {
    eat_ws();
    eat_nl();
  }
}

protected void eat_comments()
{
  if (CURRENT() == COMMENT) {
    int(0..) s = cursor;
    read_to((< '\n', EOF >), false);
    // push_token(TYPE_COMMENT, data[s .. cursor]);
    PUSH_FOLD_TOKEN(TYPE_COMMENT, data[s .. cursor]);

    col += cursor - s;

    if (peek() == '\n') {
      NEXT();
      eat_nl();
    }
    else if (peek() == EOF) {
      TRACE("Peek EOF in eat_comments()\n");
      next();
      return;
    }

    eat_ws_nl();
  }
}

protected void read_literal_string()
{
  String.Buffer b = String.Buffer();

  EXPECT('\'');

  NEXT();

  loop: while (!is_eof()) {
    switch (current()) {
      case 0x09:
      case 0x20 .. 0x26:
      case 0x28 .. 0x10FFFF:
        break;

      case '\'':
        curr_value = b->get();
        break loop;

      default:
        if (CURRENT() == NEWLINE) {
          SYNTAX_ERROR("Unexpected newline in string");
        }

        SYNTAX_ERROR("Illegat character: %c (char %[0]d)", CURRENT());
    }

    b->putchar(CURRENT());
    NEXT();
  }
}

protected void read_basic_string()
{
  String.Buffer sb = String.Buffer();

  EXPECT('"');
  // Eat the "
  NEXT();

  loop: while (!is_eof()) {
    char c = CURRENT();
    switch (c) {
      /* [ space ] / [ ! ] */
      case 0x20 .. 0x21: break;
      /* [ " ] Possibly end of string */
      case 0x22:
        /* Check for escapes here */
        if (rearview() != '\\') {
          curr_value = sb->get();
          // Done, end of string.
          // Who ever called this must take care of the value.
          break loop;
        }
        break;

      // [ # ] .. [ [ ]
      case 0x23 .. 0x5B: break;
      // [ \ ]
      case 0x5C:
        if (!ESC_SEQ[peek()]) {
          SYNTAX_ERROR("Illegal escape: \\%c", peek());
        }
        // Check for \[u4HEX | U8HEX]
        break;

      // [ ] ] .. [ ~ ]
      case 0x5D .. 0x7E: break;
      // [ \200 ] .. [ \U0010ffff ]
      case 0x80 .. 0x10ffff: break;

      default:
        if (CURRENT() == NEWLINE) {
          SYNTAX_ERROR("Unexpected newline in string");
        }

        SYNTAX_ERROR("Illegat character: %c (char %[0]d)", CURRENT());
        break;
    }

    sb->putchar(CURRENT());
    NEXT();
  }
}

protected void read_multiline_string()
{
  if (!MUL_STR()) {
    SYNTAX_ERROR("Explected \"\"\" but got %c%c%c",
                 current(), peek(), peek(2));
  }

  String.Buffer sb = String.Buffer();

  int col_start = col + 1;
  int row_start = rows + 1;

  string rd = next_str(3);
  col += 3;
  eat_nl_only(true);

  bool skip_add = false;

  loop: while (!is_eof()) {
    char c = CURRENT();
    switch (c) {
      // newline
      case 0x0A: break;
      case 0x20 .. 0x5B:
        if (c == 0x22) {
          // End of string
          if (rearview() != '\\' && peek() == '"' && peek(2) == '"') {
            curr_value = sb->get();
            push_token(TYPE_M_STRING, curr_value, col_start, row_start);
            cursor += 3;
            col += 3;
            break loop;
          }
        }
        break;

      // [ \ ]
      case 0x5C:
        if (!ESC_SEQ[peek()] && peek() != '\n') {
          SYNTAX_ERROR("Illegal escape: \\%c", peek());
        }

        if (peek() == '\n') {
          skip_add = true;
        }
        // Check for \[u4HEX | U8HEX]
        break;

      case 0x5D .. 0x7E: break;
      case 0x80 .. 0x10FFFF: break;

      default:
        SYNTAX_ERROR("Illegal character %c", current());
        break;
    }

    if (!skip_add) {
      sb->putchar(CURRENT());
    }
    else {
      skip_add = false;
    }

    if (CURRENT() == NEWLINE) {
      rows += 1;
      col = 0;

      // Multiline strings ending with \ should remove starting whitespace
      // on the next line
      if (rearview() == '\\') {
        next();
        eat_ws();
        continue;
      }
    }
    else {
      col += 1;
    }

    // No macro here since we take care of the line and col bumps above
    next();
  }
}

protected mixed read_unquoted_key()
{
  String.Buffer sb = String.Buffer();

  loop: while (!is_eof()) {
    switch (CURRENT()) {
      CASE_KEY_START:
        sb->putchar(CURRENT());
        break;

      case STD_TABLE_CLOSE:
      case KEY_SEP:
      case WS_TAB:
      case WS_SPACE:
        /* Fall-through */
      case KEYVAL_SEP:
        curr_key = sb->get();
        // Let the caller take care of the token
        // push_token(TYPE_UNQUOTED_KEY, curr_key, col_start);
        break loop;

      default:
        SYNTAX_ERROR("Illegal character %c", current());
    }

    NEXT();
  }
}

protected s8 low_read_val()
{
  int curpos = cursor;
  read_to((< ' ', '\t', EOF, '\n', ',' >));

  if (cursor == curpos) {
    return 0;
  }

  return data[curpos .. cursor];
}

#define DATEP "%*4d-%*2d-%*2d"
#define TIMEP "%*2d:%*2d:%*2d"

protected void parse_value()
{
  char c = CURRENT();

  if (c == '.') {
    SYNTAX_ERROR("Scalar values must not start with a \".\"");
  }

  int curpos = cursor;
  int col_start = col + 1;
  int row_start = rows + 1;
  string x = low_read_val();

  if (!x) {
    error("FIXME: Unexpected error.\n");
  }

  curr_value = x;

  if (x == "true" || x == "false") {
    push_token(TYPE_BOOL, x, col_start);
    return;
  }

  x = replace(x, "_", "");
  TRACE("x: %s\n", x);

  if (x[0] == '+') {
    x = x[1..];
  }

  if (x == "0" || x == "-0") {
    push_token(TYPE_INT, x, col_start);
    return;
  }

  if (x == "0.0" || x == "-0.0") {
    push_token(TYPE_FLOAT, x, col_start);
    return;
  }

  string lx = lower_case(x);
  int xlen  = sizeof(lx);

  if (lx == "nan") {
    push_token(TYPE_NAN, x, col_start);
    return;
  }

  if (lx == "inf" || lx == "-inf") {
    push_token(TYPE_INF, x, col_start);
    return;
  }

  // Check for dates
  if (xlen >= 8) {
    object m;
    bool is_time = true;
    if (sscanf(x, DATEP) == 3) {
      if (mixed err = catch(m = Calendar.dwim_time(x))) {
        is_time = false;
        catch(m = Calendar.dwim_day(x));
      }
    }
    else if (sscanf(x, TIMEP) == 3) {
      if (catch(m = Calendar.dwim_time(x))) {
        is_time = false;
      }
    }

    if (m && is_time) {
      push_token(TYPE_TIME, x, col_start);
      return;
    }
    else if (m) {
      push_token(TYPE_DATE, x, col_start);
      return;
    }
  }

  lx = "\0" + lx + "\0";

  bool is_float, is_binary,
    is_hex, is_octal;

  multiset(char) numcheck = DIGIT;

  loop: for (int i = 1; i <= xlen; i++) {
    char d  = lx[i];
    char nx = lx[i+1];
    char px = lx[i-1];

    if (is_hex) {
      if (!HEX_CHARS[d]) {
        SYNTAX_ERROR("Invalid hexadecimal value");
      }
      continue;
    }
    else if (is_octal) {
      if (!OCTAL[d]) {
        SYNTAX_ERROR("Invalid octal value");
      }
      continue;
    }
    else if (is_binary) {
      if (!BINARY[d]) {
        SYNTAX_ERROR("Invalid binary number");
      }
      continue;
    }

    switch (d) {
      case '0' .. '9': continue loop;
      case '.':
        if (is_float) {
          SYNTAX_ERROR("Malformed float value");
        }

        is_float = true;
        continue loop;

      // Binary
      case 'b':
        if (px != '0') {
          SYNTAX_ERROR("Malformed binary value");
        }

        is_binary = true;
        continue loop;

      // Hexadecimal
      case 'x':
        if (is_float || is_octal || is_binary || px != '0') {
          SYNTAX_ERROR("Malformed hexadecimal value");
        }

        is_hex = true;
        continue loop;

      // Octal
      case 'o':
        if (is_octal || is_hex || is_float || px != '0') {
          SYNTAX_ERROR("Malformed octal value");
        }

        is_octal = true;
        continue loop;

      // Exponential
      case 'e':
        if (!(DIGIT[nx] || (< '-', '+' >)[nx])) {
          SYNTAX_ERROR("Malformed numeric value");
        }
        continue loop;

      default:
        SYNTAX_ERROR("Illegal character %c", x[i-1]);
    }
  }

  if (is_float) {
    push_token(TYPE_FLOAT, x, col_start);
  }
  else if (is_hex) {
    push_token(TYPE_HEX, x, col_start);
  }
  else if (is_octal) {
    push_token(TYPE_OCT, x, col_start);
  }
  else if (is_binary) {
    push_token(TYPE_BINARY, x, col_start);
  }
  else {
    push_token(TYPE_INT, x, col_start);
  }
}

protected void read_value()
{
  eat_ws();
  char c = CURRENT();
  int(0..) row_start = rows + 1;
  int(0..) col_start = col + 1;

  if (MUL_STR()) {
    read_multiline_string();
  }
  else if (c == STR_START) {
    read_basic_string();
    push_token(TYPE_STRING, curr_value, col_start);
    NEXT();
  }
  else if (c == LIT_STR_START) {
    read_literal_string();
    push_token(TYPE_LIT_STRING, curr_value, col_start);
    NEXT();
  }
  else if (c == INLINE_TBL_START) {
    error("Inline table not implemented yet.\n");
  }
  else {
    parse_value();
    NEXT();
  }
}

protected void read_key_val()
{
  read_key();
  eat_ws();

  if (CURRENT() != KEYVAL_SEP) {
    SYNTAX_ERROR("Expected \"=\" after key %q got \"%c\".\n",
                 curr_key || "Unknown key", current());
  }

  push_token(TYPE_KEYVAL_SEP, current_str());
  NEXT();
  eat_ws();
  read_value();
  eat_nl();
}

protected void read_key(void|bool is_recurse)
{
  eat_ws();
  char c = current();

  TRACE(">> read_key(%c)\n", c);

  int(0..) col_start = col + 1;

  if (UNQUOTED_KEY_START[c]) {
    TRACE("Read unquoted key\n");
    read_unquoted_key();
    push_token(TYPE_UNQUOTED_KEY, curr_key, col_start);
  }
  else if (c == LITERAL_KEY_START) {
    read_literal_string();
    EXPECT(LITERAL_KEY_START);
    curr_key = curr_value;
    push_token(TYPE_LIT_KEY, curr_key, col_start);
    NEXT();
  }
  else if (c == QUOTED_KEY_START) {
    read_basic_string();
    EXPECT(QUOTED_KEY_START);
    push_token(TYPE_QUOTED_KEY, curr_value, col_start);
    NEXT();
  }
  else {
    SYNTAX_ERROR("Illegal character: \"%c\"", c);
  }

  eat_ws();

  switch (current()) {
    case KEY_SEP:
      push_token(TYPE_KEY_SEP, ".");
      NEXT();
      this_function(); // recurse
      break;

    case STD_TABLE_CLOSE:
      /* Break and let read_std_table() take care of the token */
      break;
  }

  TRACE("<< read_key(%c)\n", CURRENT());
}

protected void read_std_table()
{
  EXPECT(STD_TABLE_OPEN);
  push_token(TYPE_STD_TABLE_OPEN, "[");
  NEXT();
  read_key();
  eat_ws();
  EXPECT(STD_TABLE_CLOSE);
  push_token(TYPE_STD_TABLE_CLOSE, "]");
  NEXT();
  eat_nl();
}

array(Token) fold_whitespace()
{
  return filter(tokens, lambda (Token t) {
    return !t->is_a(TYPE_WHITESPACE|TYPE_NEWLINE|TYPE_COMMENT|TYPE_DEBUG);
  });
}

array(Token) lex()
{
  if (is_eof()) {
    return tokens;
  }

  do {
    eat_nl();

    TRACE(">>> lex: \"%c\" (row: %d, col: %d)\n",
           current(), current_lineno(), current_column());

    if (is_eof()) {
      TRACE("Is eol\n");
      return tokens;
    }

    switch (CURRENT()) {
      case STD_TABLE_OPEN:
        // [[
        if (peek() == STD_TABLE_OPEN) {
          die("Multitable\n");
        }
        else {
          read_std_table();
        }
        continue;

      CASE_KEY_START:
        read_key_val();
        continue;

      case ' ':
      case '\t':
        eat_ws_nl();
        continue;

      default:
        TRACE("len: %O, cursor: %O, is_eof: %O\n",
              len, cursor, is_eof());
        SYNTAX_ERROR("Unexpexted character: \"%c\"", current());
    }

  } while (!is_eof());

  return tokens;
}
