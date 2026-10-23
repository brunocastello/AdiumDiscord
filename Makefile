# Builds Discord.AdiumLibpurplePlugin for Adium 1.5.10 (Mac OS X 10.6+, i386 + x86_64).
#
#   ./scripts/fetch-deps.sh      # once: SDK + Adium frameworks into deps/
#   make                         # build/Discord.AdiumLibpurplePlugin
#   make dist                    # build/Discord-<version>.zip
#
# Current Xcode can no longer link i386, so on a modern Mac use `make ARCHS=x86_64`.
# CI cross-compiles both architectures on Linux with osxcross (see .github/workflows/build.yml).

VERSION ?= 0.1.0
PURPLE_DISCORD_REV := $(shell git -C purple-discord rev-parse --short HEAD 2>/dev/null)

ARCHS ?= i386 x86_64
DEPS  ?= deps
SDK   ?= $(DEPS)/MacOSX10.6.sdk
FW    := $(DEPS)/Frameworks

# Per-architecture compiler drivers; CI overrides these with osxcross's o32-clang / o64-clang.
CC_i386   ?= clang -arch i386
CC_x86_64 ?= clang -arch x86_64
LIPO      ?= lipo

BUILD  := build
PLUGIN := $(BUILD)/Discord.AdiumLibpurplePlugin

COMMON_FLAGS := -isysroot $(SDK) -mmacosx-version-min=10.6 -O2 -g \
	-F$(FW) \
	-I$(FW)/libpurple.framework/Headers \
	-I$(FW)/libglib.framework/Headers \
	-I$(FW)/libgobject.framework/Headers \
	-I$(FW)/libgmodule.framework/Headers \
	-I$(FW)/libjson-glib.framework/Headers

# purple-discord is built as a static prpl (no PURPLE_PLUGINS), which makes PURPLE_INIT_PLUGIN
# emit purple_init_discord_plugin() for ADDiscordPlugin to call.
DISCORD_FLAGS := -std=gnu99 -w \
	-DMARKDOWN_PIDGIN -DDISCORD_PLUGIN_VERSION='"$(PURPLE_DISCORD_REV)"' \
	-include Source/ADGioCompat.h \
	-Ipurple-discord -Ipurple-discord/purple2compat

OUR_FLAGS := -Wall -Wno-unknown-pragmas -Wno-deprecated-declarations -ISource

# AIUtilities.framework's install name is @rpath-relative, so point the rpath at Adium's Frameworks.
LDFLAGS := -bundle -mmacosx-version-min=10.6 -isysroot $(SDK) -F$(FW) \
	-Wl,-rpath,@executable_path/../Frameworks \
	-framework Cocoa -framework CoreServices \
	-framework Adium -framework AdiumLibpurple -framework AIUtilities \
	-framework libpurple -framework libglib -framework libgobject -framework libjson-glib \
	-lz

DISCORD_SRCS := \
	purple-discord/libdiscord.c \
	purple-discord/markdown.c \
	purple-discord/discord_lottie.c \
	purple-discord/purple2compat/http.c \
	purple-discord/purple2compat/purple-socket.c

OUR_C_SRCS    := Source/ADGioCompat.c
OUR_OBJC_SRCS := Source/ADDiscordPlugin.m Source/ADDiscordService.m Source/ADDiscordAccount.m

obj = $(BUILD)/$(1)/$(notdir $(basename $(2))).o
DISCORD_OBJS = $(foreach s,$(DISCORD_SRCS),$(call obj,$(1),$(s)))
OUR_OBJS     = $(foreach s,$(OUR_C_SRCS) $(OUR_OBJC_SRCS),$(call obj,$(1),$(s)))

.PHONY: all dist clean
all: $(PLUGIN)

define ARCH_RULES
$(BUILD)/$(1)/%.o: purple-discord/%.c Source/ADGioCompat.h | $(BUILD)/$(1)
	$$(CC_$(1)) $(COMMON_FLAGS) $(DISCORD_FLAGS) -c $$< -o $$@
$(BUILD)/$(1)/%.o: purple-discord/purple2compat/%.c | $(BUILD)/$(1)
	$$(CC_$(1)) $(COMMON_FLAGS) $(DISCORD_FLAGS) -c $$< -o $$@
$(BUILD)/$(1)/%.o: Source/%.c | $(BUILD)/$(1)
	$$(CC_$(1)) $(COMMON_FLAGS) -std=gnu99 $(OUR_FLAGS) -c $$< -o $$@
$(BUILD)/$(1)/%.o: Source/%.m $(wildcard Source/*.h) | $(BUILD)/$(1)
	$$(CC_$(1)) $(COMMON_FLAGS) $(OUR_FLAGS) -include Source/ADPrefix.h -c $$< -o $$@
$(BUILD)/$(1)/Discord: $(call DISCORD_OBJS,$(1)) $(call OUR_OBJS,$(1))
	$$(CC_$(1)) $(LDFLAGS) $$^ -o $$@
$(BUILD)/$(1):
	mkdir -p $$@
endef
$(foreach a,$(ARCHS),$(eval $(call ARCH_RULES,$(a))))

$(PLUGIN): $(foreach a,$(ARCHS),$(BUILD)/$(a)/Discord) Resources/Info.plist $(wildcard Resources/*.png)
	rm -rf $@
	mkdir -p $@/Contents/MacOS $@/Contents/Resources
	$(LIPO) -create $(foreach a,$(ARCHS),$(BUILD)/$(a)/Discord) -output $@/Contents/MacOS/Discord
	sed -e 's/@VERSION@/$(VERSION)/g' -e 's/@PURPLE_DISCORD_REV@/$(PURPLE_DISCORD_REV)/g' \
		Resources/Info.plist > $@/Contents/Info.plist
	cp Resources/*.png $@/Contents/Resources/
	printf 'BNDL????' > $@/Contents/PkgInfo

dist: $(PLUGIN)
	cd $(BUILD) && rm -f Discord-$(VERSION).zip && zip -qry Discord-$(VERSION).zip Discord.AdiumLibpurplePlugin

clean:
	rm -rf $(BUILD)
