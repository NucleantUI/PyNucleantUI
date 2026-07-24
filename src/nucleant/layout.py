"""nucleant.layout — public module.

Pure-Python wrapper over the native `_nucleant.layout` (pyswiftkit): it
re-exports the native types and adds the `IntEnum`s pyswiftkit can't emit
(it passes enums across as their raw `int`, not as enum classes — so the real
enum types have to live here in Python).
"""

from enum import IntEnum

from _nucleant.layout import (  # type: ignore
    NucleantFrame,
    VerticalLayout,
    HorizontalLayout,
    VerticalGrid,
    HorizontalGrid,
    GridItem,
)


class HorizontalAlignment(IntEnum):
    """Cross-axis placement for a `VerticalLayout` (raw value 0/1/2)."""

    LEADING = 0
    CENTER = 1
    TRAILING = 2


class VerticalAlignment(IntEnum):
    """Cross-axis placement for a `HorizontalLayout` (raw value 0/1/2)."""

    TOP = 0
    CENTER = 1
    BOTTOM = 2


class GridSize(IntEnum):
    """How a `GridItem` track sizes itself (raw value 0/1/2)."""

    FIXED = 0
    FLEXIBLE = 1
    ADAPTIVE = 2


__all__ = [
    "NucleantFrame",
    "VerticalLayout",
    "HorizontalLayout",
    "VerticalGrid",
    "HorizontalGrid",
    "GridItem",
    "HorizontalAlignment",
    "VerticalAlignment",
    "GridSize",
]
