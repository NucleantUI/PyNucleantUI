"""Type stubs for the `nucleant` native module (PyNucleantUI, Swift-backed).

Mirrors the `@PyModule` / `@PyClass` / `@PyProperty` / `@PyMethod` surface
declared in Sources/PyNucleantUI/PyApi. `nucleant` is a `@PyModule` whose
`modules` list has entries, so it is a package (folder) with nested module
files rather than a single module.

Registered submodules (present in `PyNucleantUI_Package.modules`):
  - nucleant.app       → App
  - nucleant.window    → WindowBase

Defined but NOT yet registered (the classes exist and are annotated, but no
active `@PyModule.py_classes` / `modules` entry exposes them yet — wire them
up in the Swift package before importing at runtime):
  - nucleant.layout    → NucleantFrame
  - nucleant.widget    → PyWidgetBase
  - nucleant.canvas    → ThorCanvasBase, SkiaCanvasBase, CanvasShader
"""

from . import app as app
from . import window as window
