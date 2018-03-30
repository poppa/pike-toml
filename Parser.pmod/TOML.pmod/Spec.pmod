constant WS_TAB   = '\t';
constant WS_SPACE = ' ';
constant NEWLINE  = '\n';

constant WS   = (< WS_SPACE, WS_TAB >);
constant QUOT = (< '\'', '"' >);
constant ESC  = (< '\\' >);

constant COMMENT    = '#';
constant KEYVAL_SEP = '=';
constant KEY_SEP    = '.';

constant ALPHA_DOWN = (<
  'a','b','c','d','e','f','g','h','i','j','k','l','m',
  'n','o','p','q','r','s','t','u','v','w','x','y','z' >);

constant ALPHA_UP = (<
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z' >);

constant DIGIT = (< '0','1','2','3','4','5','6','7','8','9' >);

constant ALNUM = ALPHA_DOWN + ALPHA_UP + DIGIT;

// [
constant STD_TABLE_OPEN = 0x5B;
// ]
constant STD_TABLE_CLOSE = 0x5D;

constant UNQUOTED_KEY       = ALNUM + (< '_', '-' >);
constant UNQUOTED_KEY_START = UNQUOTED_KEY;
constant QUOTED_KEY_START   = (< '"', '\'' >);
constant KEY_START          = UNQUOTED_KEY_START + QUOTED_KEY_START;

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
