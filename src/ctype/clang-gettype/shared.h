static char *sf;	/* socket file */
static struct sockaddr_un addr;
static int sfd;		/* socket file descriptor */

static int srcf_s;	/* source file string size */
static int wd_s;	/* working directory string size */
static long lnum, col;
static char *clargs = NULL;
static int clargs_s = 0;
static long method = 1;	/* method of retrieving Translation Unit:
						   0 - from AST file
						   1 - from source file */
static long reparse = 1; /* TU updating option:
							0 - create new
							1 - reparse */

static char *t;	/* required type */
static unsigned t_s;	/* type string size */

