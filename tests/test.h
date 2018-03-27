int __a_ok;
#define ASSERT(X) if (!(X)) error("Failed Test: " # X "\n"); \
                  __a_ok++

#define DONE(M) write(M "%d\n", __a_ok)