#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>

#include "../shared.h"

static void parsecmdargs(int, char *[]);
static void contoserv(void);
static void sendreq(void);
static void recvtype(void);

static char *srcf;
static char *wd;

enum errors {
	ARGNERR = 1,
	CRDERR,
	METHERR,
	REPARSERR,
	SOCKERR,
	CONERR,
	SNDERR,
	RCVERR,
};

void
parsecmdargs(int argc, char *argv[])
{
	char *endptr;
	
	if (argc < 6)
		exit(ARGNERR);

	sf = argv[1];
	srcf = argv[2];
	srcf_s = strlen(srcf) + 1;
	wd = argv[3];
	wd_s = strlen(wd) + 1;

	errno = 0;
	lnum = strtol(argv[4], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || lnum <= 0)
		exit(CRDERR);
	
	errno = 0;
	col = strtol(argv[5], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || col <= 0)
		exit(CRDERR);

	if (argc == 6)
		return;
	errno = 0;
	method = strtol(argv[6], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || method < 0 || method > 1)
		exit(METHERR);

	if (argc == 7)
		return;
	errno = 0;
	reparse = strtol(argv[7], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || method < 0 || method > 1)
		exit(REPARSERR);

	/* clang cmd args */
	if (argc == 8)
		return;
	clargs = argv[8];
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
			write(sfd, &method, sizeof(method)) != sizeof(method) ||
			write(sfd, &reparse, sizeof(reparse)) != sizeof(reparse) ||
			write(sfd, &clargs_s, sizeof(clargs_s)) != sizeof(clargs_s) ||
			write(sfd, clargs, clargs_s) != clargs_s ) {
		close(sfd);
		exit(SNDERR);
	}
}

void
recvtype(void)
{
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

	printf("%s\n", t);

	free(t);
	close(sfd);
}
