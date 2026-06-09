# Internal launcher used for headless preview/screenshots (no auth token, no auto-browser).
# For normal use, prefer run.jl.
import Pkg
Pkg.activate(@__DIR__)
import Pluto
Pluto.run(notebook = joinpath(@__DIR__, "SAGE_Bewley.jl"),
          launch_browser = false, port = 1234,
          require_secret_for_open_links = false,
          require_secret_for_access = false)
