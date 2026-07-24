"""nucleant.canvas — ThorCanvasBase, SkiaCanvasBase, PixelBufferCanvasBase,
PyBufferCanvasBase, CanvasShader.
"""

from collections.abc import Buffer


class CanvasShader:
    """A compute post-process installed on a canvas's render node.

    `frag_code` is fragment-style GLSL defining
    `vec4 post_process(vec4 color, vec2 uv)`; assigning it recompiles and
    reinstalls the shader. Source starting with `#version` is taken as a
    full compute shader.
    """

    id: int
    # reassign to recompile/reinstall the post pass.
    frag_code: str | None

    def __init__(self, frag_code: str | None) -> None: ...


class ThorCanvasBase:
    """A widget's ThorVG-drawn 2D canvas.

    Override `on_canvas` (first draw) and `update_canvas` (per frame). Draw
    with ThorVG via the `Tvg_Canvas` capsule from `tvg_canvas_capsule()`.
    """

    def __init__(self) -> None: ...

    # Optional override hooks — the canvas calls them only if
    # the subclass defines them (guarded), so they stay concrete, not abstract.
    def on_canvas(self) -> None: ...
    def update_canvas(self, dt: float) -> None: ...

    def tvg_canvas_capsule(self) -> object:
        """The raw `Tvg_Canvas*` as a PyCapsule for ThorVG drawing."""
        ...

    def add_shader(self, index: int, shader: CanvasShader) -> None:
        """Install a compute post shader (only one slot; `index` ignored)."""
        ...

    def update_shader(self, shader: CanvasShader | None) -> None:
        """Swap the post shader, or None to run the canvas bare."""
        ...


class PixelBufferCanvasBase:
    """A widget's CPU-fed, fixed-resolution pixel canvas.

    Some producer fills `width`×`height` RGBA8 pixels every frame; the
    composite pass scales the image to the window (`scale` is an integer
    GPU up-scale so a post shader sees real subpixels). Feed pixels from
    Python with `write`, or override `on_canvas` / `update_canvas`.
    """

    def __init__(self, width: int, height: int, scale: int) -> None:
        """Fixed content resolution (`width`×`height`) and integer up-scale."""
        ...

    # Optional override hooks — the canvas calls them only if
    # the subclass defines them (guarded), so they stay concrete, not abstract.
    def on_canvas(self) -> None: ...
    def update_canvas(self, dt: float) -> None: ...

    def write(self, buffer: bytes | bytearray | memoryview) -> None:
        """Hand one frame of tightly-packed RGBA8 bytes to the node.

        Accepts anything satisfying the buffer protocol (bytes, bytearray,
        memoryview over numpy/ctypes/array.array, …).
        """
        ...

    def add_shader(self, index: int, shader: CanvasShader) -> None:
        """Install a compute post shader (only one slot; `index` ignored)."""
        ...

    def update_shader(self, shader: CanvasShader | None) -> None:
        """Swap the post shader, or None to run the pixels bare."""
        ...


class PyBufferCanvasBase:
    """A widget's buffer-protocol-fed, fixed-resolution pixel canvas.

    The sibling of `PixelBufferCanvasBase`, and the difference is the reason
    it exists: `write` reads the producer object *directly* through the
    buffer protocol, so any object exporting a buffer works with no
    `memoryview()` wrapper — including extension types with a `bf_getbuffer`
    slot of their own, e.g. a `nucleant.nes.NesLayer`::

        canvas.write(nes.background_layer)

    `PixelBufferCanvasBase.write` deserializes to `Data`, which only accepts
    bytes/bytearray/memoryview by concrete type. Reach for this canvas when
    the producer *is* a buffer object; reach for that one when you already
    hold bytes.

    Otherwise identical: some producer fills `width`x`height` RGBA8 pixels
    every frame, the composite pass scales the image to the window, and
    `scale` is an integer GPU up-scale so a post shader sees real subpixels.
    """

    def __init__(self, width: int, height: int, scale: int) -> None:
        """Fixed content resolution (`width`x`height`) and integer up-scale."""
        ...

    # Optional override hooks — the canvas calls them only if
    # the subclass defines them (guarded), so they stay concrete, not abstract.
    def on_canvas(self) -> None: ...
    def update_canvas(self, dt: float) -> None: ...

    def write(self, buffer: Buffer) -> None:
        """Hand one frame of tightly-packed RGBA8 to the node, read straight
        out of `buffer` via `PyObject_GetBuffer`.

        Short input fills what it covers; excess bytes are ignored. Raises
        `BufferError` if the object doesn't export a buffer. A no-op before
        the canvas is attached to a node.
        """
        ...

    def add_shader(self, index: int, shader: CanvasShader) -> None:
        """Install a compute post shader (only one slot; `index` ignored)."""
        ...

    def update_shader(self, shader: CanvasShader | None) -> None:
        """Swap the post shader, or None to run the pixels bare."""
        ...


class SkiaCanvasBase:
    """A widget's Skia-drawn 2D canvas.

    Override `on_canvas` / `update_canvas`. Draw with the basic primitives
    here, or — the real path — with skia-python on the raw `SkSurface*` from
    `skia_surface_capsule()`. The surface lives on the node's image, so take
    the capsule inside `on_canvas` (or later) and re-take it after a resize.
    """

    def __init__(self) -> None: ...

    # Optional override hooks — the canvas calls them only if
    # the subclass defines them (guarded), so they stay concrete, not abstract.
    def on_canvas(self) -> None: ...
    def update_canvas(self, dt: float) -> None: ...

    def skia_surface_capsule(self) -> object:
        """The raw `SkSurface*` as a PyCapsule for skia-python."""
        ...

    def clear(self, r: float, g: float, b: float, a: float) -> None: ...
    def draw_rect(self, x: float, y: float, w: float, h: float, r: float, g: float, b: float, a: float) -> None: ...
    def draw_round_rect(self, x: float, y: float, w: float, h: float, radius: float, r: float, g: float, b: float, a: float) -> None: ...
    def draw_circle(self, cx: float, cy: float, radius: float, r: float, g: float, b: float, a: float) -> None: ...
    def draw_line(self, x0: float, y0: float, x1: float, y1: float, stroke_width: float, r: float, g: float, b: float, a: float) -> None: ...
    def draw_text(self, text: str, x: float, y: float, size: float, r: float, g: float, b: float, a: float) -> None: ...
    def text_width(self, text: str, size: float) -> float: ...

    def add_shader(self, index: int, shader: CanvasShader) -> None:
        """Install a compute post shader (only one slot; `index` ignored)."""
        ...

    def update_shader(self, shader: CanvasShader | None) -> None:
        """Swap the post shader, or None to run the canvas bare."""
        ...
