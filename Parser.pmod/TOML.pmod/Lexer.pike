#charset utf-8
#pike __REAL_VERSION__
#require constant(Regexp.PCRE.Widestring)

// Defines and macros

#define KIND(K) .Token.Kind. ## K
#define MOD(M) .Token.Modifier. ## M
#define TOKEN .Token.Token
#define POSITION .Token.Position

#define REGEX Regexp.PCRE.Widestring
#define RegexpOption Regexp.PCRE.OPTION

#define CASE_VALID_KEY_CHARS \
  case '-':                  \
  case '0'..'9':             \
  case 'A'..'Z':             \
  case '_':                  \
  case 'a'..'z'

// "    quotation mark     U+0022
// \    reverse solidus    U+005C
// /    solidus            U+002F
// b    backspace          U+0008
// f    form feed          U+000C
// n    line feed          U+000A
// r    carriage return    U+000
// t    tab                U+0009
// u    uXXXX              U+XXXX
// U    UXXXXXXXX          U+XXXXXXXX
#define CASE_ESCAPE_CHARS_SEQ \
  case 0x22:                  \
  case 0x5C:                  \
  case 0x2F:                  \
  case 0x62:                  \
  case 0x66:                  \
  case 0x6E:                  \
  case 0x72:                  \
  case 0x74:                  \
  case 0x75:                  \
  case 0x55

#define CASE_UNICODE_ESCAPE   \
  case 0x55:                  \
  case 0x75

#define CASE_NON_ASCII        \
    case 0x80..0xD7FF:        \
    case 0xE000..0x10FFFF

#define SET_STATE_KEY() lex_state = STATE_KEY
#define SET_STATE_VALUE() lex_state = STATE_VALUE
#define IS_STATE_KEY() lex_state == STATE_KEY
#define IS_STATE_VALUE() lex_state == STATE_VALUE
#define QUOTE_CHAR "\""
#define ESC_CHAR "\\"

#define POSITION_ERROR(A...)          \
  error(                              \
    "%s in \"%s:%d:%d\"\n",           \
    sprintf(A),                       \
    input_source(),                   \
    line,                             \
    column                            \
  )

#define POP_CTX_STACK()         \
  do {                          \
    if (sizeof(ctx_stack)) {    \
      ctx_stack->pop();         \
    }                           \
  } while (0)

#define EAT_COMMENT()                             \
  do {                                            \
    eat_whitespace_and_newline();                 \
    while (current == "#") {                      \
      lex_comment();                              \
      eat_whitespace_and_newline();               \
    }                                             \
  } while (0)

protected enum LexState {
  STATE_NONE,
  STATE_KEY,
  STATE_VALUE,
}

protected enum Ctx {
  CTX_NONE,
  CTX_ARRAY,
  CTX_TABLE,
}

protected Stdio.File input;
protected int(0..) cursor = 0;
protected int(0..) line = 1;
protected int(0..) column = 0;
protected string current;
protected ADT.Queue token_queue = ADT.Queue();
protected ADT.Queue peek_queue = ADT.Queue();
protected ADT.Stack ctx_stack = ADT.Stack();
protected LexState lex_state = STATE_KEY;

// Regexp strings
protected string float_p = "[-+]?(0\\.|[1-9][0-9]*\\.)[0-9]+";
protected string int_p = "(0|[1-9][0-9]*)";
protected string full_date
  = "(\\d{4})" + "-" // year
  + "(0[1-9]|1[0-2])" + "-" // month
  + "(0[1-9]|[1-2][0-9]|3[0-1])"; // day
protected string time_hour = "(0\\d|1\\d|2[0-3])";
protected string time_minute = "([0-5]\\d)";
protected string time_second = "([0-6]\\d(\\.\\d+)?)"; // Allow for leap-sec
protected string partial_time
  = time_hour + ":"
  + time_minute + ":"
  + time_second;
protected string local_date_time
  = full_date
  + "[T]" // We don't handle space atm.
  + partial_time;
protected string offset_date_time
  = local_date_time
  + "(Z|[+-]"
  + time_hour + ":"
  + time_minute + ")";

