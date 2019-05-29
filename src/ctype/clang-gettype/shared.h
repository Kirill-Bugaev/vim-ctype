static char *sf;	/* socket file */
static struct sockaddr_un addr;
static int sfd;		/* socket file descriptor */

static int qt;		/* query type:
					   0 - type request 
					   1 - test (check server still working)
					   2 - shutdown server */

typedef int qsize;
static char *srcf = NULL;	/* source file */
static qsize srcf_s = 0;	/* source file string size (termnull included) */
static char *srct = NULL;	/* source file type */
static qsize srct_s = 0;
static char *wd = NULL;		/* working directory */
static qsize wd_s = 0;
static long lnum, col;
static char *method = NULL;
static qsize method_s = 0;
static char *astdir = NULL;
static qsize astdir_s = 0;
static long reparse = 1; 	/* TU updating option:
								0 - create new
								1 - reparse */
static char *clargs = NULL; /* clang arguments */
static qsize clargs_s = 0;

static int clreqerr;			/* errors happening during clang request */

static char *t;	/* required type */
static unsigned t_s;	/* type string size */

