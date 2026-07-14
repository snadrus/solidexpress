// solidexpress shim replacing FreeCAD's SketcherGlobal.h for standalone
// PlaneGCS builds. We build PlaneGCS as a plain shared library with default
// visibility, so the export macro is empty.
#pragma once
#ifndef SketcherExport
#define SketcherExport
#endif
