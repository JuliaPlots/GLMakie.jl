module GLVisualize

using ..GLAbstraction
using AbstractPlotting: RaymarchAlgorithm, IsoValue, Absorption, MaximumIntensityProjection, AbsorptionRGBA,
                        IndexedAbsorptionRGBA

using ..GLMakie.GLFW
using ModernGL
using StaticArrays
using GeometryBasics
using Colors
using AbstractPlotting
using FixedPointNumbers
using FileIO
using Markdown
using Observables

import Base: merge, convert, show
using Base.Iterators: Repeated, repeated
using LinearAlgebra

import AbstractPlotting: to_font, glyph_uv_width!
import ..GLMakie: get_texture!

const GLBoundingBox = FRect3D

using ..GLMakie: assetpath, loadasset

include("visualize_interface.jl")
export visualize # Visualize an object
export visualize_default # get the default parameter for a visualization

include(joinpath("visualize", "lines.jl"))
include(joinpath("visualize", "image_like.jl"))
include(joinpath("visualize", "mesh.jl"))
include(joinpath("visualize", "particles.jl"))
include(joinpath("visualize", "surface.jl"))

export CIRCLE, RECTANGLE, ROUNDED_RECTANGLE, DISTANCEFIELD, TRIANGLE

end # module
