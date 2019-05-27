#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>

#include "../shared.h"

static void parsecmdargs(int, char *[]);
static void contoserv(void);
static void sendreq(void);
static void recvtype(void);

enum errors {
	ARGNERR = 1,
	SOCKFERR,
	SRCFERR,
	WDERR,
	LINERR,
	COLERR,
	SRCTYPERR,
	METHERR,
	ASTDIRERR,
	REPARSERR,
	SOCKERR,
	CONERR,
	SNDERR,
	RCVERR,
	CLREQERR,
};

void
parsecmdargs(int argc, char *argv[])
{
	char *endptr;
	
	if (argc < 6)
		exit(ARGNERR);

	sf = argv[1];
	if (access(sf, R_OK) != 0)
		exit(SOCKFERR);

	srcf = argv[2];
	srcf_s = strlen(srcf) + 1;
	if (access(srcf, R_OK) != 0)
		exit(SRCFERR);

	wd = argv[3];
	wd_s = strlen(wd) + 1;
	if (access(wd, R_OK) != 0)
		exit(WDERR);

	errno = 0;
	lnum = strtol(argv[4], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || lnum <= 0)
		exit(LINERR);
	
	errno = 0;
	col = strtol(argv[5], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || col <= 0)
		exit(COLERR);

	if (argc == 6)
		return;
	srct = argv[6];
	srct_s = strlen(srct) + 1;
	if (strcasecmp(srct, "c") != 0 && strcasecmp(srct, "cpp") != 0)
		exit(SRCTYPERR);

	if (argc == 7)
		return;
	method = argv[7];
	method_s = strlen(method) + 1;
	if (strcasecmp(method, "ast") != 0 && strcasecmp(method, "source") != 0)
		exit(METHERR);

	if (argc == 8)
		return;
	if (strcasecmp(method, "ast") == 0) {
		astdir = argv[8];
		astdir_s = strlen(astdir) + 1;
		if (access(astdir, R_OK | W_OK) != 0)
			exit(ASTDIRERR);
	} else {
		errno = 0;
		reparse = strtol(argv[8], &endptr, 10);
		if (errno != 0 || *endptr != '\0' || reparse < 0 || reparse > 1)
			exit(REPARSERR);
	}

	if (argc == 9)
		return;
	clargs = argv[9];
	clargs_s = strlen(clargs) + 1;
}

void
contoserv(void)
{
	if ((sfd = socket(PF_UNIX, SOCK_STREAM, 0)) == -1)
		exit(SOCKERR);

	memset(&addr, 0, sizeof(struct sockaddr_un));
	addr.sun_family = AF_UNIX;
	snprintf(addr.sun_path, sizeof(addr.sun_path), sf);

	if (connect(sfd, (struct sockaddr *) &addr,
			sizeof(struct sockaddr_un)) != 0)
		exit(CONERR);
}

void
sendreq(void)
{
	if ( write(sfd, &srcf_s, sizeof(srcf_s)) != sizeof(srcf_s) ||
			write(sfd, srcf, srcf_s) != srcf_s ||
			write(sfd, &wd_s, sizeof(wd_s)) != sizeof(wd_s) ||
			write(sfd, wd, wd_s) != wd_s ||
			write(sfd, &lnum, sizeof(lnum)) != sizeof(lnum) ||
			write(sfd, &col, sizeof(col)) != sizeof(col) ||
			write(sfd, &srct_s, sizeof(srct_s)) != sizeof(srct_s) ||
			write(sfd, srct, srct_s) != srct_s ||
			write(sfd, &method_s, sizeof(method_s)) != sizeof(method_s) ||
			write(sfd, method, method_s) != method_s ) {
		close(sfd);
		exit(SNDERR);
	}
	if (method && strcasecmp(method, "ast") == 0) {
		if ( write(sfd, &astdir_s, sizeof(astdir_s)) != sizeof(astdir_s) ||
				write(sfd, astdir, astdir_s) != astdir_s ) {
			close(sfd);
			exit(SNDERR);
		}
	} else {
		if (write(sfd, &reparse, sizeof(reparse)) != sizeof(reparse)) {
			close(sfd);
			exit(SNDERR);
		}
	}
	if (write(sfd, &clargs_s, sizeof(clargs_s)) != sizeof(clargs_s) ||
			write(sfd, clargs, clargs_s) != clargs_s ) {
		close(sfd);
		exit(SNDERR);
	}
}

void
recvtype(void)
{
	if (read(sfd, &clreqerr, sizeof(clreqerr)) != sizeof(clreqerr)) {
		close(sfd);
		exit(RCVERR);
	}
	if (clreqerr != 0)
		return;

	if (read(sfd, &t_s, sizeof(t_s)) != sizeof(t_s)) {
		close(sfd);
		exit(RCVERR);
	}
	t = malloc(t_s);
	if (read(sfd, t, t_s) != t_s) {
		free(t);
		close(sfd);
		exit(RCVERR);
	}
}

int
main(int argc, char *argv[])
{
	parsecmdargs(argc, argv);

	contoserv();

	sendreq();

	recvtype();

	if (clreqerr != 0) {
		printf("%d", clreqerr);
		close(sfd);
		exit(CLREQERR);
	}

	printf("@%s\n", t);

	free(t);
	close(sfd);
}
