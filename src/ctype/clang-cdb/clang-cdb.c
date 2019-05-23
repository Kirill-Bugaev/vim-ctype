#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <clang-c/CXCompilationDatabase.h>

#include "config.h"
#include "../shared.h"

static void parsecmdargs(int, char *[]);
static CXCompilationDatabase getcdb();
static void savcc(const char *, const char *, char *);
static void freefnwd(CXString, CXString);
static void freeccs(CXString, CXString, CXCompileCommands);
static void getccs(CXCompilationDatabase cdb);

static char *srcf;	/* source file */
static long m = 3;	/* method:	
							1 - print first valid compile command
				   			2 - print all valid compile commands from all cdbs
							3 - print first found compile command (no check)
							4 - print all found compile commands (no check) from all cdbs */
static char *cdb_sp;	/* compilation db search path (initial is source file
						   path, last found cdb dir further) */
static char *clang;
static char **fns = NULL;		/* extracted file names */
static char **wds = NULL;		/* extracted working dirs */
static char **ccsargs = NULL;	/* extracted compile commands args */
static unsigned s;				/* size of fns, wds and ccsargs */

enum errors {
	ARGNERR = 1,
	METHERR,
	NOSRCERR,
	MEMERR,
	CHDIRERR,
	ESCERR,
	CLEXEERR,
	FORKERR,
	NOCDBERR,
};

void
parsecmdargs(int argc, char *argv[])
{
	char *endptr;
	
	if (argc < 2)
		exit(ARGNERR);

	srcf = argv[1];

	if (argc == 2)
		return;
	errno = 0;
	m = strtol(argv[2], &endptr, 10);
	if (errno != 0 || *endptr != '\0' || m < 1 || m > 4)
		exit(METHERR);

	/* path to clang */
	if (argc == 3) 
		return;
	clcmd = argv[3];

	/* path to clang++ */
	if (argc == 4) 
		return;
	clppcmd = argv[4];
}

CXCompilationDatabase
getcdb()
{
	char *d, *e;
	CXCompilationDatabase cdb;
	CXCompilationDatabase_Error dberr;

	if (!(d = strdup(cdb_sp)))
		exit(MEMERR);

	for (e = d + strlen(d) - 1; e >= d; --e) {
		if (*e == '/') {
			if (e != d)
				*e = '\0';
			else
				*(e + 1) = '\0';
			cdb = clang_CompilationDatabase_fromDirectory(d, &dberr);
			if (dberr == CXCompilationDatabase_NoError) {
				free(cdb_sp);
				cdb_sp = d;
				return cdb;
			}
			else
				clang_CompilationDatabase_dispose(cdb);
		}
	}

	free(d);
	return (CXCompilationDatabase) NULL;
}

void
savcc(const char *fn, const char *wd, char *args)
{
	if (!(fns = realloc(fns, s + 1)) ||
			!(wds = realloc(wds, s + 1)) ||
			!(ccsargs = realloc(ccsargs, s + 1)) ||
			!(*(fns + s) = strdup(fn)) ||
			!(*(wds + s) = strdup(wd)))
		exit(MEMERR);
	*(ccsargs + s) = args;
	++s;
}

void
freefnwd(CXString cx_fn, CXString cx_wd)
{
	clang_disposeString(cx_fn);
	clang_disposeString(cx_wd);
}

void
freeccs(CXString cx_fn, CXString cx_wd, CXCompileCommands ccs)
{
	freefnwd(cx_fn, cx_wd);
	clang_CompileCommands_dispose(ccs);
}

