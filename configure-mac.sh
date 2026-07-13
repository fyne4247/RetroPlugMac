#!/bin/bash
set -euo pipefail

# Prefer a local premake5-mac binary if present; otherwise use Homebrew/system premake5.
if [[ -x "./premake5-mac" ]]; then
  PREMAKE="./premake5-mac"
elif command -v premake5 >/dev/null 2>&1; then
  PREMAKE="premake5"
else
  echo "error: premake5 not found (expected ./premake5-mac or premake5 on PATH)" >&2
  exit 1
fi

"$PREMAKE" xcode4

# NanoVG ObjC source needs ARC; IPlugAPP main must be treated as ObjC++.
if [[ -f "build/xcode4/RetroPlug-app.xcodeproj/project.pbxproj" ]]; then
  sed -i '' 's+/\* IGraphicsNanoVG_src.m \*/;+/\* IGraphicsNanoVG_src.m \*/; settings = {COMPILER_FLAGS = "-fobjc-arc"; };+g' "build/xcode4/RetroPlug-app.xcodeproj/project.pbxproj"
  sed -i '' 's+lastKnownFileType = sourcecode.cpp.cpp; name = IPlugAPP_main.cpp;+explicitFileType = sourcecode.cpp.objcpp; name = IPlugAPP_main.cpp;+g' "build/xcode4/RetroPlug-app.xcodeproj/project.pbxproj"
fi

echo "configure-mac.sh: generated Xcode projects under build/xcode4/"
