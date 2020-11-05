#charset utf-8
#pike __REAL_VERSION__

class Kind {
  public enum Type {
    None,
    Key,
    Value,
    TableOpen,
    TableClose,
    InlineTableOpen,
    InlineTableClose,
    InlineArrayOpen,
    InlineArrayClose,
    TableArrayOpen,
    TableArrayClose,
  }
}

public mapping(int:string) kind_map = ([
  Kind.None : "none",
  Kind.Key : "key",
  Kind.Value : "value",
  Kind.TableOpen : "table-open",
  Kind.TableClose : "table-close",
  Kind.InlineTableOpen: "inline-table-open",
  Kind.InlineTableClose: "inline-table-close",
  Kind.InlineArrayOpen: "inline-array-open",
  Kind.InlineArrayClose: "inline-array-close",
  Kind.TableArrayOpen: "table-array-open",
  Kind.TableArrayClose: "table-array-close",
]);

class Modifier {
  public enum Type {
    None = 0,
    QuotedString  = 1 << 0,
    LiteralString = 1 << 1,
    Multiline   = 1 << 2,
    Number      = 1 << 3,
    Boolean     = 1 << 4,
    Date        = 1 << 5,
    Int         = 1 << 6,
    Float       = 1 << 7,
    Exp         = 1 << 8,
    Hex         = 1 << 9,
    Oct         = 1 << 10,
    Bin         = 1 << 11,
    Inf         = 1 << 12,
    Nan         = 1 << 13,
    Time        = 1 << 14,
    Dotted      = 1 << 15,
  }
}

public Token new(Kind.Type kind, string value) {
  return Token(kind, value);
}

public variant Token new(Kind.Type kind, string value, Modifier.Type modifier) {
  return Token(kind, value, modifier);
}

public string kind_to_string(Kind.Type kind) {
  return kind_map[kind];
}

public string modifier_to_string(Modifier.Type modifier) {
  array(string) s = ({});

  if ((modifier & Modifier.QuotedString) == Modifier.QuotedString) {
    s += ({ "quoted-string" });
  }

  if ((modifier & Modifier.LiteralString) == Modifier.LiteralString) {
    s += ({ "literal-string" });
  }

  if ((modifier & Modifier.Multiline) == Modifier.Multiline) {
    s += ({ "multiline" });
  }

  if ((modifier & Modifier.Number) == Modifier.Number) {
    s += ({ "number" });
  }

  if ((modifier & Modifier.Boolean) == Modifier.Boolean) {
    s += ({ "boolean" });
  }

  if ((modifier & Modifier.Date) == Modifier.Date) {
    s += ({ "date" });
  }

  if ((modifier & Modifier.Int) == Modifier.Int) {
    s += ({ "int" });
  }

  if ((modifier & Modifier.Float) == Modifier.Float) {
    s += ({ "float" });
  }

  if ((modifier & Modifier.Exp) == Modifier.Exp) {
    s += ({ "exp" });
  }

  if ((modifier & Modifier.Hex) == Modifier.Hex) {
    s += ({ "hex" });
  }

  if ((modifier & Modifier.Oct) == Modifier.Oct) {
    s += ({ "oct" });
  }

  if ((modifier & Modifier.Bin) == Modifier.Bin) {
    s += ({ "bin" });
  }

  if ((modifier & Modifier.Inf) == Modifier.Inf) {
    s += ({ "inf" });
  }

  if ((modifier & Modifier.Nan) == Modifier.Nan) {
    s += ({ "nan" });
  }

  if ((modifier & Modifier.Time) == Modifier.Time) {
    s += ({ "time" });
  }

  if ((modifier & Modifier.Dotted) == Modifier.Dotted) {
    s += ({ "dotted" });
  }

  return s * "|";
}

private function _kind_to_string = kind_to_string;
private function _modifier_to_string = modifier_to_string;

class Token {
  public Kind.Type kind;
  public string value;
  public Modifier.Type modifier;

  protected void create(Kind.Type kind, string value) {
    this::kind = kind;
    this::value = value;
  }

  protected variant void create(
    Kind.Type kind,
    string value,
    Modifier.Type modifier
  ) {
    this::create(kind, value);
    this::modifier = modifier;
  }

  public bool is_key() {
    return is_kind(Kind.Key);
  }

  public bool is_value(Modifier.Type|void modifier) {
    bool is = is_kind(Kind.Value);

    if (is && modifier) {
      return is_modifier(modifier);
    }

    return is;
  }

  public bool is_table_open() {
    return is_kind(Kind.TableOpen);
  }

  public bool is_table_close() {
    return is_kind(Kind.TableClose);
  }

  public bool is_inline_array_open() {
    return is_kind(Kind.InlineArrayOpen);
  }

  public bool is_inline_array_close() {
    return is_kind(Kind.InlineArrayClose);
  }

  public bool is_inline_table_open() {
    return is_kind(Kind.InlineTableOpen);
  }

  public bool is_inline_table_close() {
    return is_kind(Kind.InlineTableClose);
  }

  public bool is_table_array_open() {
    return is_kind(Kind.TableArrayOpen);
  }

  public bool is_table_array_close() {
    return is_kind(Kind.TableArrayClose);
  }

  public bool is_kind(Kind.Type kind) {
    return this::kind == kind;
  }

  public bool is_modifier(Modifier.Type modifier) {
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

    if (is_modifier(Modifier.Number)) {
      return render_number();
    } else if (is_modifier(Modifier.Date)) {
      return render_date();
    } else if (is_modifier(Modifier.Boolean)) {
      return value == "true";
    } else {
      return value;
    }
  }

  protected int|float|object(Int.inf) render_number() {
    if (is_modifier(Modifier.Int)) {
      return (int)value;
    }

    if (is_modifier(Modifier.Float) || is_modifier(Modifier.Exp)) {
      return (float)value;
    }

    if (
      is_modifier(Modifier.Hex) ||
      is_modifier(Modifier.Bin) ||
      is_modifier(Modifier.Oct)
    ) {
      sscanf(value, "%D", int v);
      return v;
    }

    if (is_modifier(Modifier.Inf)) {
      return Int.inf;
    }

    if (is_modifier(Modifier.Nan)) {
      return Math.nan;
    }

    error("Unhandled number type %O\n", modifier_to_string());
  }

  protected object(Calendar.Time)|object(Calendar.ISO) render_date() {
    if (is_modifier(Modifier.Time)) {
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
