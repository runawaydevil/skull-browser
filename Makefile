# Include makefile config
include config.mk

# Token lib generation
TLIST = common/tokenize.list
THEAD = common/tokenize.h
TSRC  = common/tokenize.c

SRCS  = $(filter-out $(TSRC),$(wildcard *.c) $(wildcard common/*.c) $(wildcard common/clib/*.c) $(wildcard clib/*.c) $(wildcard clib/soup/*.c) $(wildcard widgets/*.c)) $(TSRC)
HEADS = $(wildcard *.h) $(wildcard common/*.h) $(wildcard common/clib/*.h) $(wildcard widgets/*.h) $(wildcard clib/*.h) $(wildcard clib/soup/*.h) $(THEAD) buildopts.h
OBJS  = $(foreach obj,$(SRCS:.c=.o),$(obj))

EXT_SRCS = $(filter-out $(TSRC),$(wildcard extension/*.c) $(wildcard extension/clib/*.c) $(wildcard common/*.c)) $(wildcard common/clib/*.c) $(TSRC)
EXT_OBJS = $(foreach obj,$(EXT_SRCS:.c=.o),$(obj))

# List of sources used to generate Lua API documentation
# Must be kept in sync with doc/docgen.ld
DOC_SRCS = $(filter-out lib/markdown.lua lib/lousy/init.lua,$(shell for d in doc/luadoc lib common/clib; do find $$d -type f; done)) tests/lib.lua

all: options newline skull skull.1 skull.so apidoc

options:
	@echo luakit build options:
	@echo "CC           = $(CC)"
	@echo "LUA_PKG_NAME = $(LUA_PKG_NAME)"
	@echo "LUA_BIN_NAME = $(LUA_BIN_NAME)"
	@echo "CFLAGS       = $(CFLAGS)"
	@echo "CPPFLAGS     = $(CPPFLAGS)"
	@echo "LDFLAGS      = $(LDFLAGS)"
	@echo "MANPREFIX    = $(MANPREFIX)"
	@echo "DOCDIR       = $(DOCDIR)"
	@echo "XDGPREFIX    = $(XDGPREFIX)"
	@echo "PIXMAPDIR    = $(PIXMAPDIR)"
	@echo "APPDIR       = $(APPDIR)"
	@echo "LIBDIR       = $(LIBDIR)"
	@echo
	@echo build targets:
	@echo "SRCS     = $(SRCS)"
	@echo "HEADS    = $(HEADS)"
	@echo "OBJS     = $(OBJS)"
	@echo "EXT_SRCS = $(EXT_SRCS)"
	@echo "EXT_OBJS = $(EXT_OBJS)"

$(THEAD) $(TSRC): $(TLIST)
	$(LUA_BIN_NAME) ./build-utils/gentokens.lua $(TLIST) $@

# FORCE porque PREFIX e XDGPREFIX podem vir da linha de comando: sem isso o
# header guarda os caminhos da primeira build e o binario procura os modulos
# no lugar errado. Regera sempre, mas so substitui se o conteudo mudou, para
# nao recompilar a arvore inteira a toa.
buildopts.h: buildopts.h.in FORCE
	@sed -e 's#LUAKIT_INSTALL_PATH .*#LUAKIT_INSTALL_PATH "$(PREFIX)/share/skull"#' \
		-e 's#LUAKIT_CONFIG_PATH .*#LUAKIT_CONFIG_PATH "$(XDGPREFIX)"#' \
		-e 's#LUAKIT_DOC_PATH .*#LUAKIT_DOC_PATH "$(DOCDIR)"#' \
		-e 's#LUAKIT_MAN_PATH .*#LUAKIT_MAN_PATH "$(MANPREFIX)"#' \
		-e 's#LUAKIT_PIXMAP_PATH .*#LUAKIT_PIXMAP_PATH "$(PIXMAPDIR)"#' \
		-e 's#LUAKIT_APP_PATH .*#LUAKIT_APP_PATH "$(APPDIR)"#' \
		-e 's#LUAKIT_LIB_PATH .*#LUAKIT_LIB_PATH "$(LIBDIR)"#' \
		buildopts.h.in > buildopts.h.tmp
	@if cmp -s buildopts.h.tmp buildopts.h; then rm -f buildopts.h.tmp; else mv buildopts.h.tmp buildopts.h; fi

FORCE:

$(filter-out $(EXT_OBJS),$(OBJS)) $(EXT_OBJS): $(HEADS) config.mk

$(filter-out $(EXT_OBJS),$(OBJS)) : %.o : %.c
	@echo $(CC) -c $< -o $@
	@$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

$(EXT_OBJS) : %.o : %.c
	@echo $(CC) -c $< -o $@
	@$(CC) -c $(CFLAGS) -DLUAKIT_WEB_EXTENSION -fPIC $(CPPFLAGS) $< -o $@

widgets/webview.o: $(wildcard widgets/webview/*.c)

skull: $(OBJS)
	@echo $(CC) -o $@ $(OBJS)
	@$(CC) -o $@ $(OBJS) $(LDFLAGS)

skull.so: $(EXT_OBJS)
	@echo $(CC) -o $@ $(EXT_OBJS)
	@$(CC) -o $@ $(EXT_OBJS) -shared $(LDFLAGS)

skull.1: skull.1.in
	@sed "s|LUAKITVERSION|$(VERSION)|" $< > $@

doc/apidocs/index.html: $(DOC_SRCS) $(wildcard build-utils/docgen/*)
	rm -rf doc/apidocs
	mkdir doc/apidocs
	$(LUA_BIN_NAME) ./build-utils/docgen/makedoc.lua

apidoc: doc/apidocs/index.html

doc: buildopts.h $(THEAD) $(TSRC)
	doxygen -s doc/luakit.doxygen

clean:
	rm -rf doc/apidocs doc/html skull $(OBJS) $(EXT_OBJS) $(TSRC) $(THEAD) buildopts.h skull.1 skull.so

install: all
	install -d $(DESTDIR)$(DOCDIR)/classes
	install -d $(DESTDIR)$(DOCDIR)/modules
	install -d $(DESTDIR)$(DOCDIR)/pages
	install -m644 README.md AUTHORS COPYING.GPLv3 $(DESTDIR)$(DOCDIR)
	install -m644 doc/apidocs/classes/* $(DESTDIR)$(DOCDIR)/classes
	install -m644 doc/apidocs/modules/* $(DESTDIR)$(DOCDIR)/modules
	install -m644 doc/apidocs/pages/* $(DESTDIR)$(DOCDIR)/pages
	install -m644 doc/apidocs/*.html $(DESTDIR)$(DOCDIR)
	install -d $(DESTDIR)$(PREFIX)/share/skull/lib/lousy/widget
	install -m644 lib/*.* $(DESTDIR)$(PREFIX)/share/skull/lib
	install -m644 lib/lousy/*.* $(DESTDIR)$(PREFIX)/share/skull/lib/lousy
	install -m644 lib/lousy/widget/*.* $(DESTDIR)$(PREFIX)/share/skull/lib/lousy/widget
	install -d $(DESTDIR)$(LIBDIR)
	install -m644 skull.so $(DESTDIR)$(LIBDIR)/skull.so
	install -d $(DESTDIR)$(PREFIX)/bin
	install skull $(DESTDIR)$(PREFIX)/bin/skull
	install -d $(DESTDIR)$(XDGPREFIX)/skull/
	install -m644 config/*.lua $(DESTDIR)$(XDGPREFIX)/skull/
	install -d $(DESTDIR)$(PIXMAPDIR)
	install -m644 extras/skull.png $(DESTDIR)$(PIXMAPDIR)
	install -m644 extras/skull.svg $(DESTDIR)$(PIXMAPDIR)
	install -d $(DESTDIR)$(APPDIR)
	install -m644 extras/skull.desktop $(DESTDIR)$(APPDIR)
	install -d $(DESTDIR)$(MANPREFIX)/man1/
	install -m644 skull.1 $(DESTDIR)$(MANPREFIX)/man1/
	install -d $(DESTDIR)$(PREFIX)/share/skull/resources/icons
	for i in resources/icons/*; do install -m644 "$$i" "$(DESTDIR)$(PREFIX)/share/skull/resources/icons"; done

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/bin/skull $(DESTDIR)$(PREFIX)/share/skull $(DESTDIR)$(PREFIX)/lib/luakit
	rm -rf $(DESTDIR)$(MANPREFIX)/man1/skull.1 $(DESTDIR)$(XDGPREFIX)/skull
	rm -rf $(DESTDIR)$(APPDIR)/skull.desktop $(DESTDIR)$(PIXMAPDIR)/skull.png

tests/util.so: tests/util.c Makefile
	$(CC) -fPIC $(CFLAGS) $(CPPFLAGS) -shared $< $(LDFLAGS) -o $@

run-tests: skull skull.so tests/util.so
	@$(LUA_BIN_NAME) tests/run_test.lua

newline: options;@echo
.PHONY: all clean options install newline apidoc doc default FORCE
