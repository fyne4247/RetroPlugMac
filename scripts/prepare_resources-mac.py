#!/usr/bin/env python3
# Create/update Info.plist files from config.h and copy fonts/img into the bundle
# (or ~/Music/<PLUG_NAME>/Resources when PLUG_SHARED_RESOURCES is enabled).

from __future__ import annotations

import os
import sys
import shutil
import plistlib

kAudioUnitType_MusicDevice = "aumu"
kAudioUnitType_MusicEffect = "aumf"
kAudioUnitType_Effect = "aufx"
kAudioUnitType_MIDIProcessor = "aumi"

scriptpath = os.path.dirname(os.path.realpath(__file__))
projectpath = os.path.abspath(os.path.join(scriptpath, os.pardir))

# Xcode runs this with cwd = projects/ (directory containing the .xcodeproj).
# Fall back to project-relative paths if that is not the case.
IPLUG2_ROOT_CANDIDATES = [
    os.path.join(os.getcwd(), "..", "thirdparty", "iPlug2"),
    os.path.join(projectpath, "thirdparty", "iPlug2"),
]

iplug2_root = None
for candidate in IPLUG2_ROOT_CANDIDATES:
    scripts_dir = os.path.join(os.path.abspath(candidate), "Scripts")
    if os.path.isdir(scripts_dir):
        iplug2_root = os.path.abspath(candidate)
        sys.path.insert(0, scripts_dir)
        break

if iplug2_root is None:
    raise SystemExit("error: could not locate thirdparty/iPlug2/Scripts")

from parse_config import parse_config, parse_xcconfig  # noqa: E402


def load_plist(path: str) -> dict:
    with open(path, "rb") as f:
        return plistlib.load(f)


def save_plist(data: dict, path: str) -> None:
    with open(path, "wb") as f:
        plistlib.dump(data, f)


