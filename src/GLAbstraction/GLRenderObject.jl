function RenderObject(data::Dict{Symbol}, program, pre, bbs=Node(FRect3D(Vec3f0(0), Vec3f0(1))), main=nothing)
    return RenderObject(convert(Dict{Symbol,Any}, data), program, pre, bbs, main)
end

function Base.show(io::IO, obj::RenderObject)
    return println(io, "RenderObject with ID: ", obj.id)
end

Base.getindex(obj::RenderObject, symbol::Symbol) = obj.uniforms[symbol]
Base.setindex!(obj::RenderObject, value, symbol::Symbol) = obj.uniforms[symbol] = value

Base.getindex(obj::RenderObject, symbol::Symbol, x::Function) = getindex(obj, Val(symbol), x)
Base.getindex(obj::RenderObject, ::Val{:prerender}, x::Function) = obj.prerenderfunctions[x]
Base.getindex(obj::RenderObject, ::Val{:postrender}, x::Function) = obj.postrenderfunctions[x]

Base.setindex!(obj::RenderObject, value, symbol::Symbol, x::Function) = setindex!(obj, value, Val(symbol), x)
Base.setindex!(obj::RenderObject, value, ::Val{:prerender}, x::Function) = obj.prerenderfunctions[x] = value
Base.setindex!(obj::RenderObject, value, ::Val{:postrender}, x::Function) = obj.postrenderfunctions[x] = value

const empty_signal = Node(false)
post_empty() = push!(empty_signal, false)

"""
Represents standard sets of function applied before rendering
"""
struct StandardPrerender
    transparency::Node{Bool}
    overdraw::Node{Bool}
end

function (sp::StandardPrerender)()
    if sp.overdraw[]
        # Disable depth testing if overdrawing
        glDisable(GL_DEPTH_TEST)
    else
        glEnable(GL_DEPTH_TEST)
        glDepthFunc(GL_LEQUAL)
    end
    # Disable depth write for transparent objects
    glDepthMask(sp.transparency[] ? GL_FALSE : GL_TRUE)
    # Disable cullface for now, untill all rendering code is corrected!
    glDisable(GL_CULL_FACE)
    # glCullFace(GL_BACK)
    return enabletransparency()
end

struct StandardPostrender
    vao::GLVertexArray
    primitive::GLenum
end
function (sp::StandardPostrender)()
    return render(sp.vao, sp.primitive)
end
struct StandardPostrenderInstanced{T}
    main::T
    vao::GLVertexArray
    primitive::GLenum
end
function (sp::StandardPostrenderInstanced)()
    return renderinstanced(sp.vao, to_value(sp.main), sp.primitive)
end

struct EmptyPrerender end
function (sp::EmptyPrerender)() end
export EmptyPrerender
export prerendertype

function instanced_renderobject(data, program, bb=Node(FRect3D(Vec3f0(0), Vec3f0(1))),
                                primitive::GLenum=GL_TRIANGLES, main=nothing)
    pre = StandardPrerender()
    robj = RenderObject(convert(Dict{Symbol,Any}, data), program, pre, nothing, bb, main)
    robj.postrenderfunction = StandardPostrenderInstanced(main, robj.vertexarray, primitive)
    return robj
end

function std_renderobject(data, program, bb=Node(FRect3D(Vec3f0(0), Vec3f0(1))), primitive=GL_TRIANGLES,
                          main=nothing)
    pre = StandardPrerender()
    robj = RenderObject(convert(Dict{Symbol,Any}, data), program, pre, nothing, bb, main)
    robj.postrenderfunction = StandardPostrender(robj.vertexarray, primitive)
    return robj
end

prerendertype(::Type{RenderObject{Pre}}) where {Pre} = Pre
prerendertype(::RenderObject{Pre}) where {Pre} = Pre
