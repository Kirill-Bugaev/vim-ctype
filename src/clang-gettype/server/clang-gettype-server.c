#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <limits.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <linux/limits.h>
#include <sys/time.h>
#include <time.h>
#include <sys/wait.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <clang-c/Index.h>

#include "config.h"
#include "../shared.h"

static void parsecmdargs(int, char *[]);
static void clangcheck(void);
static void clangcheck(void);
static void getsockf(void);
static void starserv(void);
static int recvquery(void);
static int sendtype(void);

static int cfd;
static char srcf[PATH_MAX];

static void sighandler(int);
static void catchsigs(void);

typedef struct tui {
	char *srcf;
	time_t la;	/* last access time */
	struct timespec mtim;
	CXIndex index;
	CXTranslationUnit tu;
	struct tui *next;
} TUi;

static void initc(void);
static long hash(char *);
static long lookup(char *, TUi **, TUi **);
static char *makeast(void);
static void freenp(long, TUi *, TUi *);
static long findold(TUi **, TUi **);
static void removci(long, TUi *, TUi *);
static int cacheop(long, TUi **, TUi *);
static int gettype(CXTranslationUnit);
static int clangreq(void);

static TUi **c;
static unsigned cf = 0;	/* cache fullness */
static char *astf = NULL;

enum errors {
	FORKERR = 1,
	STDIOEERR,
	BLERR,
	RTOERR,
	CSERR,
	CLCHCKERR,
	SOCKFERR,
	SOCKERR,
	BINDERR,
	LISTERR,
	ACCERR,
	SIGERR,
	INICERR,
	CLEXEERR,
};

void
parsecmdargs(int argc, char *argv[])
{
	char *endptr;

	/* backlog */
	if (argc == 1) 
		return;
	errno = 0;
	bl = strtol(argv[1], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || bl < 0)
		exit(BLERR);
	
	/* receive timeout (microseconds) */
	if (argc == 2) 
		return;
	errno = 0;
	srto.tv_usec = strtol(argv[2], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || srto.tv_usec < 0)
		exit(RTOERR);

	/* cache size */
	if (argc == 3) 
		return;
	errno = 0;
	cs = strtol(argv[3], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || cs < CS_MIN || cs > CS_MAX)
		exit(CSERR);

	/* path to clang */
	if (argc == 4) 
		return;
	clcmd = argv[4];

	/* path to clang++ */
	if (argc == 5) 
		return;
	clppcmd = argv[5];
}

void
clangcheck(void)
{
	struct stat stbuf;
	
	if (stat(clcmd, &stbuf) == -1 || !(stbuf.st_mode & S_IXUSR))
		exit(CLCHCKERR);
}

void
getsockf(void)
{
	if (!(mkdtemp(sd)))
		exit(SOCKFERR);

	if (!(sf = malloc(strlen(sd) + sizeof(SOCKF))) || !strcpy(sf, sd) ||
			!strcat(sf, SOCKF)) {
		rmdir(sd);
		exit(SOCKFERR);
	}
}

void
starserv(void)
{
	if ((sfd = socket(PF_UNIX, SOCK_STREAM, 0)) == -1) {
		rmdir(sd);
		exit(SOCKERR);	
	}

	memset(&addr, 0, sizeof(struct sockaddr_un));
	addr.sun_family = AF_UNIX;
	snprintf(addr.sun_path, sizeof(addr.sun_path), sf);

	if (bind(sfd, (struct sockaddr *) &addr, sizeof(struct sockaddr_un)) != 0) {
		rmdir(sd);
		exit(BINDERR);
	}

	if (listen(sfd, bl) != 0) {
		unlink(sf);
		rmdir(sd);
		exit(LISTERR);
	}
}

