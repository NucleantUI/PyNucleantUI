"""nucleant — Swift-backed UI toolkit.

The five native modules (`app`, `canvas`, `widget`, `window`, `_layout`) are
compiled into a *single* shared library, `_nucleant.so`, rather than one `.so`
each.  SwiftPM statically absorbs a same-package target dependency even when
that target is also its own dynamic product, so a `.so` per module put
`PNU_Core`, `PNU_Layout`, `PyNucleantUI` and `PNU_App` in several images at
once.  Two copies of a Swift module in one process means two type descriptors,
which breaks conformance lookup and generic metadata instantiation across the
boundary (`nucleant.widget`'s `PyWidgetBase` would not be `nucleant.window`'s).
One image keeps exactly one descriptor per module.

CPython derives an extension's init symbol from the *last component* of the
module name, so loading that one file as `nucleant.app` calls `PyInit_app` and
as `nucleant.window` calls `PyInit_window` — each `@PyModule` still emits its
own `@_cdecl("PyInit_<name>")`, they simply share a library now.  The finder
below is what points those names at the shared file; without it the import
system would look for `nucleant/app.so` and not find it.
"""

import os as _os
import sys as _sys
from importlib.machinery import ExtensionFileLoader as _ExtensionFileLoader
from importlib.machinery import ModuleSpec as _ModuleSpec

# Module names whose PyInit_* symbols live in _nucleant.so. `layout` is absent
# on purpose: it is the pure-Python wrapper in layout.py over native `_layout`.
_NATIVE_MODULES = frozenset({"app", "canvas", "widget", "window", "_layout"})

_NATIVE_LIB = _os.path.join(_os.path.dirname(__file__), "core.so")

_PREFIX = __name__ + "."


class _NucleantNativeFinder:
    """Maps `nucleant.<native>` onto the single shared library."""

    @staticmethod
    def find_spec(fullname, path=None, target=None):
        if not fullname.startswith(_PREFIX):
            return None
        name = fullname[len(_PREFIX):]
        # Direct children only — a dotted tail is somebody else's submodule
        # (nucleant.nes ships from a sibling wheel and must fall through).
        if name not in _NATIVE_MODULES:
            return None
        return _ModuleSpec(
            fullname,
            _ExtensionFileLoader(fullname, _NATIVE_LIB),
            origin=_NATIVE_LIB,
        )


# Ahead of PathFinder so these names resolve to the shared library. Guarded so
# a re-import (or a reload) doesn't stack duplicate finders.
if not any(f is _NucleantNativeFinder for f in _sys.meta_path):
    _sys.meta_path.insert(0, _NucleantNativeFinder)
