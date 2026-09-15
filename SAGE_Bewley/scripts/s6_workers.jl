# Start single-threaded worker processes and load the stage-6 code on all of
# them (master included, via @everywhere, so that every process holds ONE copy
# of the SAGEBewley module and the types agree). Include this FIRST, before
# anything else, from any script that builds families in parallel.
using Distributed
const S6_DIR = @__DIR__
const S6_NW = 13
if nworkers() == 1 && nprocs() == 1
    addprocs(S6_NW; exeflags = ["--project=" * abspath(joinpath(S6_DIR, "..")), "-t", "1"])
end
@everywhere include(joinpath($S6_DIR, "s6_common.jl"))
@everywhere begin
    using LinearAlgebra
    BLAS.set_num_threads(1)
end
