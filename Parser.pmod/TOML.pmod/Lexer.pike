#ifdef TOML_LEXER_DEBUG
#  define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
#  define TRACE(X...) 0
#endif

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
  advance();
}

public string advance() {
  current = input->read(1);

  if (current != "") {
    column += 1;
    return current;
  }

  return UNDEFINED;
}

public mixed lex() {
  if (sizeof(token_queue)) {
    return token_queue->get();
  }

  advance();

  if (current == "") {
    werror("End of file\n");
    return UNDEFINED;
  }

  TRACE("Current: %O\n", current);

  switch (current) {
    case "\n":
      inc_line();
      return lex();

    // Space, vtab
    case " ":
    case "\v":
      return lex();

    case "#":
      lex_comment();
      return lex();

    case "[":
      return lex_std_table();
      break;
  }

  return 1;
}

protected .Token lex_std_table() {
  expect("[");
  advance();

  string key;
  string kind = "key";

  if (current == "\"") {
    exit(1, "Read quoted key\n");
  } else if (current == "'") {
    key = read_litteral_string();
    kind = "literalkey";
    expect("'");
    advance();
  } else {
    key = read_unquoted_key();

    while (current == ".") {
      advance();
      kind = "dottedkey";
      token_queue->put(.Token(kind, read_unquoted_key()));
    }
  }


  expect("]");

  return .Token(kind, key);
}

protected string read_unquoted_key() {
  String.Buffer buf = String.Buffer();
  function push = buf->add;

  while (!(< ".", "]" >)[current]) {
    switch (current[0]) {
      case '0'..'9':
      case 'A'..'Z':
      case 'a'..'z':
      case '-':
      case '_':
        push(current);
        advance();
        break;
      default:
        error("Unexpected character %O in key\n", current);
    }
  }

  expect((< ".", "]" >));

  return (string)buf;
}

protected string read_litteral_string() {
  expect("'");
  advance();

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

  return (string)buf;
}

protected string read_quoted_string() {
  expect("\"");
}

protected void lex_comment() {
  expect("#");

  while (advance()) {
    if (!current || current == "\n") {
      break;
    }
  }

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

protected void expect(string expected) {
  if (current != expected) {
    error("Expected %O got %O\n", expected, current);
  }
}

protected variant void expect(multiset expected) {
  if (!expected[current]) {
    error("Expected %O got %O\n", expected, current);
  }
}

protected void inc_line() {
  line += 1;
  column = 0;
}
