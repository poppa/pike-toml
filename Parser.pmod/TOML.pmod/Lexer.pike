#charset utf-8
#pike __REAL_VERSION__
#require constant(Regexp.PCRE.Widestring)

#include "lexer.h"

protected Stdio.File input;
protected int(0..) cursor = 0;
protected int(0..) line = 1;
protected int(0..) column = 1;
protected string current;
protected ADT.Queue token_queue = ADT.Queue();

protected void create(Stdio.File | string input) {
  if (stringp(input)) {
    input = Stdio.FakeFile(input);
  }

  this::input = input;
}

public string advance() {
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

public mixed lex() {
  if (sizeof(token_queue)) {
    return token_queue->get();
  }

  if (!advance()) {
    TRACE("End of file\n");
    return UNDEFINED;
  }

  TRACE("Current: %O\n", current);

  switch (current) {
    // Newline
    case "\n":
      return lex();

    // Space, tab, vtab
    case " ":
    case "\t":
    case "\v":
      return lex();

    // Comment start
    case "#":
      lex_comment();
      return lex();

    // Std table
    case "[":
      return lex_std_table();

    // It must be a key/value
    default:
      return lex_key_value();
  }

  error("Unexpected character %O\n", current);
}

protected .Token lex_key_value() {
  .Token key = lex_key();
  eat_whitespace();
  expect("=");
  eat_whitespace();
  .Token value = lex_value();

  token_queue->put(value);

  return key;
}

protected .Token lex_value() {
  switch (current[0]) {
    //
    // "    Quotation mark
    case 0x22: {
      string value = read_quoted_string();
      return .Token(.Token.K_VALUE, value, "quoted-string");
    } break;

    //
    // '    Apostrophe
    case 0x27: {
      string value = read_litteral_string();
      return .Token(.Token.K_VALUE, value, "literal-string");
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

protected .Token lex_literal_value() {
  // FIXME: Verfiy there are no more stop characters
  string data = read_until((< ",", "\n", " ", "\t", "\v", "#" >));

  if (has_value(data, "_")) {
    data = replace(data, "_", "");
  }

  if (data == "false" || data == "true") {
    return .Token(.Token.K_VALUE, data, "bool");
  } else if (re_int->match(data)) {
    return .Token(.Token.K_VALUE, data, "int");
  } else if (re_float->match(data)) {
    return .Token(.Token.K_VALUE, data, "float");
  } else if (re_exp->match(data)) {
    return .Token(.Token.K_VALUE, data, "exp");
  } else if (re_hex->match(data)) {
    return .Token(.Token.K_VALUE, data, "hex");
  } else if (re_oct->match(data)) {
    return .Token(.Token.K_VALUE, data, "oct");
  } else if (re_bin->match(data)) {
    return .Token(.Token.K_VALUE, data, "bin");
  } else if (re_inf->match(data)) {
    return .Token(.Token.K_VALUE, data, "inf");
  } else if (re_nan->match(data)) {
    return .Token(.Token.K_VALUE, data, "nan");
  } else if (re_local_time->match(data)) {
    return .Token(.Token.K_VALUE, data, "local-time");
  } else if (re_full_date->match(data)) {
    return .Token(.Token.K_VALUE, data, "full-date");
  } else if (re_local_date_time->match(data)) {
    return .Token(.Token.K_VALUE, data, "local-date-time");
  } else if (re_offset_date_time->match(data)) {
    return .Token(.Token.K_VALUE, data, "offset-date-time");
  }

  error("Unhandled value: %O\n", data);
}

protected .Token lex_std_table() {
  expect("[");

  .Token t = .Token(.Token.K_STD_TABLE_OPEN, "[");

  .Token key = lex_key();
  token_queue->put(key);

  if (current == ".") {
    key->modifier = "dotted";

    while (current == ".") {
      advance();
      .Token lt = lex_key();
      lt->modifier = "dotted";
      token_queue->put(lt);
    }
  }

  expect("]");

  token_queue->put(.Token(.Token.K_STD_TABLE_CLOSE, "]"));

  return t;
}

protected .Token lex_key() {
  string modifier;
  string value;

  switch (current[0]) {
    case '"':
      modifier = "quoted";
      value = read_quoted_string();
      break;

    case '\'':
      modifier = "literal";
      value = read_litteral_string();
      break;

    CASE_VALID_KEY_CHARS:
      value = read_unquoted_key();
      break;

    default:
      error("Unexpected character %O\n", current);
  }

  return .Token(.Token.K_KEY, value, modifier);
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

  // Let the main lex() method take care of newlines
  if (current == "\n") {
    push_back();
  }
}

protected void push_back(int n) {
  input->seek(-n, Stdio.SEEK_CUR);
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
  while ((<" ", "\t", "\v">)[current]) {
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
