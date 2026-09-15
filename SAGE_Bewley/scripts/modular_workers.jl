# Bootstrap for anything that uses the modular layer in parallel: start
# single-threaded worker processes and load the whole stack on every one of
# them, master included, so the types agree. Processes rather than threads for
# the reason recorded in unemployment_core.jl.
using Distributed
const MOD_DIR = @__DIR__
# Worker count. Thirteen by default; SAGE_WORKERS overrides it. Results do not
# depend on it, since each job is an independent household problem. At the
# doubled asset grid (na 400) each worker holds 4 to 5 GB, which thirteen
# workers cannot fit in 24 GB (2026-09-15).
const MOD_NW = parse(Int, get(ENV, "SAGE_WORKERS", "13"))
if nworkers() == 1 && nprocs() == 1
    addprocs(MOD_NW; exeflags = ["--project=" * abspath(joinpath(MOD_DIR, "..")), "-t", "1"])
end
@everywhere include(joinpath($MOD_DIR, "modular_stack.jl"))
@everywhere begin
    using LinearAlgebra
    BLAS.set_num_threads(1)
end
