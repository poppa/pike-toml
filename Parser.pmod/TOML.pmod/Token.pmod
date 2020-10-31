#charset utf-8
#pike __REAL_VERSION__

class Kind {
  public enum Kind {
    K_NONE,
    K_KEY,
    K_VALUE,
    K_TABLE_OPEN,
    K_TABLE_CLOSE,
    K_INLINE_TABLE_OPEN,
    K_INLINE_TABLE_CLOSE,
    K_INLINE_ARRAY_OPEN,
    K_INLINE_ARRAY_CLOSE,
    K_TABLE_ARRAY_OPEN,
    K_TABLE_ARRAY_CLOSE,
  }
}

public mapping(int:string) kind_map = ([
  Kind.K_NONE : "none",
  Kind.K_KEY : "key",
  Kind.K_VALUE : "value",
  Kind.K_TABLE_OPEN : "table-open",
  Kind.K_TABLE_CLOSE : "table-close",
  Kind.K_INLINE_TABLE_OPEN: "inline-table-open",
  Kind.K_INLINE_TABLE_CLOSE: "inline-table-close",
  Kind.K_INLINE_ARRAY_OPEN: "inline-array-open",
  Kind.K_INLINE_ARRAY_CLOSE: "inline-array-close",
  Kind.K_TABLE_ARRAY_OPEN: "table-array-open",
  Kind.K_TABLE_ARRAY_CLOSE: "table-array-close",
]);

class Modifier {
  public enum Modifier {
    M_NONE = 0,
    M_QUOTED_STR  = 1 << 0,
    M_LITERAL_STR = 1 << 1,
    M_MULTILINE   = 1 << 2,
    M_NUMBER      = 1 << 3,
    M_BOOLEAN     = 1 << 4,
    M_DATE        = 1 << 5,
    M_INT         = 1 << 6,
    M_FLOAT       = 1 << 7,
    M_EXP         = 1 << 8,
    M_HEX         = 1 << 9,
    M_OCT         = 1 << 10,
    M_BIN         = 1 << 11,
    M_INF         = 1 << 12,
    M_NAN         = 1 << 13,
    M_TIME        = 1 << 14,
    M_DOTTED      = 1 << 15,
  }
}

public Token new(Kind.Kind kind, string value) {
  return Token(kind, value);
}

public variant Token new(Kind.Kind kind, string value, Modifier.Modifier modifier) {
  return Token(kind, value, modifier);
}

public string kind_to_string(Kind.Kind kind) {
  return kind_map[kind];
}

protected string modifier_to_string(Modifier.Modifier modifier) {
  array(string) s = ({});

  if ((modifier & Modifier.M_QUOTED_STR) == Modifier.M_QUOTED_STR) {
    s += ({ "quoted-string" });
  }

  if ((modifier & Modifier.M_LITERAL_STR) == Modifier.M_LITERAL_STR) {
    s += ({ "literal-string" });
  }

  if ((modifier & Modifier.M_MULTILINE) == Modifier.M_MULTILINE) {
    s += ({ "multiline" });
  }

  if ((modifier & Modifier.M_NUMBER) == Modifier.M_NUMBER) {
    s += ({ "number" });
  }

  if ((modifier & Modifier.M_BOOLEAN) == Modifier.M_BOOLEAN) {
    s += ({ "boolean" });
  }

  if ((modifier & Modifier.M_DATE) == Modifier.M_DATE) {
    s += ({ "date" });
  }

  if ((modifier & Modifier.M_INT) == Modifier.M_INT) {
    s += ({ "int" });
  }

  if ((modifier & Modifier.M_FLOAT) == Modifier.M_FLOAT) {
    s += ({ "float" });
  }

  if ((modifier & Modifier.M_EXP) == Modifier.M_EXP) {
    s += ({ "exp" });
  }

  if ((modifier & Modifier.M_HEX) == Modifier.M_HEX) {
    s += ({ "hex" });
  }

  if ((modifier & Modifier.M_OCT) == Modifier.M_OCT) {
    s += ({ "oct" });
  }

  if ((modifier & Modifier.M_BIN) == Modifier.M_BIN) {
    s += ({ "bin" });
  }

  if ((modifier & Modifier.M_INF) == Modifier.M_INF) {
    s += ({ "inf" });
  }

  if ((modifier & Modifier.M_NAN) == Modifier.M_NAN) {
    s += ({ "nan" });
  }

  if ((modifier & Modifier.M_TIME) == Modifier.M_TIME) {
    s += ({ "time" });
  }

  if ((modifier & Modifier.M_DOTTED) == Modifier.M_DOTTED) {
    s += ({ "dotted" });
  }

  return s * "|";
}

