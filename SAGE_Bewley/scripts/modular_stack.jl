# The whole modular stack in load order, as one file, so that it can be sent to
# a worker with a single @everywhere include. Each statement is evaluated in
# turn, which an @everywhere begin block does not do: there the include and the
# using are parsed together and the module is not yet defined.
include(joinpath(@__DIR__, "..", "src", "SAGEBewley.jl"))
using .SAGEBewley
include(joinpath(@__DIR__, "proto_participation_core.jl"))
include(joinpath(@__DIR__, "sa_core.jl"))
include(joinpath(@__DIR__, "agency_core.jl"))
include(joinpath(@__DIR__, "unemployment_core.jl"))
include(joinpath(@__DIR__, "agency_shock.jl"))
include(joinpath(@__DIR__, "sage_modular.jl"))
