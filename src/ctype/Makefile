.POSIX:

include config.mk

CDBSRC = ./clang-cdb/clang-cdb.c shared.c
SERVSRC = ./clang-gettype/server/clang-gettype-server.c shared.c
CLNTSRC = ./clang-gettype/client/clang-gettype-client.c

CDBOBJ = $(CDBSRC:.c=.o)
SERVOBJ = $(SERVSRC:.c=.o)
CLNTOBJ = $(CLNTSRC:.c=.o)

all: options cdb server client
	
options:
	@echo ctype build options:
	@echo "CFLAGS  = $(CTCFLAGS)"
	@echo "LDFLAGS = $(CTLDFLAGS)"
	@echo "CC      = $(CC)"

$(CDBOBJ): config.mk

$(SERVOBJ): config.mk

$(CLNTOBJ): config.mk

cdb: $(CDBOBJ)
	$(CC) -o $@ $(CDBOBJ) $(CTLDFLAGS)
	
server: $(SERVOBJ)
	$(CC) -o $@ $(SERVOBJ) $(CTLDFLAGS)

client: $(CLNTOBJ)
	$(CC) -o $@ $(CLNTOBJ)

clean:
	rm -f cdb server client $(CDBOBJ) $(SERVOBJ) $(CLNTOBJ)

install: cdb server client
	mkdir -p ../../bin/ctype
	cp -f cdb server client ../../bin/ctype
	chmod 755 ../../bin/ctype/cdb ../../bin/ctype/server ../../bin/ctype/client

uninstall:
	rm -f ../../bin/ctype/cdb ../../bin/ctype/server ../../bin/ctype/client
