# Launch the interactive notebook.  From the SAGE_Bewley folder run:
#     julia --project=. run.jl
# Pluto opens in your browser straight to the SAGE-Bewley notebook.
import Pkg
Pkg.activate(@__DIR__)
import Pluto
Pluto.run(notebook = joinpath(@__DIR__, "SAGE_Bewley.jl"))
