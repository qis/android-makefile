# Commands
rwildcard = $(wildcard $1/$2)$(foreach d,$(wildcard $1/*),$(call rwildcard,$d,$2))

ifeq ($(OS),Windows_NT)
	create = mkdir $(subst /,\,$1) >nul
	delete = rd /q /s $(subst /,\,$1) >nul
	copy = copy /y $(subst /,\,$1) $(subst /,\,$2) >nul
else
	create = mkdir -p $1
	delete = rm -rf $1
	copy = cp $1 $2
endif

# Application
APP = de.xnetsystems.main
JKS = C:/Workspace/android.jks
JKP = C:/Workspace/android.jkp

# Settings
MIN_SDK_VERSION = 21
TARGET_SDK_VERSION = 27
PLATFORM_VERSION = 28
BUILD_TOOLS_VERSION = 28.0.3

# Tools
JAVAC = $(JAVA_HOME)/bin/javac
D8 = $(ANDROID_SDK_ROOT)/build-tools/$(BUILD_TOOLS_VERSION)/d8
AAPT = $(ANDROID_SDK_ROOT)/build-tools/$(BUILD_TOOLS_VERSION)/aapt
AAPT2 = $(ANDROID_SDK_ROOT)/build-tools/$(BUILD_TOOLS_VERSION)/aapt2
APKSIGNER = $(ANDROID_SDK_ROOT)/build-tools/$(BUILD_TOOLS_VERSION)/apksigner
ZIPALIGN = $(ANDROID_SDK_ROOT)/build-tools/$(BUILD_TOOLS_VERSION)/zipalign
ANDROID = $(ANDROID_SDK_ROOT)/platforms/android-$(PLATFORM_VERSION)/android.jar

# Sources
SOURCES := $(call rwildcard,android/src,*.java)
OBJECTS := $(patsubst android/src/%.java,build/obj/%.class,$(SOURCES))
RESOURCES := $(call rwildcard,android/res,*.*)

all: debug

# Debug
debug: build/debug/android.apk
	adb install -rd $<
	adb shell am start $(APP)/.MainActivity

build/debug/android.apk: build/debug/android-unsigned.apk
	$(APKSIGNER) sign --ks "$(JKS)" --ks-pass file:"$(JKP)" --min-sdk-version ${MIN_SDK_VERSION} --out $@ $<

build/debug/android-unsigned.apk: build/debug/android-unsigned-unaligned.apk
	$(ZIPALIGN) -f 4 $< $@

build/debug/android-unsigned-unaligned.apk: build/debug/classes.dex build/debug/resources.apk
	$(call copy,build/debug/resources.apk,$@)
	cd build/debug && $(AAPT) add android-unsigned-unaligned.apk classes.dex > android-unsigned-unaligned.log

build/debug/resources.apk: build/debug/resources.zip
	$(AAPT2) link --manifest android/AndroidManifest.xml --min-sdk-version $(MIN_SDK_VERSION) --target-sdk-version $(TARGET_SDK_VERSION) -I $(ANDROID) -o $@ $<

build/debug/resources.zip: $(RESOURCES) build/debug
	$(AAPT2) compile --no-crunch --dir android/res -o $@

build/debug/classes.dex: $(OBJECTS) build/debug
	$(D8) --debug $(OBJECTS) --lib $(ANDROID) --classpath build/obj --output build/debug

build/debug:
	@$(call create,$@)

# Release
release: build/release/android.apk

build/release/android.apk: build/release/android-unsigned.apk
	$(APKSIGNER) sign --ks $(JKS) --ks-pass file:$(JKP) --min-sdk-version ${MIN_SDK_VERSION} --out $@ $<

build/release/android-unsigned.apk: build/release/android-unsigned-unaligned.apk
	$(ZIPALIGN) -f 4 $< $@

build/release/android-unsigned-unaligned.apk: build/release/classes.dex build/release/resources.apk
	$(call copy,build/release/resources.apk,$@)
	cd build/debug && $(AAPT) add android-unsigned-unaligned.apk classes.dex > android-unsigned-unaligned.log

build/release/resources.apk: build/release/resources.zip
	$(AAPT2) link --manifest android/AndroidManifest.xml --min-sdk-version $(MIN_SDK_VERSION) --target-sdk-version $(TARGET_SDK_VERSION) -I $(ANDROID) -o $@ $<

build/release/resources.zip: $(RESOURCES) build/release
	$(AAPT2) compile --dir android/res -o $@

build/release/classes.dex: $(OBJECTS) build/release
	$(D8) --release $(OBJECTS) --lib $(ANDROID) --classpath build/obj --output build/debug

build/release:
	@$(call create,$@)

# Common
build/obj/%.class: android/src/%.java build/obj
	$(JAVAC) -d build/obj -classpath build/obj -sourcepath abdroid/src -bootclasspath $(ANDROID) $<

build/obj:
	@$(call create,$@)

# Clean
clean:
	@$(call delete,build)

.PHONY: all debug release
