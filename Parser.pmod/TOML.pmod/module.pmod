import .Token;

array(Token) lex(string in)
{
  return .Lexer(in)->lex();
}

array(Token) fold_whitespace(array(Token) tokens)
{
  return filter(tokens, lambda (Token t) {
    return !t->is_a(TYPE_WHITESPACE|TYPE_NEWLINE|TYPE_COMMENT|TYPE_DEBUG);
  });
}

variant array(Token2) fold_whitespace(array(Token2) tokens)
{
  return filter(tokens, lambda (Token2 t) {
    return !(< T_WS, T_NL, T_COMMENT, T_DEBUG >)[t->type];
  });
}
