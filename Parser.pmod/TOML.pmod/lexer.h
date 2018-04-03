#ifndef TOML_LEXER_H
#define TOML_LEXER_H

#ifdef TOML_LEXER_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
# define PUSH_DEBUG_TOKEN(X...) do {                               \
    push_token(TYPE_DEBUG, sprintf(X));                            \
  } while (0)
#else
# define TRACE(X...)
# define PUSH_DEBUG_TOKEN(X...)
#endif

#define CURRENT() data[cursor]
#define CURR_COL() col + 1
#define CURR_LINENO() rows + 1

#define CASE_KEY_START                                             \
  case '0' .. '9': case 'a' .. 'z': case 'A' .. 'Z':               \
  case '_': case '\'': case '"': case '-'

#define NEXT() do {                                                \
    cursor++;                                                      \
    col += 1;                                                      \
  } while (0)

#define MUL_STR() \
  (CURRENT() == STR_START && peek() == STR_START && peek(2) == STR_START)

#define IS_DIGIT_START(c) \
  (DIGIT[c] || c == '+' || c == '-' )

#define die(X...)                                                  \
  do {                                                             \
    werror("Tokens: %O\n", tokens);                                \
    s8 p = sprintf("DIE: %s:%d: ", basename(__FILE__),  __LINE__); \
    p += sprintf(X);                                               \
    exit(0, p);                                                    \
  } while (0)

#define SYNTAX_ERROR(R...)                                         \
  error("TOML syntax error at line %d column %d byte %d: %s.\n",   \
        current_lineno(), current_column(), cursor, sprintf(R))

#define EXPECT(C)                                                  \
  do {                                                             \
    if (CURRENT() != C) {                                          \
      SYNTAX_ERROR("Expected \"%c\" got \"%c\"", C, CURRENT());    \
    }                                                              \
  } while (0)

#ifdef TOML_ADD_WS_TOKENS
# define PUSH_FOLD_TOKEN(TYPE,VAL) push_token((TYPE), 0, (VAL))
#else
# define PUSH_FOLD_TOKEN(TYPE,VAL)
#endif


#endif