// Regexps
protected REGEX re_int = REGEX("^[-+]?" + int_p + "$");
protected REGEX re_float = REGEX("^[-+]?" + float_p + "$");
protected REGEX re_exp = REGEX("^[-+]?(" + int_p + "|" + float_p + ")[eE][-+]?[0-9]+");
protected REGEX re_hex = REGEX("^[-+]?0x[0-9A-F]+$", RegexpOption.CASELESS);
protected REGEX re_oct = REGEX("^[-+]?0o[0-7]+$");
protected REGEX re_bin = REGEX("^[-+]?0b[0-1]+$");
protected REGEX re_inf = REGEX("^[-+]?inf$");
protected REGEX re_nan = REGEX("^[-+]?nan$");

protected REGEX re_local_time = REGEX("^(" + partial_time + ")$");
protected REGEX re_full_date = REGEX("^(" + full_date + ")$");
protected REGEX re_local_date_time = REGEX("^(" + local_date_time + ")$");
protected REGEX re_offset_date_time = REGEX("^(" + offset_date_time + ")$" );

protected void create(Stdio.File | string input) {
  if (stringp(input)) {
    input = Stdio.FakeFile(input);
  }

  this::input = input;
}

public TOKEN peek_token() {
  TOKEN t = lex();
  peek_queue->put(t);
  return t;
}

public mixed lex() {
  if (sizeof(peek_queue)) {
    return peek_queue->get();
  }

  if (sizeof(token_queue)) {
    return token_queue->get();
  }

  if (!advance()) {
    return UNDEFINED;
  }

  EAT_COMMENT();

  if (current == "" || !current) {
    return UNDEFINED;
  }

  if (sizeof(ctx_stack)) {
    int top = ctx_stack->top();

    if (top == CTX_ARRAY) {
      lex_state = STATE_VALUE;
    }
  }

  switch (current) {
    case "}": {
      POP_CTX_STACK();
      SET_STATE_KEY();
      return TOKEN(KIND(InlineTableClose), "}", get_pos());
    } break;

    case "]": {
      POP_CTX_STACK();
      SET_STATE_KEY();
      return TOKEN(KIND(InlineArrayClose), "]", get_pos());
    } break;

    case ",": {
      return lex();
    } break;

    // Std table / array
    case "[": {
      if (IS_STATE_KEY()) {
        if (peek() == "[") {
          return lex_std_array();
        }

        return lex_std_table();
      } else if (IS_STATE_VALUE()) {
        TOKEN tok = lex_value();
        return tok;
      }
    }

    // It must be a key/value
    default: {
      if (IS_STATE_KEY()) {
        TOKEN tok = lex_key();
        return tok;
      } else if (IS_STATE_VALUE()) {
        TOKEN tok = lex_value();

        if (current) {
          push_back();
        }

        SET_STATE_KEY();
        return tok;
      }
    }
  }

  POSITION_ERROR("Unexpected character %O", current);
}

protected string advance() {
  current = input->read(1);

  if (current != "") {
    column += 1;

    if (current == "\n") {
      inc_line();
    }

    return current;
  }

  return current = UNDEFINED;
}

protected TOKEN lex_key() {
  TOKEN key = lex_std_key(true);

  // FIXME: Same as in lex_inline_table()
  expect("=", true);

  SET_STATE_VALUE();

  return key;
}

protected TOKEN lex_value() {
  POSITION pos = get_pos();

  switch (current[0]) {
    //
    // [    Array start
    case 0x5b: {
      return lex_array_value();
    } break;

    //
    // {    Inline table start
    case 0x7b: {
      return lex_inline_table();
    } break;

    //
    // "    Quotation mark
    case 0x22: {
      if (peek(2) == QUOTE_CHAR + QUOTE_CHAR) {
        string value = read_multiline_quoted_string();
        return value_token(
          value,
          MOD(String) | MOD(Quoted) | MOD(Multiline),
          pos
        );
      }

      string value = read_quoted_string();

      return value_token(value, MOD(String) | MOD(Quoted), pos);
    } break;

    //
    // '    Apostrophe
    case 0x27: {
      if (peek(2) == "''") {
        string value = read_multiline_literal_string();
        return value_token(
          value,
          MOD(String) | MOD(Literal) | MOD(Multiline),
          pos
        );
      }

      string value = read_litteral_string();
      return value_token(value, MOD(String) | MOD(Literal), pos);
    } break;

    //
    // Meat of the potato
    case 0x2b:          // +    Plus sign
    case 0x2d:          // -    Minus sign
    case 0x6e:          // n    Expect nan
    case 0x66:          // f    Expect boolean false
    case 0x69:          // i    Expect inf
    case 0x74:          // t    Expect boolean true
    case 0x30..0x39: {  // 0-9  Int / Float / Date
      return lex_literal_value();
    } break;
  }

  POSITION_ERROR("Unhandled value character %O", current);
}

