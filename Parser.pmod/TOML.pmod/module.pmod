
mixed lex(string in)
{
  .Lexer lexer = .Lexer(in);
  lexer->lex();
  werror("%O\n", lexer->rows);
  werror("%O\n", lexer->position());
}
