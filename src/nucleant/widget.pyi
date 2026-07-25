"""nucleant.widget — PyWidgetBase, the widget-tree node (also the
`on_build` return type).
"""

from .canvas import SkiaCanvasBase, ThorCanvasBase, PixelBufferCanvasBase, PyBufferCanvasBase
from .layout import NucleantFrame, VerticalLayout, HorizontalLayout, VerticalGrid, HorizontalGrid

type CanvasBase = ThorCanvasBase | SkiaCanvasBase | PixelBufferCanvasBase | PyBufferCanvasBase
type Layout = VerticalLayout | HorizontalLayout | VerticalGrid | HorizontalGrid

class PyWidgetBase:
    """The attachment side of the tree: parenting + child bookkeeping.

    A widget never touches a render node — it holds one canvas (a
    `ThorCanvasBase` or `SkiaCanvasBase`) and drawing is entirely the
    canvas's business. Assign no canvas and the widget is a pure container.
    """

    # the widget's frame — position + size; assign a NucleantFrame or None.
    frame: NucleantFrame | None

    # the widget's canvas slot; assign a canvas or None.
    canvas: CanvasBase | None

    # layout that positions this widget's children; assign a
    # VStack/HStack/GridLayout or None. The pass runs over the children's
    # frames within this widget's frame.
    layout: Layout | None

    # stable identity (defaults to a UUID hash).
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