protected TOKEN lex_inline_table() {
  POSITION pos = get_pos();
  expect("{", true);

  TOKEN tok_ret = TOKEN(KIND(InlineTableOpen), "{", pos);
  SET_STATE_KEY();
  ctx_stack->push(CTX_TABLE);

  // FIXME: This is needed since we do a push_back() after lexing a value.
  //        Find a solution where none of this is neccessary.
  advance();

  return tok_ret;
}

protected TOKEN lex_array_value() {
  POSITION pos = get_pos();
  expect("[", true);

  TOKEN ret = TOKEN(KIND(InlineArrayOpen), "[", pos);
  SET_STATE_VALUE();
  ctx_stack->push(CTX_ARRAY);

  return ret;
}

protected TOKEN lex_literal_value() {
  POSITION pos = get_pos();
  // FIXME: Verfiy there are no more stop characters
  string data = read_until((< ",", "\n", " ", "\t", "\v", "#", "]", "}" >));

  if (has_value(data, "_")) {
    data = replace(data, "_", "");
  }

  if (data == "false" || data == "true") {
    return value_token(data, MOD(Boolean), pos);
  } else if (re_int->match(data)) {
    return value_token(data, MOD(Number)|MOD(Int), pos);
  } else if (re_float->match(data)) {
    return value_token(data, MOD(Number)|MOD(Float), pos);
  } else if (re_exp->match(data)) {
    return value_token(data, MOD(Number)|MOD(Exp), pos);
  } else if (re_hex->match(data)) {
    return value_token(data, MOD(Number)|MOD(Hex), pos);
  } else if (re_oct->match(data)) {
    return value_token(replace(data, "o", ""), MOD(Number)|MOD(Oct), pos);
  } else if (re_bin->match(data)) {
    return value_token(data, MOD(Number)|MOD(Bin), pos);
  } else if (re_inf->match(data)) {
    return value_token(data, MOD(Number)|MOD(Inf), pos);
  } else if (re_nan->match(data)) {
    return value_token(data, MOD(Number)|MOD(Nan), pos);
  } else if (re_local_time->match(data)) {
    return value_token(data, MOD(Date)|MOD(Time), pos);
  } else if (re_full_date->match(data)) {
    return value_token(data, MOD(Date), pos);
  } else if (re_local_date_time->match(data)) {
    return value_token(data, MOD(Date)|MOD(Time), pos);
  } else if (re_offset_date_time->match(data)) {
    return value_token(data, MOD(Date)|MOD(Time), pos);
  }

  POSITION_ERROR("Unhandled value %O", data);
}

protected TOKEN lex_std_array() {
  POSITION pos = get_pos();
  expect("[");
  expect("[");

  TOKEN tok_open = TOKEN(KIND(TableArrayOpen), "[[", pos);
  lex_std_key();
  expect("]");
  expect("]", true);

  token_queue->put(TOKEN(KIND(TableArrayClose), "]]"));

  return tok_open;
}

protected TOKEN lex_std_table() {
  POSITION pos = get_pos();
  expect("[");
  TOKEN tok_open = TOKEN(KIND(TableOpen), "[", pos);
  lex_std_key();
  pos = get_pos();
  expect("]", false);

  token_queue->put(TOKEN(KIND(TableClose), "]", pos));

  return tok_open;
}

protected TOKEN lex_std_key(bool no_push) {
  eat_whitespace();
  TOKEN key = lex_key_low();

  if (no_push == false) {
    token_queue->put(key);
  }

  if (current == ".") {
    key->modifier = MOD(Dotted);

    while (current == ".") {
      advance();
      TOKEN lt = lex_key_low();
      lt->modifier = key->modifier;
      token_queue->put(lt);
    }
  }

  eat_whitespace();
  return key;
}

protected variant TOKEN lex_std_key() {
  return this::lex_std_key(false);
}

