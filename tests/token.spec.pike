// https://github.com/poppa/pest
import Pest;
import TOML;

int main() {
  describe("Basic token tests", lambda () {
    test("Check Token.Kind.Type", lambda() {
      #define ktos(K) stringp(Token.kind_to_string(Token.Kind.##K))

      expect(ktos(None))->to_equal(true);
      expect(ktos(Key))->to_equal(true);
      expect(ktos(Value))->to_equal(true);
      expect(ktos(TableOpen))->to_equal(true);
      expect(ktos(TableClose))->to_equal(true);
      expect(ktos(InlineTableOpen))->to_equal(true);
      expect(ktos(InlineTableClose))->to_equal(true);
      expect(ktos(InlineArrayOpen))->to_equal(true);
      expect(ktos(InlineArrayClose))->to_equal(true);
      expect(ktos(TableArrayOpen))->to_equal(true);
      expect(ktos(TableArrayClose))->to_equal(true);

      #undef ktos
    });

    test("Check Token.Modifier", lambda () {
      #define mtos(M) stringp(Token.modifier_to_string(Token.Modifier.##M))

      expect(mtos(QuotedString))->to_equal(true);
      expect(mtos(LiteralString))->to_equal(true);
      expect(mtos(Multiline))->to_equal(true);
      expect(mtos(Number))->to_equal(true);
      expect(mtos(Boolean))->to_equal(true);
      expect(mtos(Date))->to_equal(true);
      expect(mtos(Int))->to_equal(true);
      expect(mtos(Float))->to_equal(true);
      expect(mtos(Exp))->to_equal(true);
      expect(mtos(Hex))->to_equal(true);
      expect(mtos(Bin))->to_equal(true);
      expect(mtos(Oct))->to_equal(true);
      expect(mtos(Inf))->to_equal(true);
      expect(mtos(Nan))->to_equal(true);
      expect(mtos(Time))->to_equal(true);
      expect(mtos(Dotted))->to_equal(true);

      #undef mtos
    });

    test(
      "Token->pike_value() should render proper value according "
      "to kind and modifers",
      lambda () {
        #define MOD(X) Token.Modifier.##X
        #define tok(V, M) \
          Token.new(Token.Kind.Value, V, M)->pike_value()

        expect(tok("12", MOD(Number)|MOD(Int)))->to_equal(12);
        expect(tok("1.0", MOD(Number)|MOD(Float)))->to_equal(1.0);
        expect(tok("1.0e2", MOD(Number)|MOD(Exp)))->to_equal(100.0);
        expect(tok("0xFF", MOD(Number)|MOD(Hex)))->to_equal(255);
        expect(tok("0071", MOD(Number)|MOD(Oct)))->to_equal(57);
        expect(tok("0b0110", MOD(Number)|MOD(Oct)))->to_equal(6);
        expect(tok("inf", MOD(Number)|MOD(Inf)))->to_equal(Int.inf);
        expect(tok("nan", MOD(Number)|MOD(Nan)))->to_equal(0.0);

        expect(tok("2020-11-03", MOD(Date)))
          ->to_equal(Calendar.dwim_day("2020-11-03"));
        expect(tok("2020-11-03T22:44:00.000+01:00", MOD(Date)|MOD(Time)))
          ->to_equal(Calendar.dwim_time("2020-11-03T22:44:00.000+01:00"));
        expect(tok("11:11:11", MOD(Date)|MOD(Time)))
          ->to_equal(Calendar.dwim_time("11:11:11"));

        expect(tok("Hello\"s", MOD(QuotedString)))->to_equal("Hello\"s");
        expect(tok("Hello\\1s", MOD(LiteralString)))->to_equal("Hello\\1s");
        expect(tok("Hello\nworld", MOD(QuotedString)|MOD(Dotted)))
          ->to_equal("Hello\nworld");
        expect(tok("Hello\nworld", MOD(LiteralString)|MOD(Dotted)))
          ->to_equal("Hello\nworld");

        #undef MOD
        #undef tok
      }
    );

    test(
      "Token->is_key() should return true if kind is Key and false otherwise",
      lambda () {
        Token.Token t = Token.new(Token.Kind.Key, "name");
        expect(t->is_key())->to_equal(true);

        t = Token.new(Token.Kind.Value, "value");
        expect(t->is_key())->to_equal(false);
      }
    );

    test(
      "Token->is_value() should return true if kind is Value "
      "and false otherwise",
      lambda () {
        Token.Token t = Token.new(Token.Kind.Value, "value");
        expect(t->is_value())->to_equal(true);

        t = Token.new(Token.Kind.Key, "name");
        expect(t->is_value())->to_equal(false);
      }
    );

    test(
      "Token->is_value() with modifier given should return properly",
      lambda () {
        constant Nmod = Token.Modifier.Number;
        constant Fmod = Token.Modifier.Float;

        Token.Token t = Token.new(Token.Kind.Value, "1.1", Nmod|Fmod );

        expect(t->is_value(Nmod))->to_equal(true);
        expect(t->is_value(Fmod))->to_equal(true);
        expect(t->is_value(Nmod|Fmod))->to_equal(true);
        expect(t->is_value(Token.Modifier.Hex))->to_equal(false);
      }
    );
  });
}
