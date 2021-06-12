# DOEVisualizer

1. Install Julia language
2. Install Julia package dependencies
   1. Open CMD or PowerShell (or other), go to this project directory/folder and run the command `julia` and then inside run the command `]activate .` and `]instantiate`
3. Use Julia to run src/DOEVUI.jl either by
   - opening CMD or Powershell (or Bash etc.) and running the command `julia PATH/TO/src/DOEVUI.jl` (must re-compile every time though)
   - or opening Julia and running the input command `include("PATH/TO/src/DOEVUI.jl")`
4. Precompilation and loading might take some time (or even downloading the package dependencies)
