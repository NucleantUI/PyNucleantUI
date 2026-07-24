"""nucleant.layout — frames, stack/grid layouts, and their enums.

A layout is assigned to a widget's `layout` slot
(`widget.layout = VerticalGrid(columns=[GridItem(...)])`); the native
side runs it over the children's frames.
"""

from enum import IntEnum


class HorizontalAlignment(IntEnum):
    """Where a child narrower than the container sits across the horizontal
    axis — the cross-axis placement for a `VerticalLayout`. An `IntEnum`, so
    it passes to a layout's `alignment` parameter as a plain int.
    """

    LEADING = 0
    CENTER = 1
    TRAILING = 2


class VerticalAlignment(IntEnum):
    """Where a child shorter than the container sits across the vertical
    axis — the cross-axis placement for a `HorizontalLayout`. Same raw values
    as `HorizontalAlignment` (0/1/2), so both cross as a plain int.
    """

    TOP = 0
    CENTER = 1
    BOTTOM = 2


class GridSize(IntEnum):
    """How one `GridItem` track sizes itself (SwiftUI's `GridItem.Size`).

    An `IntEnum`, so it crosses to the native `GridItem.kind` as a plain int.
    """

    FIXED = 0
    FLEXIBLE = 1
    ADAPTIVE = 2


class GridItem:
    """One grid track — a column for a vertical grid, a row for a horizontal
    one, modelled on SwiftUI's `GridItem`.

    `kind` picks the sizing (`GridSize`); `minimum`/`maximum` bound it — for
    `FIXED`, `minimum` is the exact extent (`maximum` ignored). `spacing` is
    the gap after this track; negative uses the grid's default. Defaults
    mirror SwiftUI's `.flexible()`.
    """

    kind: GridSize
    minimum: float
    maximum: float
    spacing: float

    def __init__(
        self,
        kind: GridSize = GridSize.FLEXIBLE,
        minimum: float = 10.0,
        maximum: float = float("inf"),
        spacing: float = -1.0,
    ) -> None: ...


class NucleantFrame:
    """A widget's position + size (observable).

    `pos` / `size` are (x, y) pairs. Mutating them in place resizes the
    owning canvas's render node; `flexible_width` / `flexible_height` mark
    axes the layout may stretch.
    """

    # (x, y) as a 2-tuple of floats.
    pos: tuple[float, float]
    # (width, height) as a 2-tuple of floats.
    size: tuple[float, float]
    flexible_width: bool
    flexible_height: bool

    def __init__(self, x: float, y: float, w: float, h: float) -> None: ...


class VerticalLayout:
    """Stacks children top-to-bottom.

    Flexible children split the leftover height; fixed children keep their
    height and are placed across the horizontal axis by `alignment`.
    """

    # gap between neighbouring children.
    spacing: float

    def __init__(
        self,
        spacing: float = 0.0,
        alignment: HorizontalAlignment = HorizontalAlignment.LEADING,
    ) -> None: ...


class HorizontalLayout:
    """Stacks children left-to-right.

    Flexible children split the leftover width; fixed children keep their
    width and are placed across the vertical axis by `alignment`.
    """

    spacing: float

    def __init__(
        self,
        spacing: float = 0.0,
        alignment: VerticalAlignment = VerticalAlignment.TOP,
    ) -> None: ...


class VerticalGrid:
    """Vertical grid — SwiftUI's `LazyVGrid`.

    Grows downward: `columns` are the cross-axis tracks (each a `GridItem`),
    children flow left-to-right and wrap into new rows. `spacing` gaps the
    rows; a track's own `GridItem.spacing` gaps it from the next column.
    `alignment` places a child smaller than its cell across the horizontal
    axis.
    """

    # gap between wrapped rows.
    spacing: float

    def __init__(
        self,
        columns: list[GridItem],
        spacing: float = 0.0,
        alignment: HorizontalAlignment = HorizontalAlignment.LEADING,
    ) -> None: ...


class HorizontalGrid:
    """Horizontal grid — SwiftUI's `LazyHGrid`.

    Grows rightward: `rows` are the cross-axis tracks (each a `GridItem`),
    children flow top-to-bottom and wrap into new columns. `spacing` gaps the
    columns; a track's own `GridItem.spacing` gaps it from the next row.
    `alignment` places a child smaller than its cell across the vertical axis.
    """

    # gap between wrapped columns.
    spacing: float

    def __init__(
        self,
        rows: list[GridItem],
        spacing: float = 0.0,
        alignment: VerticalAlignment = VerticalAlignment.TOP,
    ) -> None: ...