protected TOKEN lex_key_low() {
  .Token.Modifier.Type modifier;
  string value;

  eat_whitespace();

  POSITION pos = get_pos();

  switch (current[0]) {
    case '"':
      modifier = MOD(String) | MOD(Quoted);
      value = read_quoted_string();
      break;

    case '\'':
      modifier = MOD(String) | MOD(Literal);
      value = read_litteral_string();
      break;

    CASE_VALID_KEY_CHARS:
      value = read_unquoted_key();
      break;

    default:
      POSITION_ERROR("Unexpected character %O", current);
  }

  eat_whitespace();

  return TOKEN(KIND(Key), value, modifier, pos);
}

protected string read_unquoted_key() {
  String.Buffer buf = String.Buffer();
  function push = buf->add;

  loop: while (current) {
    switch (current[0]) {
      CASE_VALID_KEY_CHARS:
        push(current);
        advance();
        break;
      default:
        break loop;
    }
  }

  return (string)buf;
}

protected string read_litteral_string() {
  expect("'");

  String.Buffer buf = String.Buffer();
  function push = buf->add;

  while (current != "'") {
    switch (current[0]) {
      case 0x09:
      case 0x20..0x26:
      case 0x28..0x10FFFF:
        push(current);
        advance();
        break;

      default:
        POSITION_ERROR("Unexpected character %O in literal string", current);
    }
  }

  expect("'");

  return (string)buf;
}

protected string read_quoted_string() {
  expect("\"", true);

  String.Buffer buf = String.Buffer();
  function push = buf->add;

  while (advance()) {
    if (!current) {
      POSITION_ERROR("Unterminated string literal");
    }

    if (current == QUOTE_CHAR) {
      break;
    }

    if (decode_escacpe_sequence(buf)) {
      continue;
    }

    switch (current[0]) {
      case 0x09..0x0D:
      case 0x20..0x21:
      case 0x23..0x5B:
      case 0x5D..0x7E:
      CASE_NON_ASCII:
        push(current);
        break;
      default:
        POSITION_ERROR("Unhandled character %O", current);
    }
  }

  expect("\"");

  return (string)buf;
}

protected bool is_escape_char(string|int c) {
  if (stringp(c)) {
    c = c[0];
  }

  switch (c) {
    CASE_ESCAPE_CHARS_SEQ:
      return true;
    default:
      return false;
  }
}

protected int|string escape_char_to_literal(int c) {
  switch (c) {
    case '\\': return ESC_CHAR;
    case '"':  return "\"";
    case 'b':  return '\b';
    case 'f':  return '\f';
    case 'n':  return '\n';
    case 'r':  return '\r';
    case 't':  return '\t';
    default: POSITION_ERROR("Unhandled escape character \"%c\"", c);
  }
}

protected bool is_unicode_escape(string|int c) {
  if (stringp(c)) {
    c = c[0];
  }

  switch (c) {
    CASE_UNICODE_ESCAPE:
      return true;

    default:
      return false;
  }
}

// FIXME: Adhere to ABNF
protected string read_multiline_quoted_string() {
  expect(QUOTE_CHAR);
  expect(QUOTE_CHAR);
  expect(QUOTE_CHAR);

  String.Buffer buf = String.Buffer();
  function push = buf->add;

  eat_current_newline();
  push_back();

  while (advance()) {
    eat_extraneous_whitespace();

    if (current == QUOTE_CHAR && peek(2) == QUOTE_CHAR + QUOTE_CHAR) {
      break;
    }

    if (decode_escacpe_sequence(buf)) {
      continue;
    }

    push(current);
  }

  expect(QUOTE_CHAR);
  expect(QUOTE_CHAR);
  expect(QUOTE_CHAR);

  return (string)buf;
}

protected void eat_extraneous_whitespace() {
  if (current == ESC_CHAR && peek() == "\n") {
    advance();
    eat_whitespace_and_newline();
    eat_extraneous_whitespace();
  }
}

// FIXME: Adhere to ABNF
protected string read_multiline_literal_string() {
  expect("'");
  expect("'");
  expect("'");

  String.Buffer buf = String.Buffer();
  function push = buf->add;

  eat_current_newline();
  push_back();

  while (advance()) {
    if (current == "'" && peek(2) == "''") {
      break;
    }

    if (current[0] == '\0') {
      POSITION_ERROR("Illegal escape char %q in literal string", current);
    }

    push(current);
  }

  expect("'");
  expect("'");
  expect("'");

  return (string)buf;
}

