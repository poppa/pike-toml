public enum Kind {
  K_NONE,
  K_KEY,
  K_VALUE,
  K_STD_TABLE_OPEN,
  K_STD_TABLE_CLOSE,
  K_ARRAY_OPEN,
  K_ARRAY_CLOSE,
  K_INLINE_TBL_OPEN,
  K_INLINE_TBL_CLOSE,
  K_STD_ARRAY_OPEN,
  K_STD_ARRAY_CLOSE,
}

public mapping(int:string) kind_map = ([
  K_NONE : "none",
  K_KEY : "key",
  K_VALUE : "value",
  K_STD_TABLE_OPEN : "std-table-open",
  K_STD_TABLE_CLOSE : "std-table-close",
  K_ARRAY_OPEN: "array-open",
  K_ARRAY_CLOSE: "array-close",
  K_INLINE_TBL_OPEN: "inline-table-open",
  K_INLINE_TBL_CLOSE: "inline-table-close",
  K_STD_ARRAY_OPEN: "std-array-open",
  K_STD_ARRAY_CLOSE: "std-array-close",
]);

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

public Token new(Kind kind, string value) {
  return Token(kind, value);
}

public variant Token new(Kind kind, string value, Modifier modifier) {
  return Token(kind, value, modifier);
}

public string kind_to_string(Kind kind) {
  return kind_map[kind];
}

protected string modifer_to_string(Modifier modifier) {
  array(string) s = ({});

  if ((modifier & M_QUOTED_STR) == M_QUOTED_STR) {
    s += ({ "quoted-string" });
  }

  if ((modifier & M_QUOTED_STR) == M_LITERAL_STR) {
    s += ({ "literal-string" });
  }

  if ((modifier & M_MULTILINE) == M_MULTILINE) {
    s += ({ "multiline" });
  }

  if ((modifier & M_NUMBER) == M_NUMBER) {
    s += ({ "number" });
  }

  if ((modifier & M_BOOLEAN) == M_BOOLEAN) {
    s += ({ "boolean" });
  }

  if ((modifier & M_DATE) == M_DATE) {
    s += ({ "date" });
  }

  if ((modifier & M_INT) == M_INT) {
    s += ({ "int" });
  }

  if ((modifier & M_FLOAT) == M_FLOAT) {
    s += ({ "float" });
  }

  if ((modifier & M_EXP) == M_EXP) {
    s += ({ "exp" });
  }

  if ((modifier & M_HEX) == M_HEX) {
    s += ({ "hex" });
  }

  if ((modifier & M_OCT) == M_OCT) {
    s += ({ "oct" });
  }

  if ((modifier & M_BIN) == M_BIN) {
    s += ({ "bin" });
  }

  if ((modifier & M_INF) == M_INF) {
    s += ({ "inf" });
  }

  if ((modifier & M_NAN) == M_NAN) {
    s += ({ "nan" });
  }

  if ((modifier & M_TIME) == M_TIME) {
    s += ({ "time" });
  }

  if ((modifier & M_DOTTED) == M_DOTTED) {
    s += ({ "dotted" });
  }

  return s * "|";
}

private function _kind_to_string = kind_to_string;
private function _modifier_to_string = modifer_to_string;

class Token {
  public Kind kind;
  public string value;
  public Modifier modifier;

  protected void create(Kind kind, string value) {
    this::kind = kind;
    this::value = value;
  }

  protected variant void create(
    Kind kind,
    string value,
    Modifier modifier
  ) {
    this::create(kind, value);
    this::modifier = modifier;
  }

  public bool is_key() {
    return is_kind(K_KEY);
  }

  public bool is_value(Modifier|void modifier) {
    bool is = is_kind(K_VALUE);

    if (is && modifier) {
      return is_modifier(modifier);
    }

    return is;
  }

  public bool is_standard_table_open() {
    return is_kind(K_STD_TABLE_OPEN);
  }

  public bool is_standard_table_close() {
    return is_kind(K_STD_TABLE_CLOSE);
  }

  public bool is_array_open() {
    return is_kind(K_ARRAY_OPEN);
  }

  public bool is_array_close() {
    return is_kind(K_ARRAY_CLOSE);
  }

  public bool is_inline_table_open() {
    return is_kind(K_INLINE_TBL_OPEN);
  }

  public bool is_inline_table_close() {
    return is_kind(K_INLINE_TBL_CLOSE);
  }

  public bool is_standard_array_open() {
    return is_kind(K_STD_TABLE_OPEN);
  }

  public bool is_standard_array_close() {
    return is_kind(K_STD_ARRAY_CLOSE);
  }

  public bool is_kind(Kind kind) {
    return this::kind == kind;
  }

  public bool is_modifier(Modifier modifier) {
    return (this::modifier & modifier) == modifier;
  }

  protected string modifer_to_string() {
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

    if (is_modifier(M_NUMBER)) {
      return render_number();
    } else if (is_modifier(M_DATE)) {
      return render_date();
    } else if (is_modifier(M_BOOLEAN)) {
      return value == "true";
    } else {
      return value;
    }
  }

  protected int|float render_number() {
    if (is_modifier(M_INT)) {
      return (int)value;
    }

    if (is_modifier(M_FLOAT) || is_modifier(M_EXP)) {
      return (float)value;
    }

    if (is_modifier(M_HEX)) {
      sscanf(value, "%D", int v);
      return v;
    }

    if (is_modifier(M_BIN)) {
      sscanf(value, "%D", int v);
      return v;
    }

    if (is_modifier(M_OCT)) {
      string tmp = replace(replace(value, "O", "o"), "o", "");
      sscanf(tmp, "%D", int v);
      return v;
    }

    error("Unhandled number type %O\n", modifer_to_string());
  }

  protected object(Calendar.Time)|object(Calendar.ISO) render_date() {
    return Calendar.dwim_time(value);
  }

  protected string _sprintf(int t) {
    if (modifier) {
      return sprintf(
        "%O(kind: %O:%O, value: %O)",
        this_program,
        kind_map[kind],
        modifer_to_string(),
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
