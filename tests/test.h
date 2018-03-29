int __a_ok;

#define ASSERT(X)                              \
  if (!(X)) error("Failed ASSERT: " # X "\n"); \
  __a_ok++

#define ASSERT_EQ(A,B)                                            \
  if (!((A) == (B)))                                              \
    error("Failed ASSERT_EQ: " #A " == " #B " [got: %O]\n", (A)); \
   __a_ok++

#define DONE() write("[✔] %d simple tests passed\n\n", __a_ok)