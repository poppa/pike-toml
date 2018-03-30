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