#define START_TIMER() int T__ = gethrtime();
#define GET_TIME() ((gethrtime() - T__) / 1000000.0)
