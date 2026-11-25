TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = SpaceScope

SpaceScope_FILES = main.m SSAppDelegate.m SSLog.m SSUtil.m SSModels.m SSScanner.m SSOverviewVC.m SSFilesVC.m SSDupsVC.m SSCleanVC.m SSAppsVC.m SSSettingsVC.m
SpaceScope_FRAMEWORKS = UIKit Foundation CoreGraphics
SpaceScope_CFLAGS = -fobjc-arc
SpaceScope_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
