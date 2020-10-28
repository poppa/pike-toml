#ifndef TOML_LEXER_H
#define TOML_LEXER_H

#ifdef TOML_LEXER_DEBUG
#  define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
#  define TRACE(X...) 0
#endif

#define REGEX Regexp.PCRE.Widestring
#define CASELESS Regexp.PCRE.OPTION.CASELESS

#define CASE_VALID_KEY_CHARS \
  case '-': \
  case '0'..'9': \
  case 'A'..'Z': \
  case '_': \
  case 'a'..'z'

protected REGEX re_int = REGEX("^(0|[1-9][0-9]*)$");
protected REGEX re_float = REGEX("^(0\\.|[1-9][0-9]*\\.)[0-9]+$");
protected REGEX re_exp = REGEX("^([0]|[1-9][0-9]*)[eE][0-9]+");
protected REGEX re_hex = REGEX("^0x[0-9A-F]+$", CASELESS);
protected REGEX re_oct = REGEX("^0o[0-7]+$");
protected REGEX re_bin = REGEX("^0b[0-1]+$");

protected string full_date
  = "(\\d{4})" + "-" // year
  + "(0[1-9]|1[0-2])" + "-" // month
  + "(0[1-9]|[1-2][0-9]|3[0-1])"; // day
protected string time_hour = "(0\\d|1\\d|2[0-3])";
protected string time_minute = "([0-5]\\d)";
protected string time_second = "([0-6]\\d(\\.\\d+)?)"; // Allow for leap-sec
protected string partial_time
  = time_hour + ":"
  + time_minute + ":"
  + time_second;
protected string local_date_time
  = full_date
  + "[T]" // We don't handle space atm.
  + partial_time;
protected string offset_date_time
  = local_date_time
  + "[+-]"
  + time_hour + ":"
  + time_minute;

protected REGEX re_local_time = REGEX("^(" + partial_time + ")$");
protected REGEX re_full_date = REGEX("^(" + full_date + ")$");
protected REGEX re_local_date_time = REGEX("^(" + local_date_time + ")$");
protected REGEX re_offset_date_time = REGEX("^(" + offset_date_time + ")$" );

#endif
