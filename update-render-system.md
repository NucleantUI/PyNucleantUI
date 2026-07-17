

# General RenderNode type

* packages/PyNucleantUI/Sources/PyNucleantUI/RenderEngine/RenderNode.swift

```swift
public struct RenderNode {
    let id: Int
    
    let context: Context
    
    init(id: Int, context: Context) {
        self.id = id
        self.context = context
    }
}
```

now contains this struct type

first thing to fix/change is the places ObjectIdentifier have been used
id should be Int always and rely on Hashing 
some places is marked with // TODO

personal i think it should just rely on id is created by
UUID().hashValue

and since ThorCanvasBase is the context for rendernode then it should be CanvasBase id that sets RenderNode id

```swift
public final class ThorCanvasBase: PyCanvasBase, ThorGPUCanvas, PyCapsuleProtocol {
    
    public var id: Int = UUID().hashValue

```

id been added to CanvasBase also, so should easy to match CanvasBase with RenderNode

in the future a BuildToolPlugin will generate this file
* packages/PyNucleantUI/Sources/PyNucleantUI/RenderEngine/RenderNode+Context.swift
with example this as base cases
soo other libraries Swift/Python/Other based can be added by provided info in the future yaml file
but nothing important for now
for now the skia / shader case is just typealiases of ThorShaderNode

```swift
extension RenderNode {
    // generated later on
    public enum Context {
        case thor(ThorShaderNode)
        case skia(SkiaShaderNode)
        case shader(OGLShaderNode)
        case group(GroupNode)
        case texture_group(TextureGroupNode)
    }
    
}
```

# create OGLShaderNode

it should kinda just be ThorShaderNode
without the 
public var base: Tvg_Canvas
and thorvg logic at all
basicly just the PostShader part standalone
and maybe some option to register Texture Inputs by VkImage or whatever makes sense



@Observable ShaderNode -> update RenderNode.Context

since we already have implemented Observable Frame, why not make Canvas/Shader Nodes (Thorvg, and the rest) Observable
and RenderNode (if struct type fits bad then change to class) can track dirty marker, from the different ShaderNode types
or whatever make sense, sooo we can skip this spiderweb of ref forward and back between the Canvas Nodes and actual RenderNodes
atleast something smarter between when Canvas/Shader needs update vs RenderNode

# if verify that whole engine works at runtime - update app.py if needed
check PySwiftKit module names etc matches with nuclentant over sulphur names
update app.py also if wrong imports or class names
but for now focus on making this Canvas <-> Render side more smart with updates by Observation framework





