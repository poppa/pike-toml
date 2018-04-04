
#include "toml.h"

enum BaseType {
  T_NONE,       T_KEY,        T_KEY_SEP,      T_KEYVAL_SEP,
  T_VAL,        T_VAL_SEP,    T_NL,           T_WS,
  T_COMMENT,    T_MULTBL_O,   T_MULTBL_C,     T_STDTBL_O,
  T_STDTBL_C,   T_INLTBL_O,   T_INLTBL_C,     T_ARRAY_O,
  T_ARRAY_C,    T_ITEM_SEP,   T_ARRTBL_O,     T_ARRTBL_C,
  T_DEBUG,
}

mapping _basetype_to_str = ([
  T_NONE       : "T_NONE",
  T_KEY        : "T_KEY",
  T_KEY_SEP    : "T_KEY_SEP",
  T_KEYVAL_SEP : "T_KEYVAL_SEP",
  T_VAL        : "T_VAL",
  T_VAL_SEP    : "T_VAL_SEP",
  T_NL         : "T_NL",
  T_WS         : "T_WS",
  T_COMMENT    : "T_COMMENT",
  T_MULTBL_O   : "T_MULTBL_O",
  T_MULTBL_C   : "T_MULTBL_C",
  T_STDTBL_O   : "T_STDTBL_O",
  T_STDTBL_C   : "T_STDTBL_C",
  T_INLTBL_O   : "T_INLTBL_O",
  T_INLTBL_C   : "T_INLTBL_C",
  T_ARRAY_O    : "T_ARRAY_O",
  T_ARRAY_C    : "T_ARRAY_C",
  T_ITEM_SEP   : "T_ITEM_SEP",
  T_ARRTBL_O   : "T_ARRTBL_O",
  T_ARRTBL_C   : "T_ARRTBL_C",
  T_DEBUG      : "T_DEBUG",
]);

enum SubType {
  K_UNQUOTED,     K_QUOTED,     K_LITERAL,      V_STR,
  V_LITSTR,       V_MULSTR,     V_LITMULSTR,    V_INT,
  V_FLOAT,        V_HEX,        V_OCT,          V_BIN,
  V_BOOL,         V_DATE,       V_DATETIME,     V_TIME,
  V_INF,          V_NAN,
}

mapping _subtype_to_str = ([
  K_UNQUOTED  : "K_UNQUOTED",
  K_QUOTED    : "K_QUOTED",
  K_LITERAL   : "K_LITERAL",
  V_STR       : "V_STR",
  V_LITSTR    : "V_LITSTR",
  V_MULSTR    : "V_MULSTR",
  V_LITMULSTR : "V_LITMULSTR",
  V_INT       : "V_INT",
  V_FLOAT     : "V_FLOAT",
  V_HEX       : "V_HEX",
  V_OCT       : "V_OCT",
  V_BIN       : "V_BIN",
  V_BOOL      : "V_BOOL",
  V_DATE      : "V_DATE",
  V_DATETIME  : "V_DATETIME",
  V_TIME      : "V_TIME",
  V_INF       : "V_INF",
  V_NAN       : "V_NAN",
]);

class Token
{
  protected BaseType _type;
  protected SubType _sub;
  protected s8   _text;
  protected int  _line;
  protected int  _col;

  protected void create(BaseType type, SubType sub, s8 text,
                        int(1..) line, int(1..) col)
  {
    this::_type = type;
    this::_sub  = sub;
    this::_text = text;
    this::_line = line;
    this::_col  = col;
  }

  public BaseType `type()    { return _type; }
  public SubType  `subtype() { return _sub;  }
  public s8       `text()    { return _text; }
  public int      `line()    { return _line; }
  public int      `column()  { return _col;  }


  protected s8 _sprintf(int t)
  {
    return sprintf("%O(%O, \"%s\", %d, %d)",
      object_program(this),
      type_to_str(),
      shorten_text(_text),
      _line, _col);
  }

  protected s8 shorten_text(s8 t)
  {
    if (sizeof(t) > 20) {
      t = t[0..20] + " [...]";
    }

    if (search(t, "\n") > -1) {
      t = replace(t, "\n", "\\n");
    }

    return t;
  }

  protected s8 type_to_str()
  {
    s8 s = _basetype_to_str[_type];

    if (_sub) {
      s += " | " + _subtype_to_str[_sub];
    }

    return s;
  }

  bool is_a(BaseType t1, void|SubType t2)
  {
    if (_type != t1) {
      return false;
    }

    return _sub == t2;
  }
}
