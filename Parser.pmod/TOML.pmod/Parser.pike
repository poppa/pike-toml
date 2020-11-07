#charset utf-8
#pike __REAL_VERSION__

#define KIND(K) .Token.Kind. ## K
#define MOD(M) .Token.Modifier. ## M
#define TOKEN .Token.Token

protected typedef RefArray|mapping(string:mixed) Container;
protected typedef array(TOKEN) TokenArray;

protected multiset(string) defined_paths = (<>);

protected multiset(KIND(Type)) expect_as_value = (<
  KIND(Value),
  KIND(InlineArrayOpen),
  KIND(InlineTableOpen),
>);

protected multiset(KIND(Type)) expect_as_key = (<
  KIND(Key),
  KIND(InlineArrayOpen),
  KIND(InlineTableOpen),
>);

public mapping parse_file(Stdio.File file) {
  return this::parse(.Lexer(file));
}

public variant mapping parse_file(string path) {
  if (!Stdio.exist(path)) {
    error("Unknown file %q\n", path);
  }

  return this::parse(.Lexer(Stdio.File(path, "r")));
}

public mapping parse_string(string toml_data) {
  return this::parse(.Lexer(Stdio.FakeFile(toml_data)));
}

private Container current_container;
private mapping top;

public mapping parse(.Lexer lexer) {
  current_container = ([]);
  top = current_container;

  while (TOKEN t = lexer->lex()) {
    switch (t->kind) {
      case KIND(Key):
        parse_key(t, lexer);
        break;

      case KIND(TableOpen):
        parse_table_open(t, lexer);
        break;

      case KIND(TableArrayOpen):
        parse_table_array_open(t, lexer);
        break;
    }
  }

  normalize_result();

  return top;
}

protected void normalize_result() {
  void mapit(mapping m) {
    foreach (m; string key; mixed val) {
      if (is_ref_array(val)) {
        m[key] = (array)val;
      } else if (mappingp(val)) {
        this_function(val);
      }
    }
  };

  mapit(top);
}

protected void parse_table_array_open(TOKEN token, .Lexer lexer) {
  expect_kind(token, KIND(TableArrayOpen));
  TokenArray keys = read_keys(lexer);
  RefArray a = mkarray(top, keys);
  expect_kind(lexer->lex(), KIND(TableArrayClose));

  mapping c = ([]);
  Container old_container = current_container;
  current_container = c;

  TOKEN next = lexer->lex();

  do {
    expect_one_of(next, (< KIND(Key) >));
    parse_key(next, lexer);
    TOKEN peek = lexer->peek_token();

    if (!peek || !peek->is_key()) {
      break;
    }
  } while (next = lexer->lex());

  current_container = old_container;
  a += ({ c });
}

protected void parse_table_open(TOKEN token, .Lexer lexer) {
  expect_kind(token, KIND(TableOpen));

  TokenArray keys = read_keys(lexer);
  mapping m = this::mkmapping(top, keys);
  current_container = m;

  expect_kind(lexer->lex(), KIND(TableClose));
}

protected void parse_key(TOKEN token, .Lexer lexer) {
  if (!mappingp(current_container)) {
    error("Expected current_container to be a mapping\n");
  }

  expect_kind(token, KIND(Key));
  TOKEN next = lexer->lex();
  expect_one_of(next, expect_as_value);

  mixed value;

  switch (next->kind) {
    case KIND(InlineArrayOpen):
      value = parse_inline_array(next, lexer);
      break;

    case KIND(InlineTableOpen):
      value = parse_inline_table(next, lexer);
      break;

    case KIND(Value):
      value = next->pike_value();
      break;
  }

  current_container[token->value] = value;
}

protected mapping(string:mixed) parse_inline_table(TOKEN token, .Lexer lexer) {
  expect_kind(token, KIND(InlineTableOpen));

  Container prev_container = current_container;
  mapping value = ([]);
  current_container = value;

  TOKEN next;
  while (next = lexer->lex()) {
    if (next->is_inline_table_close()) {
      break;
    }

    expect_one_of(next, expect_as_key);

    switch (next->kind) {
      case KIND(Key):
        parse_key(next, lexer);
        break;

      case KIND(InlineArrayOpen):
        parse_inline_array(next, lexer);
        break;

      case KIND(InlineTableOpen):
        parse_inline_table(next, lexer);
        break;
    }
  }

  expect_kind(next, KIND(InlineTableClose));
  current_container = prev_container;

  return value;
}

