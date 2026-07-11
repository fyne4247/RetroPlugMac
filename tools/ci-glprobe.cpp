// TEMP CI diagnostic probe (throwaway ci-win-nanovg branch). Mirrors DPF NanoVG's
// GL include preamble to reproduce/inspect the "glext typedefs undeclared under
// MSVC" failure in isolation. Compiled + preprocessed by build.bat's :rpdiag.
#include <windows.h>
#include <GL/gl.h>
#include <GL/glext.h>

PFNGLACTIVETEXTUREPROC rp_probe_pfn = 0;
