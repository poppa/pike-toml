// https://github.com/poppa/pest
import Pest;
import Parser.TOML;

#include "helpers.h"

int main() {
  describe("Parser init tests", lambda () {
    test(
      "Parser->parse_file() should handle Stdio.File objects as argument",
      lambda () {
        Parser p = Parser();
        mapping res = p->parse_file(
          Stdio.File(toml_file("simple.toml"))
        );

        expect(res["string-key"])->to_equal("string");
      }
    );

    test(
      "Parser->parse_file() should handle path to a file as argument",
      lambda () {
        Parser p = Parser();
        mapping res = p->parse_file(toml_file("simple.toml"));
        expect(res["string-key"])->to_equal("string");
      }
    );

    test(
      "Parser->parse_string() should parse the string given as argument",
      lambda () {
        Parser p = Parser();
        mapping res = p->parse_string("key = 1");
        expect(res->key)->to_equal(1);
      }
    );
  });

  describe("Parser parse tests", lambda() {
    test("Parser should handle literal values", lambda () {
      mapping res = parse_string(#"
        intkey = 1
        floatkey = 1.1
        expkey = 1.1e-2
        octkey = 0o072
        binkey = 0b011
        hexkey = 0xFF
        strkey = \"str\"
        litkey = 'lit'
        booltrue = true
        boolfalse = false
        dashed-key = 'dashed'
        mulstr = \"\"\"Multi
          line str\"\"\"
        mullit = '''Multi
          line lit'''
        fulldate = 2020-11-07T01:01:01.000
        localtime = 01:01:01
      ");

      expect(res->intkey)->to_equal(1);
      expect(res->floatkey)->to_equal(1.1);
      expect(res->expkey)->to_equal(0.011);
      expect(res->octkey)->to_equal(58);
      expect(res->binkey)->to_equal(3);
      expect(res->hexkey)->to_equal(255);
      expect(res->strkey)->to_equal("str");
      expect(res->litkey)->to_equal("lit");
      expect(res->booltrue)->to_equal(true);
      expect(res->boolfalse)->to_equal(false);
      expect(res["dashed-key"])->to_equal("dashed");
      expect(res->mulstr)->to_equal("Multi\n          line str");
      expect(res->mullit)->to_equal("Multi\n          line lit");
      expect(res->localtime->hour_no())->to_equal(1);
      expect(res->localtime->minute_no())->to_equal(1);
      expect(res->localtime->second_no())->to_equal(1);
    });

    test("Parser should handle inline arrays", lambda () {
      mapping res = parse_string(#"
        nums = [1, 2, 3]
        strs = ['one', 'two']
      ");

      expect(res->nums)->to_equal(({ 1, 2, 3 }));
      expect(res->strs)->to_equal(({ "one", "two" }));
    });

    test("Parser should handle inline tables", lambda () {
      mapping res = parse_string(#"
        one = { name = 'key', value = 1 }
      ");

      expect(res->one)->to_equal(([ "name": "key", "value": 1 ]));
    });

    test("Parser should handle inline array of tables", lambda () {
      mapping res = parse_string(#"
        one = [{ name = 'key', value = 1 }, { name = 'key', value = 2 }]
      ");

      expect(res->one)->to_equal(({
        ([ "name": "key", "value": 1 ]),
        ([ "name": "key", "value": 2 ]),
      }));
    });

    test(
      "Parser should throw error on inline array with mixed data types",
      lambda () {
        mixed err = catch(parse_string("a = [1, 1.2]"));
        expect(!err)->to_equal(false);
      }
    );

    test("Parser should handle standard tables", lambda () {
      mapping res = parse_string(#"
        [root]
        key = 'hello'
        val = 1
      ");

      expect(res->root)->to_equal(([ "key": "hello", "val": 1 ]));
    });

    test("Parser should handle nested standard tables", lambda () {
      mapping res = parse_string(#"
        [root]
        key = 'hello'
        val = 1

        [root.sub]
        key = 'sub'
        num = 1.1
      ");

      expect(res->root)->to_equal(([
        "key": "hello",
        "val": 1,
        "sub": ([
          "key": "sub",
          "num": 1.1
        ])
      ]));
    });

    test("Parser should handle standard arrays", lambda () {
      mapping res = parse_string(#"
        [[arr]]
        i = 0
        v = 'zero'

        [[arr]]
        i = 1
        v = 'one'

        [[arr]]
        i = 2
        v = 'two'
      ");

      expect(res->arr)->to_equal(({
        ([ "i": 0, "v": "zero" ]),
        ([ "i": 1, "v": "one" ]),
        ([ "i": 2, "v": "two" ]),
      }));
    });

    test("Parser should handle standard arrays with dotted keys", lambda () {
      mapping res = parse_string(#"
        [[arr.sub]]
        i = 0
        v = 'zero'

        [[arr.sub]]
        i = 1
        v = 'one'
      ");

      expect(res->arr->sub)->to_equal(({
        ([ "i": 0, "v": "zero" ]),
        ([ "i": 1, "v": "one" ]),
      }));
    });
  });
}
