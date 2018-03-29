
constant WS   = (< ' ', '\t' >);
constant QUOT = (< '\'', '"' >);
constant ESC  = (< '\\' >);

// Escape sequence according to spec
constant ESC_SEQ = (<
  0x22, //  "    quotation mark  U+0022
  0x5C, //  \    reverse solidus U+005C
  0x2F, //  /    solidus         U+002F
  0x62, //  b    backspace       U+0008
  0x66, //  f    form feed       U+000C
  0x6E, //  n    line feed       U+000A
  0x72, //  r    carriage return U+000D
  0x74, //  t    tab             U+0009
  0x75, //  uXXXX                U+XXXX
  0x55, //  UXXXXXXXX            U+XXXXXXXX
>);
