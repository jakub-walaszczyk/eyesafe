APP_NAME := EyeSafe
BUILD_DIR := ./build
CONFIG := Release
DESTINATION := platform=macOS,arch=arm64
APP_PATH := $(BUILD_DIR)/Build/Products/$(CONFIG)/$(APP_NAME).app

.PHONY: build run clean install uninstall

build:
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) \
		-destination '$(DESTINATION)' \
		-quiet \
		build
	@echo "Built: $(APP_PATH)"

run: build
	open $(APP_PATH)

clean:
	rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"

install: build
	cp -R $(APP_PATH) /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

uninstall:
	rm -rf /Applications/$(APP_NAME).app
	@echo "Removed /Applications/$(APP_NAME).app"
