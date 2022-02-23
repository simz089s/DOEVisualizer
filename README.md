# DOEVisualizer

1. Install Julia language.
2. Install Julia package dependencies.
   1. Open a terminal, go to this project directory/folder and run the command `julia --project=. -i src/DOEVUI.jl` and then inside the Julia REPL, run the command `]instantiate`.
3. You can re-open the app with the command `include("src/DOEVUI.jl")` (note that if some code or configurations have changed, you must restart Julia itself by quitting and re-running `julia --project=. -i src/DOEVUI.jl`).
4. Precompilation and loading might take some time (if you have not already downloaded the package dependencies/libraries, it will take longer to do so and to install them).
