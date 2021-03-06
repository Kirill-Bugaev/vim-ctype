#define SOCKF	"/socket"
#define CS_MAX		10000
#define CS_MIN		1

static long bl = 10;	/* backlog: maximum length to which the queue of pending
						 * connections for socket may grow */
static struct timeval srto = {	/* socket receive timeout */
	.tv_sec = 0,
	.tv_usec = 10000
};
static long cs = 20;	/* cache size, 1 is minimum */
static char *clcmd = "/usr/bin/clang";
static char *clppcmd = "/usr/bin/clang++";
static char sd[] = "/tmp/clang-gettype-socket-XXXXXX";
static char *astdefdir = "/tmp";
static const char *astff = "clang-gettype-ast-XXXXXX";
