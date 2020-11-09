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
    None       = 0,
    String     = 1 << 0,
    Quoted     = 1 << 1,
    Literal    = 1 << 2,
    Multiline  = 1 << 3,
    Number     = 1 << 4,
    Boolean    = 1 << 5,
    Date       = 1 << 6,
    Int        = 1 << 7,
    Float      = 1 << 8,
    Exp        = 1 << 9,
    Hex        = 1 << 10,
    Oct        = 1 << 11,
    Bin        = 1 << 12,
    Inf        = 1 << 13,
    Nan        = 1 << 14,
    Time       = 1 << 15,
    Dotted     = 1 << 16,
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

  if ((modifier & Modifier.String) == Modifier.String) {
    s += ({ "string" });
  }

  if ((modifier & Modifier.Quoted) == Modifier.Quoted) {
    s += ({ "quoted" });
  }

  if ((modifier & Modifier.Literal) == Modifier.Literal) {
    s += ({ "literal" });
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

public bool is_string_value(Token token) {
  return token->is_value() && has_modifier(token, Modifier.String);
}

public bool has_modifier(Token token, Modifier.Type modifier) {
  return (token->modifier & modifier) == modifier;
}

private function _kind_to_string = kind_to_string;
private function _modifier_to_string = modifier_to_string;
private function _is_string_value = is_string_value;

private string re_ymd_s = "\\d{4}-\\d{2}-\\d{2}";
private string re_hms_s = "\\d{2}:\\d{2}:\\d{2}";
private string re_frac_s = "\\.\\d+";
private string re_tz_s = "([Zz]|[-+]\\d{2}:\\d{2})";

#define RE Regexp.PCRE.Widestring

private RE re_ymds_frac_tz =
  RE("^" + re_ymd_s + "[Tt ]" + re_hms_s + re_frac_s + re_tz_s + "$");
private RE re_ymds_frac =
  RE("^" + re_ymd_s + "[Tt ]" + re_hms_s + re_frac_s + "$");
private RE re_ymds_tz =
  RE("^" + re_ymd_s + "[Tt ]" + re_hms_s + re_tz_s + "$");
private RE re_ymds =
  RE("^" + re_ymd_s + "[Tt ]" + re_hms_s + "$");

private RE re_time_frac_tz = RE("^" + re_hms_s + re_frac_s + re_tz_s + "$");
private RE re_time_frac = RE("^" + re_hms_s + re_frac_s + "$");
private RE re_time_tz = RE("^" + re_hms_s + re_tz_s + "$");
private RE re_time = RE("^" + re_hms_s + "$");

public class Position {
  public int line;
  public int column;

  protected void create(int line, int column) {
    this::line = line;
    this::column = column;
  }
}

public class Token {
  public Kind.Type kind;
  public string value;
  public Modifier.Type modifier;
  public Position position;

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

  protected variant void create(
    Kind.Type kind,
    string value,
    Position position
  ) {
    this::create(kind, value);
    this::position = position;
  }

  protected variant void create(
    Kind.Type kind,
    string value,
    Modifier.Type modifier,
    Position position
  ) {
    this::create(kind, value, modifier);
    this::position = position;
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

  public bool is_string_value() {
    return _is_string_value(this);
  }

  public string modifier_to_string() {
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
      return utf8_to_string(value);
    }

    if (is_modifier(Modifier.Number)) {
      return render_number();
    } else if (is_modifier(Modifier.Date)) {
      return render_date();
    } else if (is_modifier(Modifier.Boolean)) {
      return value == "true";
    } else {
      return string_to_utf8(value);
    }
  }

  protected int|float|object(Int.inf) render_number() {
    if (is_modifier(Modifier.Int)) {
      return (int)value;
    }

    if (is_modifier(Modifier.Exp)) {
      // FIXME: Do we need to use Gmp.mpf() here in some cases?
      return (float)value;
    }

    if (is_modifier(Modifier.Float)) {
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
      if (value == "-inf") {
        return -Int.inf;
      }

      return Int.inf;
    }

    if (is_modifier(Modifier.Nan)) {
      if (value == "-nan") {
        return -Math.nan;
      }

      return Math.nan;
    }

    error("Unhandled number type %O\n", modifier_to_string());
  }

  protected object(Calendar.Time)|object(Calendar.ISO) render_date() {
    if (is_modifier(Modifier.Time)) {
      string fmt = get_calendar_parse_string();
      Calendar.Second ret;

      if (mixed err = catch(ret = Calendar.parse(fmt, value))) {
        error(
          "Failed to convert time %q to time object: %s\n",
          value,
          describe_error(err)
        );
      }

      return ret;
    } else {
      return Calendar.dwim_day(value);
    }
  }

  protected string get_calendar_parse_string() {
    if (re_ymds_frac_tz->match(value)) {
      return "%Y-%M-%D%[T ]%h:%m:%s.%f%z";
    }

    if (re_ymds_frac->match(value)) {
      return "%Y-%M-%D%[T ]%h:%m:%s.%f";
    }

    if (re_ymds_tz->match(value)) {
      return "%Y-%M-%D%[T ]%h:%m:%s%z";
    }

    if (re_ymds->match(value)) {
      return "%Y-%M-%D%[T ]%h:%m:%s";
    }

    if (re_time_frac_tz->match(value)) {
      return "%h:%m:%s.%f%z";
    }

    if (re_time_frac->match(value)) {
      return "%h:%m:%s.%f";
    }

    if (re_time_tz->match(value)) {
      return "%h:%m:%s%z";
    }

    if (re_time->match(value)) {
      return "%h:%m:%s";
    }

    error("Unknown date format %O\n", value);
  }

  protected string _sprintf(int t) {
    string ln = position
      ? sprintf(" @%d:%d", position->line, position->column)
      : "";

    if (modifier) {
      return sprintf(
        "%O(kind: %O:%O, value: %O%s)",
        this_program,
        kind_map[kind],
        modifier_to_string(),
        value,
        ln
      );
    } else {
      return sprintf(
        "%O(kind: %O, value: %O%s)",
        this_program,
        kind_map[kind],
        value,
        ln
      );
    }
  }
}
