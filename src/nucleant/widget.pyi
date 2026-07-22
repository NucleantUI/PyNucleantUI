"""nucleant.widget — PyWidgetBase (`@PyClass`).

NOTE: not yet registered in `PyNucleantUI_Package.modules` / any active
`py_classes`; the class is defined and annotated but the module wiring is
pending. Stub kept here so the window's `on_build` return type resolves.
"""

from .canvas import SkiaCanvasBase, ThorCanvasBase

type CanvasBase = ThorCanvasBase | SkiaCanvasBase

class PyWidgetBase:
    """The attachment side of the tree: parenting + child bookkeeping.

    A widget never touches a render node — it holds one canvas (a
    `ThorCanvasBase` or `SkiaCanvasBase`) and drawing is entirely the
    canvas's business. Assign no canvas and the widget is a pure container.
    """

    # `@PyProperty` — the widget's canvas slot; assign a canvas or None.
    canvas: CanvasBase | None

    # `@PyProperty` — stable identity (defaults to a UUID hash).
    id: int

    def __init__(self) -> None: ...

    def add_widget(self, widget: PyWidgetBase) -> None:
        """Parent `widget` under this one."""
        ...

    def remove_widget(self, widget: PyWidgetBase) -> None:
        """Unparent `widget` and tear its subtree out of the composite."""
        ...

    def clear_widgets(self) -> None:
        """Remove every child."""
        ...
