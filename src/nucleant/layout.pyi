"""nucleant.layout — `@PyModule(name: "nucleant.layout")`, NucleantFrame (`@PyClass`).

NOTE: the module exists in Swift but is NOT in `PyNucleantUI_Package.modules`
yet, and NucleantFrame is not in an active `py_classes`; wiring is pending.
"""


class NucleantFrame:
    """A widget's position + size (`@PyClass`, observable).

    `pos` / `size` are (x, y) pairs. Mutating them in place resizes the
    owning canvas's render node; `flexible_width` / `flexible_height` mark
    axes the layout may stretch.
    """

    # `@PyProperty` — (x, y) as a 2-tuple of floats.
    pos: tuple[float, float]
    # `@PyProperty` — (width, height) as a 2-tuple of floats.
    size: tuple[float, float]
    # `@PyProperty`
    flexible_width: bool
    # `@PyProperty`
    flexible_height: bool

    def __init__(self, x: float, y: float, w: float, h: float) -> None: ...
