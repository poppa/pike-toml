#charset utf-8
#pike __REAL_VERSION__

protected typedef array(mixed)|mapping(string:mixed) Container;
protected typedef array(Token) TokenArray;

protected constant Lexer = .Lexer;
protected constant Token = .Token.Token;
protected constant Modifier = .Token.Modifier;
protected constant Kind = .Token.Kind;
protected multiset(string) defined_paths = (<>);

protected multiset(Kind.Type) expect_as_value = (<
  Kind.Value,
  Kind.InlineArrayOpen,
  Kind.InlineTableOpen,
>);

protected multiset(Kind.Type) expect_as_key = (<
  Kind.Key,
  Kind.InlineArrayOpen,
  Kind.InlineTableOpen,
>);

public mapping parse_file(Stdio.File file) {
  return this::parse(Lexer(file));
}

public variant mapping parse_file(string path) {
  if (!Stdio.exist(path)) {
    error("Unknown file %q\n", path);
  }

  this::parse(Lexer(Stdio.File(path)));
}

public mapping parse_string(string toml_data) {
  return this::parse(Lexer(Stdio.FakeFile(toml_data)));
}

private Container current_container = ([]);

public mapping parse(Lexer lexer) {
  while (Token t = lexer->lex()) {
    switch (t->kind) {
      case Kind.Key:
        parse_key(t, lexer);
        break;
    }
  }

  werror("Curr container: %O\n", current_container);

  return current_container;
}

protected void parse_key(Token token, Lexer lexer) {
  if (!mappingp(current_container)) {
    error("Expected current_container to be a mapping");
  }

  expect_kind(token, Kind.Key);
  Token next = lexer->lex();
  expect_one_of(next, expect_as_value);

  mixed value;

  switch (next->kind) {
    case Kind.InlineArrayOpen:
      value = parse_inline_array(next, lexer);
      break;

    case Kind.InlineTableOpen:
      value = parse_inline_table(next, lexer);
      break;

    case Kind.Value:
      value = next->pike_value();
      break;
  }

  current_container[token->value] = value;
}

protected mapping(string:mixed) parse_inline_table(Token token, Lexer lexer) {
  expect_kind(token, Kind.InlineTableOpen);

  Container prev_container = current_container;
  mapping value = ([]);
  current_container = value;

  Token next;
  while (next = lexer->lex()) {
    if (next->is_inline_table_close()) {
      break;
    }

    expect_one_of(next, expect_as_key);

    switch (next->kind) {
      case Kind.Key:
        parse_key(next, lexer);
        break;

      case Kind.InlineArrayOpen:
        parse_inline_array(next, lexer);
        break;

      case Kind.InlineTableOpen:
        parse_inline_table(next, lexer);
        break;
    }
  }

  expect_kind(next, Kind.InlineTableClose);
  current_container = prev_container;

  return value;
}

protected array(mixed) parse_inline_array(Token token, Lexer lexer) {
  expect_kind(token, Kind.InlineArrayOpen);

  Container prev_container = current_container;
  array values = ({});
  current_container = values;
  Modifier.Type first_type;
  Token next;

  while (next = lexer->lex()) {
    if (next->is_inline_array_close()) {
      break;
    }

    expect_one_of(next, expect_as_value);

    if (!next->is_value()) {
      array|mapping v;
      if (next->is_inline_array_open()) {
        v = parse_inline_array(next, lexer);
      } else if (next->is_inline_table_open()) {
        v = parse_inline_table(next, lexer);
      }

      // FIXME: These have to type checks
      values += ({ v });
      continue;
    }

    if (!first_type) {
      first_type = next->is_string_value()
        ? .Token.Modifier.String
        :  next->modifier;
    } else {
      if (!.Token.has_modifier(next, first_type)) {
        error(
          "Array values must be of the same type. "
          "Array is typed as %O, got value of type %O\n",
          .Token.modifier_to_string(first_type),
          // .Token.modifier_to_string(next->modifier)
          next->modifier_to_string()
        );
      }
    }

    values += ({ next->pike_value() });
  }

  expect_kind(next, Kind.InlineArrayClose);
  current_container = prev_container;

  return values;
}

#if 0

public mixed parse(Lexer lexer) {
  mapping p = ([]);
  mapping top = p;

  while (Token tok = lexer->lex()) {
    switch (tok->kind) {
      //
      // Handle key
      case Kind.Key: {
        Token val = lexer->lex();
        expect_one_of(val, (<
          Kind.Value,
          Kind.InlineArrayOpen,
          Kind.InlineTableOpen
        >));

        if (val->is_value()) {
          if (!undefinedp(p[tok->value])) {
            error("Trying to overwrite existing value\n");
          }

          p[tok->value] = val->pike_value();
        } else {
          werror("Handle some shit now\n");
          exit(0);
        }

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

#endif

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
    error(
      "Expected kind %O, got %O\n",
      .Token.kind_to_string(kind),
      t->kind_to_string()
    );
  }
}

protected void expect_one_of(Token t, multiset(Kind.Type) kinds) {
  if (!kinds[t->kind]) {
    error(
      "Expected kind of %q, got %O\n",
      String.implode_nicely(map((array)kinds, .Token.kind_to_string), "or"),
      t->kind_to_string()
    );
  }
}
