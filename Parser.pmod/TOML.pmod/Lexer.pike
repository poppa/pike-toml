#include "toml.h"

#ifdef TOML_LEXER_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...)0
#endif

#define die(X...) \
  do { \
    werror("Tokens: %O\n", tokens); \
    exit(0, X); \
  } while (0)

#define SYNTAX_ERROR(R...) \
  error("Synax error at line %d column %d byte %d: %s.\n", \
        current_lineno(), current_column(), cursor, sprintf(R))

import .Spec;
import .Token;
inherit .Stream.StringStream;

mapping doc = ([]);
mapping curr_storage = doc;
mixed curr_value;
int(0..) rows;
int(0..) col;

array(Token) tokens = ({});

s8 curr_key;

protected int(1..) current_lineno()
{
  return rows + 1;
}

protected int(1..) current_column()
{
  return col + 1;
}

protected void push_token(SimpleType type, s8 text, void|int _col,
                          void|int _row)
{
  if (zero_type(_col)) {
    _col = current_column();
  }

  if (zero_type(_row)) {
    _row = current_lineno();
  }

  tokens += ({ Token(type, text, _row, _col) });
}

protected int count_escapes_behind()
{
  int n = 0, step = 1;

  werror("count_escapes_behind(< %c)\n", rearview());

  while (rearview(step++) == '\\') {
    n += 1;
  }

  return n;
}

protected void eat_nl_only()
{
  int start = cursor;
  ::eat('\n');
  int n = cursor - start;

  while (n--) {
    TRACE("Got %d nl\n", n);
    push_token(SIMPLE_TYPE_NEWLINE, "\n");
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
  if (WS[current()]) {
    int(0..) s = cursor;
    ::eat(WS);
    int diff = cursor - s;

    push_token(SIMPLE_TYPE_WHITESPACE, data[s .. cursor - 1]);

    col += diff;
    eat_nl();
  }
}

protected void eat_comments()
{
  if (current() == '#') {
    int(0..) s = cursor;
    read_to((< '\n', EOL >), false);
    col += cursor - s;

    if (peek() == '\n') {
      next();
      col += 1;
      eat_nl();
    }

    eat_ws();
  }
}

protected void read_literal_string()
{
  werror("read_literal_string()\n");
  String.Buffer b = String.Buffer();
}

protected void read_basic_string()
{
  String.Buffer sb = String.Buffer();

  if (current() != '"') {
    SYNTAX_ERROR("Expected \" but got %c", current());
  }

  // Eat the "
  next();
  col += 1;

  werror("read_basic_string(%c)\n", current());

  int(0..) col_start = col - 1; // Take the eaten " into account

  loop: while (!is_eol()) {
    switch (current()) {
      /* [ space ] / [ ! ] */
      case 0x20 .. 0x21: break;
      /* [ " ] Possibly end of string */
      case 0x22:
        /* Check for escapes here */
        if (rearview() != '\\') {
          curr_value = sb->get();
          push_token(SIMPLE_TYPE_STRING, curr_value, col_start);
          next(); // eat current char
          col += 1;
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
        if (current() == 0x0A) {
          SYNTAX_ERROR("Unexpected newline in string");
        }

        SYNTAX_ERROR("Illegat character: %c (char %[0]d)", current());
        break;
    }

    sb->putchar(current());
    next();
    col += 1;
  }
}

protected void read_multiline_string()
{
  if (current() != '"' && peek() != '"' && peek(2) != '"') {
    SYNTAX_ERROR("Explected \"\"\" but got %c%c%c",
                 current(), peek(), peek(2));
  }

  String.Buffer sb = String.Buffer();

  int col_start = col + 1;
  int row_start = rows + 1;

  string rd = next_str(3);
  col += 3;
  eat_nl_only();

  loop: while (!is_eol()) {
    switch (current()) {
      // newline
      case 0x0A: break;
      case 0x20 .. 0x5B:
        if (current() == 0x22) {
          // End of string
          if (rearview() != '\\' && peek() == '"' && peek(2) == '"') {
            curr_value = sb->get();
            push_token(SIMPLE_TYPE_M_STRING, curr_value, col_start, row_start);
            cursor += 3;
            col += 3;
            break loop;
          }
        }
        break;

      // [ \ ]
      case 0x5C:
        if (!ESC_SEQ[peek()]) {
          SYNTAX_ERROR("Illegal escape: \\%c", peek());
        }
        // Check for \[u4HEX | U8HEX]
        break;

      case 0x5D .. 0x7E: break;
      case 0x80 .. 0x10FFFF: break;

      default:
        SYNTAX_ERROR("Illegal character %c", current());
        break;
    }

    if (current() == '\n') {
      rows += 1;
      col = 0;
    }
    else {
      col += 1;
    }

    sb->putchar(current());
    next();
  }
}

protected mixed read_unquoted_key()
{
  werror("read_unquoted_key(%c)\n", current());
  String.Buffer sb = String.Buffer();

  int(0..) col_start = col + 1;

  loop: while (!is_eol()) {
    switch (current()) {
      case '0' .. '9': case 'a' .. 'z': case 'A' .. 'Z':
      case '_': case '-':
        sb->putchar(current());
        break;

      case ' ':
        eat_ws();
        /* Fall-through */
      case '=':
        curr_key = sb->get();
        push_token(SIMPLE_TYPE_UNQUOTED_KEY, curr_key, col_start);
        push_token(SIMPLE_TYPE_KEYVAL_SEP, "=");
        break loop;

      default:
        SYNTAX_ERROR("Illegal character %c", current());
    }

    ::next();
    col += 1;
  }
}

protected void read_value()
{
  eat_ws();

  char c = current();

  werror("read_value(%c)\n", c);

  if (c == '"' && peek() == '"' && peek(2) == '"') {
    read_multiline_string();
    eat_nl();
  }
  else if (c == '"') {
    read_basic_string();
    eat_nl();
  }
  else {
    error("Value starting with %c not implemented yet. ", c);
  }
}

protected void read_key()
{
  werror("read_key()\n");
  s8 k;

  switch (current()) {
    case '\'':
      read_literal_string();
      break;

    case '"':
      read_basic_string();
      break;

    default:
      read_unquoted_key();
      break;
  }

  eat_ws();

  if (current() != '=') {
    error("Syntax error at line %d. Expected \"=\" after key %q.\n",
          current_lineno(), k || "Unknown key");
  }

  next();
  col += 1;

  read_value();

  // exit(0);
}

mapping lex()
{
  if (is_eol()) {
    werror("Is eol\n");
    exit(0);
  }

  eat_nl();

  werror("After init: %c (row: %d, col: %d)\n",
         current(), current_lineno(), current_column());

  switch (current())
  {
    case '[':
      if (peek() == '[') {
        die("Multitable\n");
      }
      else {
        die("Table\n");
      }
      break;

    // Key can start with [_ 0-9 a-Z " ']
    case '\'': case '"': case '_':
    case '0' .. '9': case 'a' .. 'z': case 'A' .. 'Z':
      werror("+++ Start read Key\n");
      read_key();
      werror("Should have key: %O\n", curr_key);
      werror("Should have value: %O\n", curr_value);
      return lex();
      break;

    default:
      SYNTAX_ERROR("Unexpexted character: \"%c\"", current());
      break;
  }

  werror("Tokens: %O\n", tokens);

  return doc + ([]);
}