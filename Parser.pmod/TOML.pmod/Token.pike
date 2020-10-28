public string kind;
public string value;
public string modifier;

protected void create(string kind, string value) {
  this::kind = kind;
  this::value = value;
}

protected variant void create(
  string kind,
  string value,
  string | int(0..0) modifier
) {
  this::create(kind, value);
  this::modifier = modifier;
}

protected string _sprintf(int t) {
  if (modifier) {
    return sprintf(
      "%O(kind: %O:%O, value: %O)", this_program, kind, modifier, value
    );
  } else {
    return sprintf("%O(kind: %O, value: %O)", this_program, kind, value);
  }
}
