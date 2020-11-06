import Pest;

class MyArgs {
  inherit Arg.Options;
  Opt file = HasOpt("--file")|HasOpt("-f");
  Opt test = HasOpt("--test")|HasOpt("-t");
}


int main(int argc, array(string) argv) {
  MyArgs a = MyArgs(argv);
  GlobArg file_glob;

  if (a->file) {
    file_glob = a->file / ",";
  }

  run_test(__DIR__, file_glob);
}
