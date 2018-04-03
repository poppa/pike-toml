
#include "toml.h"

#if 0
enum Type {
  TYPE_NONE            = 0,
  TYPE_KEY             = 1 << 0,
  TYPE_UNQUOTED_KEY    = 1 << 1,
  TYPE_QUOTED_KEY      = 1 << 2,
  TYPE_DOTTED_KEY      = 1 << 3,
  TYPE_KEYVAL_SEP      = 1 << 4,
  TYPE_WHITESPACE      = 1 << 5,
  TYPE_NEWLINE         = 1 << 6,
  TYPE_STRING          = 1 << 7,
  TYPE_M_STRING        = 1 << 8,
  TYPE_STD_TABLE_OPEN  = 1 << 9,
  TYPE_STD_TABLE_CLOSE = 1 << 10,
  TYPE_COMMENT         = 1 << 11,
  TYPE_KEY_SEP         = 1 << 12,
  TYPE_BOOL            = 1 << 13,
  TYPE_FLOAT           = 1 << 14,
  TYPE_INT             = 1 << 15,
  TYPE_HEX             = 1 << 16,
  TYPE_OCT             = 1 << 17,
  TYPE_DATE            = 1 << 18,
  TYPE_TIME            = 1 << 19,
  TYPE_LIT_STRING      = 1 << 20,
  TYPE_INF             = 1 << 21,
  TYPE_NAN             = 1 << 22,
  TYPE_BINARY          = 1 << 23,
  TYPE_LIT_KEY         = 1 << 24,
  TYPE_VALUE           = TYPE_STRING | TYPE_M_STRING | TYPE_BOOL | TYPE_FLOAT |
                         TYPE_INT | TYPE_DATE | TYPE_TIME | TYPE_INF |
                         TYPE_NAN | TYPE_BINARY | TYPE_OCT | TYPE_HEX,
  TYPE_DEBUG           = 1 << 30,
}
#endif

enum BaseType {
  T_NONE,
  T_KEY,
  T_KEY_SEP,
  T_KEYVAL_SEP,
  T_VAL,
  T_VAL_SEP,
  T_NL,
  T_WS,
  T_COMMENT,
  T_STDTBL_O,
  T_STDTBL_C,
  T_INLTBL_O,
  T_INLTBL_C,
  T_ARRAY_O,
  T_ARRAY_C,
  T_ITEM_SEP,
  T_ARRTBL_O,
  T_ARRTBL_C,
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
  K_UNQUOTED,
  K_QUOTED,
  K_LITERAL,
  V_STR,
  V_LITSTR,
  V_MULSTR,
  V_LITMULSTR,
  V_INT,
  V_FLOAT,
  V_HEX,
  V_OCT,
  V_BIN,
  V_BOOL,
  V_DATE,
  V_DATETIME,
  V_TIME,
  V_INF,
  V_NAN,
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

#if 0
protected mapping(int:s8) _type_to_str = ([
  TYPE_NONE            : "TYPE_NONE",
  TYPE_KEY             : "TYPE_KEY",
  TYPE_UNQUOTED_KEY    : "TYPE_UNQUOTED_KEY",
  TYPE_QUOTED_KEY      : "TYPE_QUOTED_KEY",
  TYPE_DOTTED_KEY      : "TYPE_DOTTED_KEY",
  TYPE_KEYVAL_SEP      : "TYPE_KEYVAL_SEP",
  TYPE_WHITESPACE      : "TYPE_WHITESPACE",
  TYPE_NEWLINE         : "TYPE_NEWLINE",
  TYPE_STRING          : "TYPE_STRING",
  TYPE_M_STRING        : "TYPE_M_STRING",
  TYPE_VALUE           : "TYPE_VALUE",
  TYPE_STD_TABLE_OPEN  : "TYPE_STD_TABLE_OPEN",
  TYPE_STD_TABLE_CLOSE : "TYPE_STD_TABLE_CLOSE",
  TYPE_COMMENT         : "TYPE_COMMENT",
  TYPE_KEY_SEP         : "TYPE_KEY_SEP",
  TYPE_BOOL            : "TYPE_BOOL",
  TYPE_INT             : "TYPE_INT",
  TYPE_FLOAT           : "TYPE_FLOAT",
  TYPE_HEX             : "TYPE_HEX",
  TYPE_OCT             : "TYPE_OCT",
  TYPE_TIME            : "TYPE_TIME",
  TYPE_DATE            : "TYPE_DATE",
  TYPE_LIT_STRING      : "TYPE_LIT_STRING",
  TYPE_INF             : "TYPE_INF",
  TYPE_NAN             : "TYPE_NAN",
  TYPE_BINARY          : "TYPE_BINARY",
  TYPE_LIT_KEY         : "TYPE_LIT_KEY",
  TYPE_DEBUG           : "<< TYPE_DEBUG >>",
]);
#endif

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

#if 0
class Token
{
  protected Type _type;
  protected s8   _text;
  protected int  _line;
  protected int  _col;

  protected void create(Type type, s8 text, int(1..) line, int(1..) col)
  {
    this::_type = type;
    this::_text = text;
    this::_line = line;
    this::_col  = col;
  }

  public Type `type() { return _type; }
  public s8   `text() { return _text; }
  public int  `line() { return _line; }
  public int  `column() { return _col; }

  public bool is_a(Type t)
  {
    return this::_type & t;
  }

  protected string _sprintf(int t)
  {
    switch (t) {
      default:
        return sprintf("%O(%O, %O, %O, %O)",
                       object_program(this),
                       type_to_str(),
                       shorten_text(_text), _line, _col);
    }
  }

  protected s8 shorten_text(s8 t)
  {
    if (sizeof(t) > 20) {
      t = t[0..20] + " [...]";
    }

    if (search(t, "\n")) {
      replace(t, "\n", "\\n");
    }

    return t;
  }

  protected s8 type_to_str()
  {
    array(s8) t = ({});

    foreach (_type_to_str; int tt; s8 st) {
      if (_type & tt) {
        t += ({ st });
      }
    }

    return t * " | ";
  }
}
#endif