void getccs(CXCompilationDatabase cdb)
{
	CXCompileCommands ccs;
	CXCompileCommand cc;
	CXString cx_wd, cx_fn, cx_arg;
	unsigned ccs_s, argnum;
	const char *wd, *fn, *arg;
	char *args;
	int skipnext = 0;

	ccs = clang_CompilationDatabase_getCompileCommands(cdb, srcf);

	ccs_s = clang_CompileCommands_getSize(ccs);
	for (unsigned i = 0; i < ccs_s; ++i) {
		cc = clang_CompileCommands_getCommand(ccs, i);

		cx_wd = clang_CompileCommand_getDirectory(cc);
		wd = clang_getCString(cx_wd);
		cx_fn = clang_CompileCommand_getFilename(cc);
		fn = clang_getCString(cx_fn);

		if (!(args = malloc(1)))
			exit(MEMERR);
		*args = '\0';
		argnum = clang_CompileCommand_getNumArgs(cc);
		/* arg 0 is the compiler executable */
		for (unsigned j = 1; j < argnum; ++j) {
			if (skipnext) {
				skipnext = 0;
				continue;
			}
			cx_arg = clang_CompileCommand_getArg(cc, j);
			arg = clang_getCString(cx_arg);

			if (strcmp(arg, fn) == 0) {
				/* arg is source file, skip */
				clang_disposeString(cx_arg);
				continue;
			} else {
				if (*arg == '-' && (*(arg + 1) == 'x' || *(arg + 1) == 'o')) {
					/* arg is '-x' or '-o', skip */
					if (strlen(arg) == 2)
						/* not merged arg, skip next arg */
						skipnext = 1;
					clang_disposeString(cx_arg);
					continue;
				} else {
					/* appropriate arg */
					if (!(args = realloc(args, strlen(args) + strlen(arg) + 2)))
						exit(MEMERR);
					strcat(args, arg);
					strcat(args, " ");
				}
			}

			clang_disposeString(cx_arg);
		}
		if (*args != '\0')
			*(args + strlen(args) - 1) = '\0';	/* remove trailing whitespace */

		if (m == 3 || m == 4) {
			/* validation not required */
			savcc(fn, wd, args);
			if (m == 3) {
				freeccs(cx_fn, cx_wd, ccs);
				return;
			}
			freefnwd(cx_fn, cx_wd);
			continue;
		}

		/* check obtained args */
		pid_t p = fork();
		if (p == 0) {
			/* --- child process --- */
			if (chdir(wd) == -1)
				exit(CHDIRERR);
			
			char *ewd, *efn, *eargs;
			if (!(ewd = expesc(wd)))
				exit(ESCERR);
			if (!(efn = expesc(fn)))
				exit(ESCERR);
			if (!(eargs = expesc(args)))
				exit(ESCERR);

			/* cmd = clang + " -working-directory=" + "'" + ewd + "'" +
			 * " -emit-ast " + "'" + efn + "'" + " -o /dev/null " + eargs */
			char *cmd = malloc(strlen(clang) + sizeof("-working-directory='") +
					strlen(ewd) + sizeof("' -emit-ast ") + strlen(efn) +
				   	sizeof("' -o /dev/null") + strlen(eargs));
			*cmd = '\0';
			strcat(cmd, clang);
			strcat(cmd, " -working-directory='");
			strcat(cmd, ewd);
			strcat(cmd, "' -emit-ast '");
			strcat(cmd, efn);
			strcat(cmd, "' -o /dev/null ");
			strcat(cmd, eargs);

			if (execl("/bin/sh", "sh", "-c", cmd, NULL) == -1)
				exit(CLEXEERR);
			free(ewd);
			free(efn);
			free(eargs);
			free(cmd);
			/* --- end of child process --- */
		} else if (p == -1)
			exit(FORKERR);

		int st;
		if (waitpid(p, &st , 0) == -1)
			exit(FORKERR);
		if (WIFEXITED(st) && WEXITSTATUS(st) == 0) {
			/* save valid data */
			savcc(fn, wd, args);
			
			if (m == 1) {
				/* only one valid compile command required */
				freeccs(cx_fn, cx_wd, ccs);
				return;
			}
		} else {
			/* ast failed */
			free(args);
		}

		freefnwd(cx_fn, cx_wd);
	}

	clang_CompileCommands_dispose(ccs);
}

int
main(int argc, char *argv[])
{
	char *ext;
	int cdbfound = 0, ccfound = 0;
	CXCompilationDatabase cdb;

	parsecmdargs(argc, argv);
	
	/* Determine which clang facility use (clang or clang++) */
	if ((ext = strrchr(srcf, '.')) && strcmp(ext, (char *) &".cpp") == 0)
		clang = clppcmd;
	else
		clang = clcmd;

	if (!(srcf = realpath(srcf, NULL)))
		exit(NOSRCERR);

	if (!(cdb_sp = strdup(srcf)))
		exit(MEMERR);
	
	while ((cdb = getcdb()) && (m == 2 || !ccfound)) {
		cdbfound = 1;
		getccs(cdb);

		printf("%s\n", cdb_sp);
		printf("%u\n", s);
		if (s > 0)
			ccfound = 1;
		for (unsigned i = 0; i < s; ++i) {
			printf("%s\n", *(fns + i));
			free(*(fns + i));
			printf("%s\n", *(wds + i));
			free(*(wds + i));
			printf("%s\n", *(ccsargs + i));
			free(*(ccsargs + i));
		}

		if (s > 0) {
			free(fns);
			fns = NULL;
			free(wds);
			wds = NULL;
			free(ccsargs);
			ccsargs = NULL;
			s = 0;
		}
		clang_CompilationDatabase_dispose(cdb);
	}

	if (!cdbfound)
		exit(NOCDBERR);
	
	free(cdb_sp);
}
