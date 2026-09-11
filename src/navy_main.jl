using YAXArrays
using NetCDF
using DimensionalData
using Base: eventloop
using Trapz
using Glob
using Dates
using Makie
using GeoMakie
import IntervalSets
import Interpolations

include("./navy_io.jl")
include("./navy_arrange.jl")
include("./navy_visualize.jl")
include("./navy_analysis.jl")
include("./navy_utils.jl")
