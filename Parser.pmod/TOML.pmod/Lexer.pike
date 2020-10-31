#charset utf-8
#pike __REAL_VERSION__
#require constant(Regexp.PCRE.Widestring)

// Defines and macros
#define REGEX Regexp.PCRE.Widestring
#define RegexpOption Regexp.PCRE.OPTION

#define CASE_VALID_KEY_CHARS \
  case '-':                  \
  case '0'..'9':             \
  case 'A'..'Z':             \
  case '_':                  \
  case 'a'..'z'

#define SET_STATE_KEY() lex_state = STATE_KEY
#define SET_STATE_VALUE() lex_state = STATE_VALUE
#define IS_STATE_KEY() lex_state == STATE_KEY
#define IS_STATE_VALUE() lex_state == STATE_VALUE

#define POP_CTX_STACK()         \
  do {                          \
    if (sizeof(ctx_stack)) {    \
      ctx_stack->pop();         \
    }                           \
  } while (0)

#define EAT_COMMENT()                             \
  do {                                            \
    eat_whitespace_and_nl();                      \
    while (current == "#") {                      \
      lex_comment();                              \
      eat_whitespace_and_nl();                    \
    }                                             \
  } while (0)

private constant Token = .Token.Token;

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
protected int(0..) column = 1;
protected string current;
protected ADT.Queue token_queue = ADT.Queue();
protected ADT.Queue peek_queue = ADT.Queue();
protected ADT.Stack ctx_stack = ADT.Stack();
protected LexState lex_state = STATE_KEY;

// Regexp strings
protected string float_p = "[-+]?(0\\.|[1-9][0-9]*\\.)[0-9]+";
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
  + "[+-]"
  + time_hour + ":"
  + time_minute;

// Regexps
protected REGEX re_int = REGEX("^[-+]?(0|[1-9][0-9]*)$");
protected REGEX re_float = REGEX("^[-+]?" + float_p + "$");
protected REGEX re_exp = REGEX("^[-+]?" + float_p + "[eE]-?[0-9]+");
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

public Token peek_token() {
  Token t = lex();
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

  if (current == "") {
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
      return Token(.Token.K_INLINE_TABLE_CLOSE, "}");
    } break;

    case "]": {
      POP_CTX_STACK();
      SET_STATE_KEY();
      return Token(.Token.K_INLINE_ARRAY_CLOSE, "]");
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
        Token tok = lex_value();
        return tok;
      }
    }

    // It must be a key/value
    default: {
      if (IS_STATE_KEY()) {
        Token tok = lex_key();
        return tok;
      } else if (IS_STATE_VALUE()) {
        Token tok = lex_value();
        push_back();
        SET_STATE_KEY();
        return tok;
      }
    }
  }

  error("Unexpected character %O\n", current);
}

protected string advance() {
  current = input->read(1);

  if (current != "") {
    if (current == "\n") {
      inc_line();
    }

    column += 1;
    return current;
  }

  return UNDEFINED;
}

protected Token lex_key() {
  Token key = lex_key_low();
  eat_whitespace();
  // FIXME: Same as in lex_inline_table()
  expect("=", true);

  SET_STATE_VALUE();

  return key;
}

protected Token lex_value() {
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
      if (peek(2) == "\"\"") {
        string value = read_multiline_quoted_string();
        return value_token(value, .Token.M_QUOTED_STR | .Token.M_MULTILINE);
      }

      string value = read_quoted_string();

      return value_token(value, .Token.M_QUOTED_STR);
    } break;

    //
    // '    Apostrophe
    case 0x27: {
      if (peek(2) == "''") {
        string value = read_multiline_literal_string();
        return value_token(value, .Token.M_LITERAL_STR | .Token.M_MULTILINE);
      }

      string value = read_litteral_string();
      return value_token(value, .Token.M_LITERAL_STR);
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

  exit(1, "Lex value\n");
}

