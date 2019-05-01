#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "shared.h"

char *
expesc(const char *s) 
{
	char *d, *p, c;

	if (!(d = p = malloc(strlen(s) * 2 + 1)))
		return NULL;

	while (c = *(s++))
		switch(c) {
			case '\a': 
				*(p++) = '\\';
				*(p++) = 'a';
				break;
			case '\b': 
				*(p++) = '\\';
				*(p++) = 'b';
				break;
			case '\t': 
				*(p++) = '\\';
				*(p++) = 't';
				break;
			case '\n': 
				*(p++) = '\\';
				*(p++) = 'n';
				break;
			case '\v': 
				*(p++) = '\\';
				*(p++) = 'v';
				break;
			case '\f': 
				*(p++) = '\\';
				*(p++) = 'f';
				break;
			case '\r': 
				*(p++) = '\\';
				*(p++) = 'r';
				break;
			case '\\': 
				*(p++) = '\\';
				*(p++) = '\\';
				break;
			case '\"': 
				*(p++) = '\\';
				*(p++) = '\"';
				break;
			case '\'': 
				*(p++) = '\\';
				*(p++) = '\'';
				break;
			default:
				*(p++) = c;
		}

	*p = '\0';
	if (!(d = realloc(d, strlen(d) + 1)))
		return NULL;

	return d;
}
