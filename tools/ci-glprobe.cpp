// TEMP CI diagnostic probe (throwaway ci-win-nanovg branch). Mirrors the GL
// include preamble DPF's NanoVG.cpp relies on, to reproduce the "glext typedefs
// undeclared under MSVC" failure in isolation. Compiled by build.bat's :rpdiag.
#include <windows.h>
#include <GL/gl.h>
#include <GL/glext.h>

PFNGLACTIVETEXTUREPROC rp_probe_pfn = 0;   // needs glext's GL_VERSION_1_3 typedef
GLchar                 rp_probe_char = 0;  // needs glext's GL_VERSION_2_0 type
int                    rp_probe_enum = GL_TEXTURE0; // needs glext's enum
