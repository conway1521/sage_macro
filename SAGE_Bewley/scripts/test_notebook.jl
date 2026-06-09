# Headless test: open and fully run the Pluto notebook, report any cell errors.
#   julia --project=. scripts/test_notebook.jl
using Pluto

nbpath = joinpath(@__DIR__, "..", "SAGE_Bewley.jl")
println("Opening ", nbpath)
s = Pluto.ServerSession()
nb = Pluto.SessionActions.open(s, nbpath; run_async = false)

nerr = 0
for c in nb.cells
    if c.errored
        global nerr += 1
        println("\n──── CELL ERROR ────")
        println(">>>CODE>>>"); println(c.code); println("<<<CODE<<<")
        println("MSG: ", get(c.output.body, :msg, c.output.body))
    end
end
println(nerr == 0 ? "\n ALL CELLS RAN CLEANLY" : "\n $nerr cell(s) errored")
exit(nerr == 0 ? 0 : 1)
