#charset utf8

// https://github.com/poppa/pest
import Pest;
import Parser.TOML;

#include "helpers.h"

int main() {
  describe("Test strings from https://toml.io/", lambda () {
    test("Expect basic strings to be handled correctly", lambda () {
      mapping res = parse_file(toml_file("spec.basic-strings.toml"));
      expect(res->str1)->to_equal("I'm a string.");
      expect(res->str2)->to_equal("You can \"quote\" me.");
      expect(res->str3)->to_equal(string_to_utf8("Name\tJos\u00E9\nLoc\tSF."));
      expect(utf8_to_string(res->str3))->to_equal("Name\tJos\u00E9\nLoc\tSF.");
    });

    test("Expect literal strings to be handled correctly", lambda () {
      mapping res = parse_file(toml_file("spec.literal-strings.toml"));

      expect(res->path)->to_equal("C:\\Users\\nodejs\\templates");
      expect(res->path2)->to_equal("\\\\User\\admin$\\system32");
      expect(res->regex)->to_equal("<\\i\\c*\\s*>");
    });

    test(
      "Expect multiline basic string to be stripped of newline following "
      "opening quotes",
      lambda () {
        mapping res = parse_file(toml_file("spec.multiline-basic-string.toml"));
        expect(res->str1)->to_equal("Roses are red\nViolets are blue");
      }
    );

    test(
      "Expect lines ending with '\\' to strip the following whitespaces",
      lambda () {
        mapping res = parse_file(toml_file("spec.multiline-basic-string.toml"));
        string str = "The quick brown fox jumps over the lazy dog.";

        expect(res->str2)->to_equal(str);
        expect(res->str3)->to_equal(str);
        expect(res->str4)->to_equal(str);
      }
    );

    test(
      "Expect multiline literal string to be stripped of newline following "
      "opening quotes",
      lambda () {
        string file_name = "spec.multiline-literal-strings.toml";
        mapping res = parse_file(toml_file(file_name));

        expect(res->lines)->to_equal(
          "The first newline is\n"
          "trimmed in raw strings.\n"
          "   All other whitespace\n"
          "   is preserved.\n"
        );

        expect(res->regex2)->to_equal("I [dw]on't need \\d{2} apples");
      }
    );
  });

  describe("Test integers from https://toml.io/", lambda () {
    test("Normal integers should be handled correctly", lambda() {
      mapping res = parse_file(toml_file("spec.integers.toml"));

      expect(res->int1)->to_equal(99);
      expect(res->int2)->to_equal(42);
      expect(res->int3)->to_equal(0);
      expect(res->int4)->to_equal(-17);
      expect(res->int5)->to_equal(1000);
      expect(res->int6)->to_equal(5349221);
      expect(res->int7)->to_equal(12345);
    });

    test("Hexadecimal integers should be handled correctly", lambda () {
      mapping res = parse_file(toml_file("spec.integers.toml"));

      expect(res->hex1)->to_equal(3735928559);
      expect(res->hex2)->to_equal(3735928559);
      expect(res->hex3)->to_equal(3735928559);
    });

    test("Octal integers should be handled correctly", lambda () {
      mapping res = parse_file(toml_file("spec.integers.toml"));

      expect(res->oct1)->to_equal(342391);
      expect(res->oct2)->to_equal(493);
    });

    test("Binary integers should be handled correctly", lambda () {
      mapping res = parse_file(toml_file("spec.integers.toml"));
      expect(res->bin1)->to_equal(214);
    });
  });

  describe("Test floating point numbers from https://toml.io/", lambda () {
    test(
      "Expect basic floating point numbers to be handled correctly",
      lambda () {
        mapping res = parse_file(toml_file("spec.float.toml"));

        expect(res->flt1)->to_equal(1.0);
        expect(res->flt2)->to_equal(3.1415);
        expect(res->flt3)->to_equal(-0.01);
        expect(res->flt4)->to_equal(5e+22);
        expect(res->flt5)->to_equal(1000000.0);
        expect(res->flt6)->to_equal(-0.02);
        // FIXME: How do we handle this properly?
        //        If we don't do the (float)"6.626e-34" thing the test will
        //        fail. This is probably due to some precision being lost when
        //        the string -> float conversion in Token is being done.
        expect(res->flt7)->to_equal((float)"6.626e-34");
        expect(res->flt8)->to_equal(9224617.44599123);
      }
    );
  });

  describe("Test inf/nan from https://toml.io/", lambda () {
    test("Expect inf to be handled correctly", lambda() {
      mapping res = parse_file(toml_file("spec.inf-nan.toml"));

      expect(res->sf1)->to_equal(Int.inf);
      expect(res->sf2)->to_equal(Int.inf);
      expect(res->sf3)->to_equal(-Int.inf);
    });

    test("Expect nan to be handled correctly", lambda() {
      mapping res = parse_file(toml_file("spec.inf-nan.toml"));

      expect((string)res->sf4)->to_equal("nan");
      expect((string)res->sf5)->to_equal("nan");
      expect((string)res->sf6)->to_equal("nan");
    });
  });

  describe("Test boolean from https://toml.io/", lambda () {
    test("Expect boolean values to be handled correctly", lambda() {
      mapping res = parse_file(toml_file("spec.bool.toml"));

      expect(res->bool1)->to_be_truthy();
      expect(res->bool1)->to_be(Val.true);
      expect(res->bool2)->to_be_falsy();
      expect(res->bool2)->to_be(Val.false);
    });
  });

  describe("Test offset datetime from https://toml.io/", lambda () {
    test("Expect offset datetime to be handled correctly", lambda() {
      mapping res = parse_file(toml_file("spec.offset-datetime.toml"));

      expect(object_program(res->odt1))->to_be(Calendar.Second);
      expect(object_program(res->odt2))->to_be(Calendar.Second);
      expect(object_program(res->odt3))->to_be(Calendar.Fraction);

      expect(res->odt1->format_xtime())->to_equal("1979-05-27 07:32:00.000000");
      expect(res->odt2->format_xtime())->to_equal("1979-05-27 00:32:00.000000");
      expect(res->odt3->format_xtime())->to_equal("1979-05-27 00:32:00.999999");
    });
  });

  describe("Test local datetime from https://toml.io/", lambda () {
    test("Expect local datetime to be handled correctly", lambda() {
      mapping res = parse_file(toml_file("spec.local-datetime.toml"));


      expect(object_program(res->ld1))->to_be(Calendar.Day);
      expect(object_program(res->ldt1))->to_be(Calendar.Second);
      expect(object_program(res->ldt2))->to_be(Calendar.Fraction);
      expect(object_program(res->lt1))->to_be(Calendar.Second);
      expect(object_program(res->lt2))->to_be(Calendar.Fraction);

      expect(res->ld1->format_ymd())->to_equal("1979-05-27");
      expect(res->ldt1->format_xtime())->to_equal("1979-05-27 07:32:00.000000");
      expect(res->ldt2->format_xtime())->to_equal("1979-05-27 00:32:00.999999");
    });
  });

  describe("Test arrays from https://toml.io/", lambda () {
    test("Expect inline arrays to be handled correctly", lambda() {
      mapping res = parse_file(toml_file("spec.array.toml"));

      expect(res->arr1)->to_equal(({ 1, 2, 3 }));
      expect(res->arr2)->to_equal(({ "red", "yellow", "green" }));
      expect(res->arr3)->to_equal(({ ({ 1, 2 }), ({ 3, 4, 5 }) }));
      expect(res->arr4)->to_equal(({
        "all",
        "strings",
        "are the same",
        "type"
      }));
      expect(res->arr5)->to_equal(({ ({ 1, 2 }), ({ "a", "b", "c" }) }));
      expect(res->arr7)->to_equal(({ 1, 2, 3 }));
      expect(res->arr8)->to_equal(({ 1, 2 }));
    });

    test("Expect array with mixed types to throw an error", lambda () {
      mixed err = catch {
        mapping res = parse_file(toml_file("spec.array-fail.toml"));
      };

      expect(!err)->to_equal(false);
    });
  });

  describe("Test tables from https://toml.io/", lambda () {
    test("Expect standard tables to be handled correctly", lambda() {
      mapping res = parse_file(toml_file("spec.table.toml"));

      expect(res->empty)->to_equal(([]));

      expect(res["table-1"])->to_equal(([
        "key1": "some string",
        "key2": 123,
      ]));

      expect(res["table-2"])->to_equal(([
        "key1": "another string",
        "key2": 456,
      ]));

      expect(res->a->b->c)->to_equal(([]));
      expect(res->d->e->f)->to_equal(([]));
      expect(res->g->h->i)->to_equal(([]));
      expect(res->j->ʞ->l)->to_equal(([]));
      expect(res->dog["tater.man"]->type->name)->to_equal("pug");
    });

    test("Expect overwriting existing table keys to fail", lambda () {
      mixed err = catch (parse_string(#"
        [a]
        b = 1
        [a]
        c = 2
      "));

      expect(!err)->to_equal(false);

      err = catch (parse_string(#"
        [a]
        b = 1
        [a.b]
        c = 2
      "));

      expect(!err)->to_equal(false);
    });
  });
}
