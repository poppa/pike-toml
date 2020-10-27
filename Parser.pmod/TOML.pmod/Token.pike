public string kind;
public string value;

protected void create(string kind, string value) {
  this::kind = kind;
  this::value = value;
}

protected string _sprintf(int t) {
  return sprintf("%O(kind: %O, value: %O)", this_program, kind, value);
}