protected Token lex_inline_table() {
  expect("{", true);

  Token tok_ret = Token(.Token.K_INLINE_TABLE_OPEN, "{");
  SET_STATE_KEY();
  ctx_stack->push(CTX_TABLE);

  // FIXME: This is needed since we do a push_back() after lexing a value.
  //        Find a solution where none of this is neccessary.
  advance();

  return tok_ret;
}

protected Token lex_array_value() {
  expect("[", true);

  Token ret = Token(.Token.K_INLINE_ARRAY_OPEN, "[");
  SET_STATE_VALUE();
  ctx_stack->push(CTX_ARRAY);

  return ret;
}

protected Token lex_literal_value() {
  // FIXME: Verfiy there are no more stop characters
  string data = read_until((< ",", "\n", " ", "\t", "\v", "#", "]", "}" >));

  if (has_value(data, "_")) {
    data = replace(data, "_", "");
  }

  if (data == "false" || data == "true") {
    return value_token(data, .Token.M_BOOLEAN);
  } else if (re_int->match(data)) {
    return value_token(data, .Token.M_NUMBER | .Token.M_INT);
  } else if (re_float->match(data)) {
    return value_token(data, .Token.M_NUMBER | .Token.M_FLOAT);
  } else if (re_exp->match(data)) {
    return value_token(data, .Token.M_NUMBER | .Token.M_EXP);
  } else if (re_hex->match(data)) {
    return value_token(data, .Token.M_NUMBER | .Token.M_HEX);
  } else if (re_oct->match(data)) {
    return value_token(data, .Token.M_NUMBER | .Token.M_OCT);
  } else if (re_bin->match(data)) {
    return value_token(data, .Token.M_NUMBER | .Token.M_BIN);
  } else if (re_inf->match(data)) {
    return value_token(data, .Token.M_NUMBER | .Token.M_INF);
  } else if (re_nan->match(data)) {
    return value_token(data, .Token.M_NUMBER | .Token.M_NAN);
  } else if (re_local_time->match(data)) {
    return value_token(data, .Token.M_DATE | .Token.M_TIME);
  } else if (re_full_date->match(data)) {
    return value_token(data, .Token.M_DATE);
  } else if (re_local_date_time->match(data)) {
    return value_token(data, .Token.M_DATE | .Token.M_TIME);
  } else if (re_offset_date_time->match(data)) {
    return value_token(data, .Token.M_DATE | .Token.M_TIME);
  }

  error("Unhandled value: %O\n", data);
}

protected Token lex_std_array() {
  expect("[");
  expect("[");

  Token tok_open = Token(.Token.K_TABLE_ARRAY_OPEN, "[[");
  lex_std_key();
  expect("]");
  expect("]", true);

  token_queue->put(Token(.Token.K_TABLE_ARRAY_CLOSE, "]]"));

  return tok_open;
}

protected Token lex_std_table() {
  expect("[");
  Token tok_open = Token(.Token.K_TABLE_OPEN, "[");
  lex_std_key();
  expect("]", false);

  token_queue->put(Token(.Token.K_TABLE_CLOSE, "]"));

  return tok_open;
}

protected void lex_std_key() {
  eat_whitespace();
  Token key = lex_key_low();
  token_queue->put(key);

  if (current == ".") {
    key->modifier = .Token.M_DOTTED;

    while (current == ".") {
      advance();
      Token lt = lex_key_low();
      lt->modifier = key->modifier;
      token_queue->put(lt);
    }
  }

  eat_whitespace();
}

protected Token lex_key_low() {
  .Token.Modifier modifier;
  string value;

  eat_whitespace();

  switch (current[0]) {
    case '"':
      modifier = .Token.M_QUOTED_STR;
      value = read_quoted_string();
      break;

    case '\'':
      modifier = .Token.M_LITERAL_STR;
      value = read_litteral_string();
      break;

    CASE_VALID_KEY_CHARS:
      value = read_unquoted_key();
      break;

    default:
      error("Unexpected character %O\n", current);
  }

  eat_whitespace();

  return Token(.Token.K_KEY, value, modifier);
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
        error("Unexpected character %O in literal string\n", current);
    }
  }

  expect("'");

  return (string)buf;
}