private function _kind_to_string = kind_to_string;
private function _modifier_to_string = modifier_to_string;

class Token {
  public Kind.Kind kind;
  public string value;
  public Modifier.Modifier modifier;

  protected void create(Kind.Kind kind, string value) {
    this::kind = kind;
    this::value = value;
  }

  protected variant void create(
    Kind.Kind kind,
    string value,
    Modifier.Modifier modifier
  ) {
    this::create(kind, value);
    this::modifier = modifier;
  }

  public bool is_key() {
    return is_kind(Kind.K_KEY);
  }

  public bool is_value(Modifier.Modifier|void modifier) {
    bool is = is_kind(Kind.K_VALUE);

    if (is && modifier) {
      return is_modifier(modifier);
    }

    return is;
  }

  public bool is_standard_table_open() {
    return is_kind(Kind.K_TABLE_OPEN);
  }

  public bool is_standard_table_close() {
    return is_kind(Kind.K_TABLE_CLOSE);
  }

  public bool is_array_open() {
    return is_kind(Kind.K_INLINE_ARRAY_OPEN);
  }

  public bool is_array_close() {
    return is_kind(Kind.K_INLINE_ARRAY_CLOSE);
  }

  public bool is_inline_table_open() {
    return is_kind(Kind.K_INLINE_TABLE_OPEN);
  }

  public bool is_inline_table_close() {
    return is_kind(Kind.K_INLINE_TABLE_CLOSE);
  }

  public bool is_standard_array_open() {
    return is_kind(Kind.K_TABLE_OPEN);
  }

  public bool is_standard_array_close() {
    return is_kind(Kind.K_TABLE_ARRAY_CLOSE);
  }

  public bool is_kind(Kind.Kind kind) {
    return this::kind == kind;
  }

  public bool is_modifier(Modifier.Modifier modifier) {
    return (this::modifier & modifier) == modifier;
  }

  protected string modifier_to_string() {
    return _modifier_to_string(modifier);
  }

  public string kind_to_string() {
    return _kind_to_string(kind);
  }

  public int
    | float
    | object(Calendar.Time)
    | object(Calendar.ISO)
    | string(8bit)
    | bool pike_value()
  {
    if (!is_value()) {
      return value;
    }

    if (is_modifier(Modifier.M_NUMBER)) {
      return render_number();
    } else if (is_modifier(Modifier.M_DATE)) {
      return render_date();
    } else if (is_modifier(Modifier.M_BOOLEAN)) {
      return value == "true";
    } else {
      return value;
    }
  }

  protected int|float render_number() {
    if (is_modifier(Modifier.M_INT)) {
      return (int)value;
    }

    if (is_modifier(Modifier.M_FLOAT) || is_modifier(Modifier.M_EXP)) {
      return (float)value;
    }

    if (is_modifier(Modifier.M_HEX)) {
      sscanf(value, "%D", int v);
      return v;
    }

    if (is_modifier(Modifier.M_BIN)) {
      sscanf(value, "%D", int v);
      return v;
    }

    if (is_modifier(Modifier.M_OCT)) {
      string tmp = replace(replace(value, "O", "o"), "o", "");
      sscanf(tmp, "%D", int v);
      return v;
    }

    error("Unhandled number type %O\n", modifier_to_string());
  }

  protected object(Calendar.Time)|object(Calendar.ISO) render_date() {
    if (is_modifier(Modifier.M_TIME)) {
      return Calendar.dwim_time(value);
    } else {
      return Calendar.dwim_day(value);
    }
  }

  protected string _sprintf(int t) {
    if (modifier) {
      return sprintf(
        "%O(kind: %O:%O, value: %O)",
        this_program,
        kind_map[kind],
        modifier_to_string(),
        value
      );
    } else {
      return sprintf(
        "%O(kind: %O, value: %O)",
        this_program,
        kind_map[kind],
        value
      );
    }
  }
}