protected void lex_comment() {
  expect("#", true);

  while (advance()) {
    if (!current || current == "\n") {
      break;
    }
  }
}

protected string look() {
  string r = input->read(1);
  input->seek(-1, Stdio.SEEK_CUR);
  return r;
}

protected void push_back(int n) {
  int p = input->seek(-n, Stdio.SEEK_CUR);

  // FIXME: This isn't fool-proof in any way
  if (p >= 0 && look() == "\n") {
    line -= 1;
    column = 0;
  } else {
    column -= n;
  }
}

protected variant void push_back() {
  push_back(1);
}

protected void expect(string expected, bool no_advance) {
  if (current != expected) {
    POSITION_ERROR("Expected %O got %O", expected, current);
  }

  if (!no_advance) {
    advance();
  }
}

protected variant void expect(multiset expected, bool no_advance) {
  if (!expected[current]) {
    POSITION_ERROR("Expected %O got %O", expected, current);
  }

  if (!no_advance) {
    advance();
  }
}

protected variant void expect(string expected) {
  this::expect(expected, false);
}

protected variant void expect(multiset expected) {
  this::expect(expected, false);
}

protected void inc_line() {
  line += 1;
  column = 0;
}

protected string look_behind(int(0..) n_chars, int(0..) length) {
  int org_pos = input->tell();
  input->seek(-(n_chars + 1), Stdio.SEEK_CUR);
  string c = input->read(length);
  input->seek(org_pos, Stdio.SEEK_SET);

  return c;
}

protected variant string look_behind(int(0..) n_chars) {
  return this::look_behind(n_chars, 1);
}

protected variant string look_behind() {
  return this::look_behind(1, 1);
}

protected void eat_whitespace() {
  while ((< " ", "\t", "\v" >)[current]) {
    advance();
  }
}

protected void eat_whitespace_and_newline() {
  while ((< " ", "\t", "\v", "\n" >)[current]) {
    advance();
  }
}

protected void eat_newline() {
  while (current == "\n") {
    advance();
  }
}

protected void eat_current_newline() {
  if (current == "\n") {
    advance();
  }
}

protected string read_n_chars(int(0..) len) {
  string buf = current;
  int i = 0;

  for (int i = 0; i < len; i++) {
    buf += advance();

    if (!current) {
      POSITION_ERROR("Unexpected end of file");
    }
  }

  return buf;
}

protected string read_until(multiset(string) chars) {
  string buf = current;

  while (current) {
    advance();

    if (!current || chars[current]) {
      break;
    }

    buf += current;
  }

  return buf;
}

protected string peek(int(0..) | void n) {
  if (undefinedp(n) || n <= 0) {
    n = 1;
  }

  int pos = input->tell();
  string v = input->read(n);
  input->seek(pos, Stdio.SEEK_SET);

  return v;
}

protected TOKEN value_token(
  string value,
  /*.Token.Modifier.Type*/ int|void modifier,
  POSITION|void pos
) {
  return TOKEN(KIND(Value), value, modifier, pos);
}

protected POSITION get_pos() {
  return POSITION(line, column);
}

//! Returns the input source. If the input source was a file on disk the
//! the path is returns, else @code{stdin@} is returned.
public string input_source() {
  if (object_program(input) == Stdio.FakeFile) {
    return "stdin";
  } else {
    string o = sprintf("%O", input);
    sscanf(o, "%*s\"%s\"", string filename);
    return filename ? filename : "stdin";
  }
}

protected inline bool decode_escacpe_sequence(String.Buffer buf) {
  if (current == ESC_CHAR) {
    string next = peek();

    if (!is_escape_char(next)) {
      POSITION_ERROR("Illegal escape sequence %O", next);
    }

    if (is_unicode_escape(next)) {
      advance();
      advance();

      string s = "0x" + (next == "u" ? read_n_chars(3) : read_n_chars(7));

      sscanf(s, "%x", int ch);

      if (!Unicode.is_wordchar(ch)) {
        POSITION_ERROR("Invalid unicode character \"%c\"", ch);
      }

      buf->putchar(ch);

      return true;
    }

    int|string c = escape_char_to_literal(next[0]);

    if (intp(c)) {
      buf->putchar(c);
    } else {
      buf->add(c);
    }

    advance();

    return true;
  }

  return false;
}