protected RefArray parse_inline_array(TOKEN token, .Lexer lexer) {
  expect_kind(token, KIND(InlineArrayOpen));

  Container prev_container = current_container;
  RefArray values = RefArray();
  current_container = values;
  .Token.Modifier.Type first_type;
  TOKEN next;

  while (next = lexer->lex()) {
    if (next->is_inline_array_close()) {
      break;
    }

    expect_one_of(next, expect_as_value);

    if (!next->is_value()) {
      Container v;

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
        ? MOD(String)
        : next->modifier;
    } else {
      if (!.Token.has_modifier(next, first_type)) {
        error(
          "Array values must be of the same type. "
          "Array is typed as %O, got value of type %O\n",
          .Token.modifier_to_string(first_type),
          next->modifier_to_string()
        );
      }
    }

    values += ({ next->pike_value() });
  }

  expect_kind(next, KIND(InlineArrayClose));
  current_container = prev_container;

  return values;
}

protected mapping mkmapping(mapping old, TokenArray keys) {
  mapping p = old;
  mapping tmp = ([]);
  array(string)|string path = ({});

  foreach (keys, TOKEN t) {
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

protected RefArray mkarray(mapping old, TokenArray keys) {
  Container p = old;
  Container tmp = p;
  array(string)|string path = ({});

  int len = sizeof(keys);

  for (int i; i < len; i++) {
    if (is_ref_array(p)) {
      error("Badly nested table array\n");
    }

    TOKEN k = keys[i];
    tmp = p[k->value];
    path += ({ k->value });

    if (!tmp) {
      tmp = p[k->value] = (i == len - 1) ? RefArray() : ([]);
    }

    p = tmp;
  }

  if (!is_ref_array(p)) {
    error("mkarray expexted an array but got %O\n", p);
  }

  path = path * ".";
  defined_paths[path] = true;

  return p;
}

protected TokenArray read_keys(.Lexer lexer) {
  TokenArray out = ({});

  while (TOKEN t = lexer->lex()) {
    out += ({ t });

    if (!lexer->peek_token()->is_key()) {
      break;
    }
  }

  return out;
}

protected void expect_value(TOKEN t) {
  if (!t->is_value()) {
    error("Expected a value token, got %O\n", t->kind_to_string());
  }
}

protected void expect_kind(TOKEN t, int /*.Token.Kind.Type*/ kind) {
  if (!t->is_kind(kind)) {
    error(
      "Expected kind %O, got %O\n",
      .Token.kind_to_string(kind),
      t->kind_to_string()
    );
  }
}

protected void expect_one_of(
  TOKEN t,
  multiset(int /*.Token.Kind.Type*/) kinds
) {
  if (!kinds[t->kind]) {
    error(
      "Expected kind of %q, got %O\n",
      String.implode_nicely(map((array)kinds, .Token.kind_to_string), "or"),
      t->kind_to_string()
    );
  }
}

protected bool is_ref_array(mixed o) {
  return objectp(o) && object_program(o) == RefArray;
}

protected class RefArray {
  protected array data = ({});

  public mixed `+(array value) {
    data += value;
    return this;
  }

  public mixed `[](int idx) {
    if (has_index(data, idx)) {
      return data[idx];
    }

    error("Array out of index %O\n", idx);
  }

  protected array(int) _indices() {
    return indices(data);
  }

  protected array(mixed) _values() {
    return values(data);
  }

  protected mixed cast(string how) {
    switch (how) {
      case "array":
        return data;

      case "int":
        return sizeof(data);
    }

    error("Cant cast %O to %O\n", object_program(this), how);
  }

  protected int _sizeof() {
    return sizeof(data);
  }

  protected string _sprintf() {
    return sprintf("%O(%O)", object_program(this), data);
    // return sprintf("%O", (array)this);
  }
}
