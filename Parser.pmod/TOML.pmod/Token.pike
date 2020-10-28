public enum Kind {
  K_NONE,
  K_KEY,
  K_VALUE,
  K_STD_TABLE_OPEN,
  K_STD_TABLE_CLOSE,
}

public mapping(int:string) kind_map = ([
  K_NONE : "none",
  K_KEY : "key",
  K_VALUE : "value",
  K_STD_TABLE_OPEN : "std-table-open",
  K_STD_TABLE_CLOSE : "std-table-close",
]);

public enum Modifier {
  M_NONE = 0,
}

public Kind kind;
public string value;
public string modifier;

protected void create(Kind kind, string value) {
  this::kind = kind;
  this::value = value;
}

protected variant void create(
  Kind kind,
  string value,
  string | int(0..0) modifier
) {
  this::create(kind, value);
  this::modifier = modifier;
}

protected string _sprintf(int t) {
  if (modifier) {
    return sprintf(
      "%O(kind: %O:%O, value: %O)",
      this_program,
      kind_map[kind],
      modifier,
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
