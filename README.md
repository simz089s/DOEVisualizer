# DOEVisualizer

## Installation and running the app

1. Install Julia language. This project uses version `1.7.x`.
2. Install Julia extra package dependencies:
   1. Open a terminal/command line/console/shell and go to this project's root directory/folder. So basically the directory/folder containing `Manifest.toml`, `Project.toml`, `/src`, `/cfg`, etc.
   2. Open a Julia REPL/shell by running the command `julia`. The Julia executable (e.g. `julia.exe` for a Windows computer, but Julia works on Mac OS and Linux too) must be in your `PATH`.
   3. If not, you need to know where Julia was installed on the computer. Usually somewhere like `C:/Users/username/AppData/Local/Programs/Julia-1.7.x`, where `username` is your Windows accounts folder name and `x` is your Julia version, for a Windows computer. Your computer might be different. To run Julia (open a Julia REPL/shell) this way, you would run the command `C:/Users/username/AppData/Local/Programs/Julia-1.7.x/bin/julia.exe`.
   4. Once inside the Julia REPL/shell, type `using Pkg` and press _Enter_.
   5. Then, type `Pkg.activate(".")` and press _Enter_.
   6. Then, type `Pkg.instantiate()` and press _Enter_. Wait for Julia to install all the extra packages. This might take some time.
3. Once everything is downloaded and installed, you can run the DOEVisualizer app/program by typing `include("src/DOEVUI.jl")` and pressing _Enter_. This might take some time to compile the program. Julia only compiles part of the program that is used, so even if a graphical interface shows up, clicking on buttons the first time might take some time to compile those other parts of the program that run them.
4. Now, you can re-open the program with the command `include("src/DOEVUI.jl")` as used above (note that if some code or configurations have changed, you must restart the Julia REPL/shell by quitting and re-running `julia --project=. -i src/DOEVUI.jl` or simply repeating steps 2.1 to 2.6 and 3.)
5. The first time you install and run everything it will take a long time to download and install everything for the first time. It should be much faster the next times. Unfortunately, the way Julia works makes it so that certain parts of the program *must* be re-compiled every time you re-open a Julia shell, so everything written in step 3. will always happen. This is why it is recommended to keep an already opened and compiled Julia shell open as long as possible, and to simply re-run `include("src/DOEVUI.jl")` to restart the DOEVisualizer.

## DOEVisualizer usage

1. When you run the DOEVisualizer (e.g. with `include("src/DOEVUI.jl")` in a Julia shell), you should be greeted with an app window showing you a few options. If you just want a quick test, you should prepare an Excel spreadsheet table in the accepted format and remember the top-left cell position as well as the bottom-right cell position. You can then proceed to put those cell position in the DOEVisualizer interface in the last text field at the bottom, using the format `A1:B2` (top-left:bottom-right). Then, click on the "Visualize" button.
2. You must then find and select and open the Excel spreadsheet you used.
3. A new windows will then open as the DOEVisualizer.
