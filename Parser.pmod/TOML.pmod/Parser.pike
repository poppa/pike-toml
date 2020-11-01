#charset utf-8
#pike __REAL_VERSION__

protected constant Lexer = .Lexer;
protected constant Token = .Token.Token;
protected constant Modifier = .Token.Modifier;
protected constant Kind = .Token.Kind;
protected typedef array(Token) TokenArray;
protected multiset(string) defined_paths = (<>);

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
      case Kind.Key: {
        Token val = lexer->lex();
        expect_value(val);

        if (!undefinedp(p[tok->value])) {
          error("Trying to overwrite existing value\n");
        }

        p[tok->value] = val->pike_value();
      } break;

      //
      // Handle std table
      case Kind.TableOpen: {
        TokenArray keys = read_keys(lexer);
        expect_kind(lexer->lex(), Kind.TableClose);

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
  array(string)|string path = ({});

  foreach (keys, Token t) {
    tmp = p[t->value];
    path += ({ t->value });

    if (!tmp) {
      tmp = p[t->value] = ([]);
    }

    p = tmp;
  }

  path = path * ".";

  if (defined_paths[path]) {
    error("Trying to redefine %q\n", path);
  }

  defined_paths[path] = true;

  return p;
}

protected TokenArray read_keys(Lexer lexer) {
  TokenArray out = ({});

  while (Token t = lexer->lex()) {
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

protected void expect_kind(Token t, Kind.Type kind) {
  if (!t->is_kind(kind)) {
    error("Expected kind %O, got %O\n", kind, t->kind);
  }
}
