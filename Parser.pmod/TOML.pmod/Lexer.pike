#include "toml.h"

#ifdef TOML_LEXER_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
# define PUSH_DEBUG_TOKEN(X...) do { \
    push_token(TYPE_DEBUG, sprintf(X)); \
  } while (0)
#else
# define TRACE(X...)
# define PUSH_DEBUG_TOKEN(X...)
#endif

#define die(X...) \
  do { \
    werror("Tokens: %O\n", tokens); \
    s8 p = sprintf("DIE: %s:%d: ", basename(__FILE__),  __LINE__); \
    p += sprintf(X); \
    exit(0, p); \
  } while (0)

#define SYNTAX_ERROR(R...) \
  error("Synax error at line %d column %d byte %d: %s.\n", \
        current_lineno(), current_column(), cursor, sprintf(R))

import .Spec;
import .Token;
inherit .Stream.StringStream;

protected mixed curr_value;
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

protected void push_token(Type type, s8 text, void|int _col,
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

  // TRACE("count_escapes_behind(< %c)\n", rearview());

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
      push_token(TYPE_NEWLINE, "\n");
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
 if (WS[current()]) {
    int(0..) s = cursor;
    ::eat(WS);
    int diff = cursor - s;

    push_token(TYPE_WHITESPACE, data[s .. cursor - 1]);

    col += diff;
  }
}

protected void eat_ws_nl()
{
  if (WS[current()]) {
    eat_ws();
    eat_nl();
  }
}

protected void eat_comments()
{
  if (current() == COMMENT) {
    int(0..) s = cursor;
    read_to((< '\n', EOL >), false);
    push_token(TYPE_COMMENT, data[s .. cursor]);

    col += cursor - s;

    if (peek() == '\n') {
      next();
      col += 1;
      eat_nl();
    }
    else if (peek() == EOL) {
      TRACE("Peek EOL in eat_comments()\n");
      next();
      return;
    }

    eat_ws_nl();
  }
}

protected void read_literal_string()
{
  TRACE("read_literal_string()\n");
  String.Buffer b = String.Buffer();
}

protected void read_basic_string()
{
  TRACE(">>> read_basic_string(%c)\n", current());
  String.Buffer sb = String.Buffer();

  if (current() != '"') {
    SYNTAX_ERROR("Expected \" but got %c", current());
  }

  // Eat the "
  next();
  col += 1;

  int(0..) col_start = col; // Take the eaten " into account

  loop: while (!is_eol()) {
    switch (current()) {
      /* [ space ] / [ ! ] */
      case 0x20 .. 0x21: break;
      /* [ " ] Possibly end of string */
      case 0x22:
        /* Check for escapes here */
        if (rearview() != '\\') {
          curr_value = sb->get();
          push_token(TYPE_STRING, curr_value, col_start);
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

  TRACE("<<< read_basic_string(%c)\n", current());
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
  eat_nl_only(true);

  loop: while (!is_eol()) {
    switch (current()) {
      // newline
      case 0x0A: break;
      case 0x20 .. 0x5B:
        if (current() == 0x22) {
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
  String.Buffer sb = String.Buffer();

  int(0..) col_start = col + 1;

  loop: while (!is_eol()) {
    switch (current()) {
      case '0' .. '9': case 'a' .. 'z': case 'A' .. 'Z':
      case '_': case '-':
        sb->putchar(current());
        break;

      case STD_TABLE_CLOSE:
      case KEY_SEP:
      case WS_TAB:
      case WS_SPACE:
        /* Fall-through */
      case KEYVAL_SEP:
        curr_key = sb->get();
        push_token(TYPE_UNQUOTED_KEY, curr_key, col_start);
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
  // TRACE("read_value(%c)\n", c);

  if (c == '"' && peek() == '"' && peek(2) == '"') {
    read_multiline_string();
    // eat_nl();
  }
  else if (c == '"') {
    read_basic_string();
    // eat_nl();
  }
  else {
    error("Value starting with %c not implemented yet. ", c);
  }
}

protected void read_key_val()
{
  TRACE(">>> read_key_val()\n");

  switch (current()) {
    case '\'': read_literal_string(); break;
    case '"':  read_basic_string();   break;
    default:   read_unquoted_key();   break;
  }

  eat_ws();

  if (current() != KEYVAL_SEP) {
    error("Syntax error at line %d. Expected \"=\" after key %q got \"%c\".\n",
          current_lineno(), curr_key || "Unknown key", current());
  }

  push_token(TYPE_KEYVAL_SEP, "=");
  next();
  col += 1;
  eat_ws();
  read_value();

  TRACE("<<< read_key_val()\n");
}

protected void read_std_table(void|bool is_recurse)
{
  eat_ws();
  char c = current();

  TRACE(">> read_std_table(%c)\n", c);

  if (UNQUOTED_KEY_START[c]) {
    TRACE("Read unquoted key\n");
    read_unquoted_key();
  }
  else if (QUOTED_KEY_START[c]) {
    die("Read quoted key\n");
  }
  else {
    SYNTAX_ERROR("Illegal character: \"%c\"", c);
  }

  eat_ws();

  switch (current()) {
    case KEY_SEP:
      TRACE("key_sep: %d, %d\n", current_lineno(), current_column());
      push_token(TYPE_KEY_SEP, ".");
      next();
      col += 1;
      read_std_table();
      break;

    case STD_TABLE_CLOSE:
      /* Break and let begin_read_std_table() take care of the token */
      break;

    default:

      break;
  }

  TRACE("<< read_std_table(%c)\n", current());
}

protected void begin_read_std_table()
{
  TRACE(">> begin_read_std_table(%c)\n", current());
  if (current() != STD_TABLE_OPEN) {
    SYNTAX_ERROR("Expected [ got %c", current());
  }

  push_token(TYPE_STD_TABLE_OPEN, "[");
  next();
  col += 1;

  read_std_table();
  eat_ws();

  if (current() != STD_TABLE_CLOSE) {
    SYNTAX_ERROR("Expected ] got %c", current());
  }

  push_token(TYPE_STD_TABLE_CLOSE, "]");
  next();
  col += 1;

  eat_nl();

  TRACE("<< begin_read_std_table()\n");
}

array(Token) fold_whitespace()
{
  return filter(tokens, lambda (Token t) {
    return !t->is_a(TYPE_WHITESPACE|TYPE_NEWLINE|TYPE_COMMENT);
  });
}

array(Token) lex()
{
  if (is_eol()) {
    return tokens;
  }

  eat_nl();

  TRACE(">>> lex: \"%c\" (row: %d, col: %d)\n",
         current(), current_lineno(), current_column());

  if (is_eol()) {
    TRACE("Is eol\n");
    return tokens;
  }

  switch (current())
  {
    case STD_TABLE_OPEN:
      // [[
      if (peek() == STD_TABLE_OPEN) {
        die("Multitable\n");
      }
      else {
        begin_read_std_table();
      }
      return lex();

    // Key can start with [_0-9 a-Z"']
    case '\'': case '"': case '_':
    case '0' .. '9': case 'a' .. 'z': case 'A' .. 'Z':
      read_key_val();
      return lex();

    case ' ':
    case '\t':
      eat_ws_nl();
      return lex();

    default:
      TRACE("len: %O, cursor: %O, is_eol: %O\n",
            len, cursor, is_eol());
      SYNTAX_ERROR("Unexpexted character: \"%c\"", current());
      break;
  }

  return tokens;
}