def main() -> None:
    config = parse_config(projectpath)
    xcconfig = parse_xcconfig(os.path.join(iplug2_root, "common-mac.xcconfig"))

    CFBundleGetInfoString = (
        f"{config['BUNDLE_NAME']} v{config['FULL_VER_STR']} {config['PLUG_COPYRIGHT_STR']}"
    )
    CFBundleVersion = config["FULL_VER_STR"]
    CFBundlePackageType = "BNDL"
    CSResourcesFileMapped = True
    LSMinimumSystemVersion = xcconfig["DEPLOYMENT_TARGET"]

    print("Copying resources ...")

    if config["PLUG_SHARED_RESOURCES"]:
        dst = os.path.expanduser("~") + "/Music/" + config["BUNDLE_NAME"] + "/Resources"
    else:
        # When run outside Xcode these env vars are absent; skip the copy then.
        build_dir = os.environ.get("TARGET_BUILD_DIR")
        res_path = os.environ.get("UNLOCALIZED_RESOURCES_FOLDER_PATH")
        if not build_dir or not res_path:
            print("warning: TARGET_BUILD_DIR / UNLOCALIZED_RESOURCES_FOLDER_PATH not set; skipping resource copy")
            dst = None
        else:
            dst = build_dir + res_path

    if dst is not None:
        os.makedirs(dst, exist_ok=True)

        img_dir = os.path.join(projectpath, "resources", "img")
        if os.path.isdir(img_dir):
            for img in os.listdir(img_dir):
                print(f"copying {img} to {dst}")
                shutil.copy(os.path.join(img_dir, img), dst)

        font_dir = os.path.join(projectpath, "resources", "fonts")
        if os.path.isdir(font_dir):
            for font in os.listdir(font_dir):
                print(f"copying {font} to {dst}")
                shutil.copy(os.path.join(font_dir, font), dst)

    print("Processing Info.plist files...")

    # VST3
    plistpath = os.path.join(projectpath, "resources", config["BUNDLE_NAME"] + "-VST3-Info.plist")
    if os.path.exists(plistpath):
        vst3 = load_plist(plistpath)
        vst3["CFBundleExecutable"] = config["BUNDLE_NAME"]
        vst3["CFBundleGetInfoString"] = CFBundleGetInfoString
        vst3["CFBundleIdentifier"] = (
            f"{config['BUNDLE_DOMAIN']}.{config['BUNDLE_MFR']}.vst3.{config['BUNDLE_NAME']}"
        )
        vst3["CFBundleName"] = config["BUNDLE_NAME"]
        vst3["CFBundleVersion"] = CFBundleVersion
        vst3["CFBundleShortVersionString"] = CFBundleVersion
        vst3["LSMinimumSystemVersion"] = LSMinimumSystemVersion
        vst3["CFBundlePackageType"] = CFBundlePackageType
        vst3["CFBundleSignature"] = config["PLUG_UNIQUE_ID"]
        vst3["CSResourcesFileMapped"] = CSResourcesFileMapped
        save_plist(vst3, plistpath)

    # VST2
    plistpath = os.path.join(projectpath, "resources", config["BUNDLE_NAME"] + "-VST2-Info.plist")
    if os.path.exists(plistpath):
        vst2 = load_plist(plistpath)
        vst2["CFBundleExecutable"] = config["BUNDLE_NAME"]
        vst2["CFBundleGetInfoString"] = CFBundleGetInfoString
        vst2["CFBundleIdentifier"] = (
            f"{config['BUNDLE_DOMAIN']}.{config['BUNDLE_MFR']}.vst.{config['BUNDLE_NAME']}"
        )
        vst2["CFBundleName"] = config["BUNDLE_NAME"]
        vst2["CFBundleVersion"] = CFBundleVersion
        vst2["CFBundleShortVersionString"] = CFBundleVersion
        vst2["LSMinimumSystemVersion"] = LSMinimumSystemVersion
        vst2["CFBundlePackageType"] = CFBundlePackageType
        vst2["CFBundleSignature"] = config["PLUG_UNIQUE_ID"]
        vst2["CSResourcesFileMapped"] = CSResourcesFileMapped
        save_plist(vst2, plistpath)

    # Audio Unit v2
    if config["PLUG_TYPE"] == 0:
        if config["PLUG_DOES_MIDI_IN"]:
            COMPONENT_TYPE = kAudioUnitType_MusicEffect
        else:
            COMPONENT_TYPE = kAudioUnitType_Effect
    elif config["PLUG_TYPE"] == 1:
        COMPONENT_TYPE = kAudioUnitType_MusicDevice
    elif config["PLUG_TYPE"] == 2:
        COMPONENT_TYPE = kAudioUnitType_MIDIProcessor
    else:
        COMPONENT_TYPE = kAudioUnitType_MusicDevice

    plistpath = os.path.join(projectpath, "resources", config["BUNDLE_NAME"] + "-AU-Info.plist")
    if os.path.exists(plistpath):
        auv2 = load_plist(plistpath)
        auv2["CFBundleExecutable"] = config["BUNDLE_NAME"]
        auv2["CFBundleGetInfoString"] = CFBundleGetInfoString
        auv2["CFBundleIdentifier"] = (
            f"{config['BUNDLE_DOMAIN']}.{config['BUNDLE_MFR']}.audiounit.{config['BUNDLE_NAME']}"
        )
        auv2["CFBundleName"] = config["BUNDLE_NAME"]
        auv2["CFBundleVersion"] = CFBundleVersion
        auv2["CFBundleShortVersionString"] = CFBundleVersion
        auv2["LSMinimumSystemVersion"] = LSMinimumSystemVersion
        auv2["CFBundlePackageType"] = CFBundlePackageType
        auv2["CFBundleSignature"] = config["PLUG_UNIQUE_ID"]
        auv2["CSResourcesFileMapped"] = CSResourcesFileMapped
        auv2["AudioUnit Version"] = config["PLUG_VERSION_HEX"]
        auv2["AudioComponents"] = [
            {
                "description": config["PLUG_NAME"],
                "factoryFunction": config["AUV2_FACTORY"],
                "manufacturer": config["PLUG_MFR_ID"],
                "name": f"{config['PLUG_MFR']}: {config['PLUG_NAME']}",
                "subtype": config["PLUG_UNIQUE_ID"],
                "type": COMPONENT_TYPE,
                "version": config["PLUG_VERSION_INT"],
                "sandboxSafe": True,
            }
        ]
        save_plist(auv2, plistpath)

    # Audio Unit v3
    if config["PLUG_HAS_UI"]:
        NSEXTENSIONPOINTIDENTIFIER = "com.apple.AudioUnit-UI"
    else:
        NSEXTENSIONPOINTIDENTIFIER = "com.apple.AudioUnit"

    plistpath = os.path.join(projectpath, "resources", config["BUNDLE_NAME"] + "-macOS-AUv3-Info.plist")
    if os.path.exists(plistpath):
        auv3 = load_plist(plistpath)
        auv3["CFBundleExecutable"] = config["BUNDLE_NAME"]
        auv3["CFBundleGetInfoString"] = CFBundleGetInfoString
        auv3["CFBundleIdentifier"] = (
            f"{config['BUNDLE_DOMAIN']}.{config['BUNDLE_MFR']}.app.{config['BUNDLE_NAME']}.AUv3"
        )
        auv3["CFBundleName"] = config["BUNDLE_NAME"]
        auv3["CFBundleVersion"] = CFBundleVersion
        auv3["CFBundleShortVersionString"] = CFBundleVersion
        auv3["LSMinimumSystemVersion"] = "10.12.0"
        auv3["CFBundlePackageType"] = "XPC!"
        tag = "Synth" if config["PLUG_TYPE"] == 1 else "Effects"
        auv3["NSExtension"] = {
            "NSExtensionAttributes": {
                "AudioComponentBundle": f"com.tommitytom.app.{config['BUNDLE_NAME']}.AUv3Framework",
                "AudioComponents": [
                    {
                        "description": config["PLUG_NAME"],
                        "manufacturer": config["PLUG_MFR_ID"],
                        "name": f"{config['PLUG_MFR']}: {config['PLUG_NAME']}",
                        "subtype": config["PLUG_UNIQUE_ID"],
                        "type": COMPONENT_TYPE,
                        "version": config["PLUG_VERSION_INT"],
                        "sandboxSafe": True,
                        "tags": [tag],
                    }
                ],
            },
            "NSExtensionPointIdentifier": NSEXTENSIONPOINTIDENTIFIER,
            "NSExtensionPrincipalClass": "IPlugAUViewController",
        }
        save_plist(auv3, plistpath)

    # AAX
    plistpath = os.path.join(projectpath, "resources", config["BUNDLE_NAME"] + "-AAX-Info.plist")
    if os.path.exists(plistpath):
        aax = load_plist(plistpath)
        aax["CFBundleExecutable"] = config["BUNDLE_NAME"]
        aax["CFBundleGetInfoString"] = CFBundleGetInfoString
        aax["CFBundleIdentifier"] = (
            f"{config['BUNDLE_DOMAIN']}.{config['BUNDLE_MFR']}.aax.{config['BUNDLE_NAME']}"
        )
        aax["CFBundleName"] = config["BUNDLE_NAME"]
        aax["CFBundleVersion"] = CFBundleVersion
        aax["CFBundleShortVersionString"] = CFBundleVersion
        aax["LSMinimumSystemVersion"] = LSMinimumSystemVersion
        aax["CSResourcesFileMapped"] = CSResourcesFileMapped
        save_plist(aax, plistpath)

    # Standalone macOS app
    plistpath = os.path.join(projectpath, "resources", config["BUNDLE_NAME"] + "-macOS-Info.plist")
    if os.path.exists(plistpath):
        macOSapp = load_plist(plistpath)
        macOSapp["CFBundleExecutable"] = config["BUNDLE_NAME"]
        macOSapp["CFBundleGetInfoString"] = CFBundleGetInfoString
        macOSapp["CFBundleIdentifier"] = (
            f"{config['BUNDLE_DOMAIN']}.{config['BUNDLE_MFR']}.app.{config['BUNDLE_NAME']}"
        )
        macOSapp["CFBundleName"] = config["BUNDLE_NAME"]
        macOSapp["CFBundleVersion"] = CFBundleVersion
        macOSapp["CFBundleShortVersionString"] = CFBundleVersion
        macOSapp["LSMinimumSystemVersion"] = LSMinimumSystemVersion
        macOSapp["CFBundlePackageType"] = CFBundlePackageType
        macOSapp["CFBundleSignature"] = config["PLUG_UNIQUE_ID"]
        macOSapp["CSResourcesFileMapped"] = CSResourcesFileMapped
        macOSapp["NSPrincipalClass"] = "SWELLApplication"
        macOSapp["NSMainNibFile"] = config["BUNDLE_NAME"] + "-macOS-MainMenu"
        macOSapp["LSApplicationCategoryType"] = "public.app-category.music"
        macOSapp["CFBundleIconFile"] = config["BUNDLE_NAME"] + ".icns"
        save_plist(macOSapp, plistpath)

    print("prepare_resources-mac.py: done")


if __name__ == "__main__":
    main()
