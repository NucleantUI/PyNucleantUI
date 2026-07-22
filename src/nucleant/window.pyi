"""nucleant.window — `@PyModule(name: "nucleant.window")`, py_classes: [WindowBase]."""

from abc import ABC, abstractmethod

from .widget import PyWidgetBase


class WindowBase(ABC):
    """A platform window bound to a Vulkan render engine (`@PyClass`, WindowBase).

    Subclass it and implement the `on_*` hooks. The native side calls each
    hook directly (`@PyCallMethod`, unguarded), so they are abstract — a
    subclass must provide them: `on_build` returns the root widget tree,
    `on_frame` advances per-tick state, and the input hooks receive
    mouse/scroll/key events.
    """

    def __init__(self, x: int, y: int, w: int, h: int) -> None:
        """Position/size the window's content rect (`x, y, w, h`)."""
        ...

    def present(self) -> None:
        """Create the platform window + engine and show it."""
        ...

    # Override hooks (`@PyCallMethod`) — abstract; implement in your subclass.

    @abstractmethod
    def on_build(self) -> PyWidgetBase | None:
        """Return the root widget of this window's tree."""
        ...

    @abstractmethod
    def on_frame(self, dt: float) -> None:
        """Per display-link tick, `dt` seconds since the last frame."""
        ...

    @abstractmethod
    def on_mouse_down(self, x: float, y: float) -> None: ...
    @abstractmethod
    def on_mouse_up(self, x: float, y: float) -> None: ...
    @abstractmethod
    def on_mouse_dragged(self, x: float, y: float) -> None: ...
    @abstractmethod
    def on_mouse_moved(self, x: float, y: float) -> None: ...
    @abstractmethod
    def on_right_mouse_down(self, x: float, y: float) -> None: ...
    @abstractmethod
    def on_right_mouse_up(self, x: float, y: float) -> None: ...
    @abstractmethod
    def on_scroll(self, dx: float, dy: float) -> None: ...
    @abstractmethod
    def on_key_down(self, keyCode: int, characters: str | None) -> None: ...
    @abstractmethod
    def on_key_up(self, keyCode: int, characters: str | None) -> None: ...