protected string read_quoted_string() {
  expect("\"", true);

  String.Buffer buf = String.Buffer();
  function push = buf->add;

  do {
    advance();

    if (!current) {
      error("Unterminated string literal\n");
    }

    if (current == "\\") {
      do {
        string v = read_escape_chars();
        push(v);
      } while(current == "\\");
    }

    switch (current[0]) {
      case 0x20..0x21:
      case 0x23..0x5B:
      case 0x5D..0x7E:
      case 0x80..0x10FFFF:
        push(current);
        break;
    }
  } while (current != "\"");

  expect("\"");

  return (string)buf;
}

// FIXME: Adhere to ABNF
protected string read_multiline_quoted_string() {
  expect("\"");
  expect("\"");
  expect("\"");

  String.Buffer buf = String.Buffer();
  function push = buf->add;

  while (current) {
    if (current == "\"" && peek(2) == "\"\"") {
      break;
    }

    push(current);
    advance();
  }

  expect("\"");
  expect("\"");
  expect("\"");

  return (string)buf;
}

// FIXME: Adhere to ABNF
protected string read_multiline_literal_string() {
  expect("'");
  expect("'");
  expect("'");

  String.Buffer buf = String.Buffer();
  function push = buf->add;

  while (current) {
    if (current == "'" && peek(2) == "''") {
      break;
    }

    push(current);
    advance();
  }

  expect("'");
  expect("'");
  expect("'");

  return (string)buf;
}

protected string read_escape_chars() {
  expect("\\");

  switch (current[0]) {
    case 0x22: // "    quotation mark     U+0022
    case 0x5C: // \    reverse solidus    U+005C
    case 0x2F: // /    solidus            U+002F
    case 0x62: // b    backspace          U+0008
    case 0x66: // f    form feed          U+000C
    case 0x6E: // n    line feed          U+000A
    case 0x72: // r    carriage return    U+000D
    case 0x74: // t    tab                U+0009
      string v = current;
      advance();
      return "\\" + v;
      break;
    case 0x75: // uXXXX                U+XXXX
      error("Unicode not implemented yet\n");
      break;
    case 0x55: // UXXXXXXXX            U+XXXXXXXX
      error("Unicode not implemented yet\n");
      break;

    default:
      error("Expected escape sequence character, got %O\n", current);
  }
}

protected void lex_comment() {
  expect("#", true);

  while (advance()) {
    if (!current || current == "\n") {
      break;
    }
  }
}

protected void push_back(int n) {
  input->seek(-n, Stdio.SEEK_CUR);
  column -= n;
}

protected variant void push_back() {
  push_back(1);
}

protected void expect(string expected, bool no_advance) {
  if (current != expected) {
    error("Expected %O got %O\n", expected, current);
  }

  if (!no_advance) {
    advance();
  }
}

protected variant void expect(multiset expected, bool no_advance) {
  if (!expected[current]) {
    error("Expected %O got %O\n", expected, current);
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

protected void eat_whitespace_and_nl() {
  while ((< " ", "\t", "\v", "\n" >)[current]) {
    advance();
  }
}

protected string read_n_chars(int(0..) len) {
  string buf = current;
  int i = 0;

  for (int i = 0; i < len; i++) {
    buf += advance();

    if (!current) {
      error("Unexpected end of file\n");
    }
  }

  return buf;
}

protected string read_until(multiset(string) chars) {
  string buf = current;

  while (current) {
    advance();

    if (chars[current] || !current) {
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

protected Token value_token(
  string value,
  .Token.Modifier|void modifier
) {
  return Token(.Token.K_VALUE, value, modifier);
}
