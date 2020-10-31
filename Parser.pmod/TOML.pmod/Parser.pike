private mapping v = ([]);

protected constant Lexer = .Lexer;
protected constant Token = .Token.Token;
protected typedef array(Token) TokenArray;

public mixed parse_file(Stdio.File file) {
  return this::parse(Lexer(file));
}

public variant mixed parse_file(string path) {
  if (!Stdio.exist(path)) {
    error("Unknown file %q\n", path);
  }

  this::parse(Lexer(Stdio.File(path)));
}

public mixed parse_string(string toml_data) {
  return this::parse(Lexer(Stdio.FakeFile(toml_data)));
}

public mixed parse(Lexer lexer) {
  mapping p = ([]);
  mapping top = p;

  while (Token tok = lexer->lex()) {
    switch (tok->kind) {
      //
      // Handle key
      case .Token.K_KEY: {
        Token val = lexer->lex();
        expect_value(val);
        p[tok->value] = val->pike_value();
      } break;

      //
      // Handle std table
      case .Token.K_STD_TABLE_OPEN: {
        TokenArray keys = read_keys(lexer);
        expect_kind(lexer->lex(), .Token.K_STD_TABLE_CLOSE);

        p = mkmapping(top, keys);

        if (!sizeof(indices(p))) {
          top = p + top;
        }
      } break;

      //
      // Don't dare getting here
      default:
        exit(1, "%O not implemented yet\n", tok);
    }
  }

  werror("Converted: %O\n", top);
}

protected mapping mkmapping(mapping old, TokenArray keys) {
  mapping p = old;
  mapping tmp = ([]);

  foreach (keys, Token t) {
    tmp = p[t->value];

    if (!tmp) {
      tmp = p[t->value] = ([]);
      p = tmp;
    } else {
      p = tmp;
    }
  }

  return p;
}

protected TokenArray read_keys(Lexer lexer) {
  TokenArray out = ({});

  while (.Token t = lexer->lex()) {
    out += ({ t });

    if (!lexer->peek_token()->is_key()) {
      break;
    }
  }

  return out;
}

protected void expect_value(Token t) {
  if (!t->is_value()) {
    error("Expected a value token, got %O\n", t->kind_to_string());
  }
}

protected void expect_kind(Token t, .Token.Kind kind) {
  if (!t->is_kind(kind)) {
    error("Expected kind %O, got %O\n", kind, t->kind);
  }
}