int
recvquery(void)
{
	if (setsockopt(cfd, SOL_SOCKET, SO_RCVTIMEO, (char *)&srto,
                sizeof(srto)) == -1)
		return -1;
	
	if ( read(cfd, &srcf_s, sizeof(srcf_s)) != sizeof(srcf_s) ||
			read(cfd, srcf, srcf_s) != srcf_s ||
			read(cfd, &lnum, sizeof(lnum)) != sizeof(lnum) ||
			read(cfd, &col, sizeof(col)) != sizeof(col) )
		return -1;

	if (clargs) {
		free(clargs);
		clargs = NULL;
	}
	if (read(cfd, &clargs_s, sizeof(clargs_s)) != sizeof(clargs_s))
		return -1;
	if (clargs_s != 0) {
		if (!(clargs = malloc(clargs_s)))
			return -1;
		if (read(cfd, clargs, clargs_s) != clargs_s) {
			free(clargs);
			clargs = NULL;
			return -1;
		}
	}

	return 0;
}

int
sendtype(void)
{
	if ( write(cfd, &t_s, sizeof(t_s)) != sizeof(t_s) ||
			write(cfd, t, t_s) != t_s )
		return -1;
	return 0;
}

void
initc(void)
{
	if (!( c = malloc(sizeof(TUi *) * cs) ))
		exit(INICERR);
	for (long i = 0; i < cs; ++i)
		c[i] = NULL;
}

long
hash(char *srcf)
{
	unsigned hashval;

	for (hashval = 0; *srcf != '\0'; srcf++)
		hashval = *srcf + 31 * hashval;
	return hashval % cs;
}

long
lookup(char *srcf, TUi **np, TUi **prev)
{
	long ci;

	ci = hash(srcf);
	*prev = NULL;
	for (*np = c[ci]; *np != NULL; *np = (*np)->next) {
		if (strcmp(srcf, (*np)->srcf) == 0)
			break;
		*prev = *np;
	}
	return ci;
}

char *
makeast(void)
{
	char *clang, *ext, *af;
	int fd;
	unsigned cmdsize;

	if ((ext = strrchr(srcf, '.')) && strcmp(ext, (char *) &".cpp") == 0)
		clang = clppcmd;
	else
		clang = clcmd;

	if (!( af = strdup(astff) ))
		return NULL;
	
	if ((fd = mkstemp(af)) == -1) {
		free(af);
		return NULL;
	}
	close(fd);

	pid_t p = fork();
	if (p == 0) {
		if (execl(clang, clang, "-emit-ast", srcf, "-o", af, clargs,
				NULL) == -1)
			exit(CLEXEERR);
	} else if (p == -1) {
		free(af);
		return NULL;
	}
	int st;
	if (waitpid(p, &st , 0) == -1) {
		free(af);
		return NULL;
	}
	if (WIFEXITED(st) && WEXITSTATUS(st) != 0) {
		free(af);
		return NULL;
    }

	return af;
}

void
freenp(long ci, TUi *np, TUi *prev)
{
	free(np->srcf);
	if (np == c[ci])	/* first in cache branch */
		c[ci] = np->next;
	else
		prev->next = np->next;
	free(np);
}

long
findold(TUi **op, TUi **prev)
{
	long ci = -1;
	time_t la = (time_t) LONG_MAX;
	TUi *np, *pp;

	for (long i = 0; i < cs; ++i) {
		pp = NULL;
		for (np = c[i]; np != NULL; np = np->next) {
			if (np->la < la) {
				la = np->la;
				*op = np;
				*prev = pp;
				ci = i;
			}
			pp = np;
		}
	}
	return ci;
}

void
removci(long ci, TUi *np, TUi *prev)
{
	clang_disposeTranslationUnit(np->tu);
	clang_disposeIndex(np->index);
	freenp(ci, np, prev);
	--cf;
}

int
cacheop(long ci, TUi **np, TUi *prev)
{
	unsigned hashval;
	TUi *oldp;
	long oci;

	if (!*np) {
		if (cf == cs) {
			if ((oci = findold(&oldp, &prev)) == -1)
				return -1;
			removci(oci, oldp, prev);
		}
		if (!( *np = malloc(sizeof(TUi)) ) ||
				!( (*np)->srcf = strdup(srcf) ) ) {
			if (*np) {
				if ((*np)->srcf)
					free((*np)->srcf);
			   	free(*np);
			}
			return -1;
		}
		(*np)->next = c[ci];
		c[ci] = *np;
		++cf;
	} else {
		clang_disposeTranslationUnit((*np)->tu);
		clang_disposeIndex((*np)->index);
	}

	if (!(astf = makeast())) {
		freenp(ci, *np, prev);
		--cf;
		return -1;
	}
	
	(*np)->index = clang_createIndex(0, 0);
	(*np)->tu = clang_createTranslationUnit((*np)->index, astf);
	unlink(astf);
	free(astf);
	astf = NULL;
	
	return 0;
}

