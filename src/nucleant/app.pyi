"""nucleant.app — `@PyModule(name: "nucleant.app")`, py_classes: [App]."""

from abc import ABC, abstractmethod


class App(ABC):
    """The application object (`@PyClass(name: "App")`, PyApp).

    Owns the process: creates the platform app delegate, initialises the
    ThorVG engine, registers windows by name, and runs the main loop.
    Subclass it and implement `on_start` (called unconditionally via
    `@PyCallMethod`).
    """

    def __init__(self, threads: int) -> None:
        """`threads` seeds `tvg_engine_init` — the ThorVG worker count."""
        ...

    def run(self) -> None:
        """Enter the platform run loop (blocks until the app quits)."""
        ...

    def register_window(self, name: str, window: object) -> None:
        """Store a window class/instance under `name` for later opening."""
        ...

    def open_registered_window(self, name: str) -> None:
        """Present the window previously registered under `name`."""
        ...

    # Override hook (`@PyCallMethod`) — abstract; the Swift side calls this
    # on your subclass after startup. Implement it to build initial state.
    @abstractmethod
    def on_start(self) -> None: ...