int
gettype(CXTranslationUnit tu)
{
	CXFile file;
	CXSourceLocation loc;
	CXCursor cursor, def;
	CXType type;
	CXString typesp;
	const char *typestr;

	file = clang_getFile(tu, srcf);
	loc = clang_getLocation(tu, file, lnum, col);
	cursor = clang_getCursor(tu, loc);
	def = clang_getCursorDefinition(cursor);
	if (clang_Cursor_isNull(def))
		type = clang_getCursorType(cursor);
	else 
		type = clang_getCursorType(def);
	typesp = clang_getTypeSpelling(type);
	typestr = clang_getCString(typesp);
	
	t_s = strlen(typestr) + 1;
	t = strdup(typestr);

	clang_disposeString(typesp);
	if (t) return 0;
	else return -1;
}

int
clangreq(void)
{
	TUi *np, *prev;
	struct stat stbuf;
	int mod = 0;
	long ci;

	if (stat(srcf, &stbuf) == -1)
		return -1;
	ci = lookup(srcf, &np, &prev);
	if (np) {
		/* check modification time of source file */
		if (stbuf.st_mtim.tv_sec != np->mtim.tv_sec ||
				stbuf.st_mtim.tv_nsec != np->mtim.tv_nsec)
			mod = 1;
	}

	if (!np || mod) {
		if (cacheop(ci, &np, prev) == -1)
			return -1;
		np->mtim.tv_sec = stbuf.st_mtim.tv_sec;
		np->mtim.tv_nsec = stbuf.st_mtim.tv_nsec;
	}
	np->la = time(NULL);
	
	if (gettype(np->tu) != -1)
		return 0;
	else
	   	return -1;
}

void sighandler(int signo)
{
	if (signo == SIGINT || signo == SIGTERM || signo == SIGHUP) {
		if (astf) unlink(astf);
		close(cfd);
		close(sfd);
		unlink(sf);
//		unlink(sd);
		rmdir(sd);
		exit(0);
	}
	
}

void catchsigs(void)
{
	if (signal(SIGINT, sighandler) == SIG_ERR ||
			signal(SIGTERM, sighandler) == SIG_ERR ||
			signal(SIGHUP, sighandler) == SIG_ERR ||
			signal(SIGPIPE, sighandler) == SIG_ERR)
		exit(SIGERR);
}

int
main(int argc, char *argv[])
{
	static socklen_t addrl;
	
	parsecmdargs(argc, argv);
	clangcheck();

	getsockf();
	starserv();
	
#define _FORK	1
#if defined(_FORK) && _FORK == 1
	pid_t p = fork();
	if (p == -1)
		exit(FORKERR);
	else if (p > 0) {
		printf("%d\n%s\n", p, sf);
		exit(0);
	}
	if (close(0) == -1 || close(1) == -1 || close(2) == -1 ||
			open("/dev/null", O_RDONLY) == -1 ||
			open("/dev/null", O_RDWR) == -1 ||
			open("/dev/null", O_RDWR) == -1)
		exit(STDIOEERR);
#else
	printf("%s\n", sf);
#endif

	catchsigs();

	initc();

	while((cfd = accept(sfd, (struct sockaddr *) &addr, &addrl)) != -1) {
		if (recvquery() == -1)
			goto cont;
		if (clangreq() == -1)
			goto cont;
		if (sendtype() == -1) {
			free(t);
			goto cont;
		}
		free(t);
cont:
		close(cfd);
	}

	close(sfd);
	unlink(sf);
	rmdir(sd);
	exit(ACCERR);
}
