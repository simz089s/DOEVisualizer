# DOEVisualizer

![2021_05_07T01_18_53 531_S_time_temperat _A_time_yield_strength_elongation](https://github.com/simz089s/DOEVisualizer/assets/24693006/92118bd6-8549-42e5-98be-79dc2bc8572d)
![2021_05_07T01_20_32 540_S_time_temperat _A_time_yield_strength_elongation](https://github.com/simz089s/DOEVisualizer/assets/24693006/67faa528-4159-4b66-9061-ee498c2ab91b)

## Installation and running the app

1. [Install Julia language](https://julialang.org/downloads/). This was tested on the Long-Term Support (LTS) version 1.6.7 but it should probably work on the newer version.
2. Install Julia extra package dependencies:
   1. Open a terminal/command line/console/shell and go to this project's root directory/folder. So basically the directory/folder containing `Manifest.toml`, `Project.toml`, `/src`, `/cfg`, etc.
      1. On Windows, you can use the Start Menu search bar for "Windows PowerShell" and open that.
      2. Then type `cd C:/Users/blablablabla/Downloads/DOEVisualizer` (change the path to wherever you downloaded this folder).
   2. Open a Julia REPL/shell by running the command `julia`. The Julia executable (e.g. `julia.exe` for a Windows computer, but Julia works on Mac OS and Linux too) must be in your `PATH`.
   3. If not, you need to know where Julia was installed on the computer. Usually somewhere like `C:/Users/username/AppData/Local/Programs/Julia-1.6.7`, where `username` is your Windows accounts folder name and `Julia-1.6.7` should be replaced with your Julia version, for a Windows computer. Your computer might be different. To run Julia (open a Julia REPL/shell) this way, you would run the command `C:/Users/username/AppData/Local/Programs/Julia-1.6.7/bin/julia.exe` (replace the version number if needed). If you installed the portable version of Julia, you should probably know where the `julia.exe` is (e.g. your `/Downloads` folder).
   4. Once inside the Julia REPL/shell, type `using Pkg` and press _Enter_.
   5. Then, type `Pkg.activate(".")` and press _Enter_.
   6. Then, type `Pkg.instantiate()` and press _Enter_. Wait for Julia to install all the extra packages. This might take a while depending on the speed of your Internet connection and computer.
3. Once everything is downloaded and installed, you can run the DOEVisualizer app/program by typing `include("src/DOEVisualizer.jl")` and pressing _Enter_. This might take some time to compile (further install) the program. Julia only compiles part of the program that is used, so even if a graphical interface shows up, clicking on buttons the first time might take some time to compile those other parts of the program that run them.
4. Now, you can re-open the program with the command `include("src/DOEVisualizer.jl")` as used above (note that if some code or configurations have changed, you must restart the Julia REPL/shell by quitting and re-running `julia --project=. -i src/DOEVisualizer.jl` or simply repeating steps 2.1 to 2.6 and 3.)
5. The first time you install and run everything it will take a long time to download and install everything for the first time. It should be much faster the next times. Unfortunately, the way Julia works makes it so that certain parts of the program *must* be re-compiled every time you re-open a Julia shell, so everything written in step 3. will always happen. This is why it is recommended to keep an already opened Julia shell that has previously opened the DOEVisualizer for as long as possible, and to simply re-run `include("src/DOEVisualizer.jl")` to restart the DOEVisualizer.

## DOEVisualizer usage

1. When you run the DOEVisualizer (e.g. with `include("src/DOEVisualizer.jl")` in a Julia shell), you should be greeted with an app window showing you a few options. If you just want a quick test, you should prepare a CSV or an Excel spreadsheet table in the accepted format and remember the top-left cell position as well as the bottom-right cell position. You can then proceed to put those cell position in the DOEVisualizer interface in the last text field at the bottom, using the format `A1:B2` (top-left:bottom-right). Then, click on the "Visualize" button.
2. You must then find and select and open the CSV or Excel spreadsheet you used.
3. A new window will then open as the DOEVisualizer.
4. For now, it is recommend to only manipulate (rotate with left-click, move with right-click, zoom with mouse wheel) using the bottom left (3rd) 3D plot model, as the top two ones are buggy.

## More "permanent" installation (untested)

1. Open Julia as explained [previously](#installation-and-running-the-app) in step 2 (2.1 to 2.5).
2. Type `Pkg.add("PackageCompiler")` and press _Enter_.
3. Type `using PackageCompiler` and press _Enter_.
4. Copy the path where you downloaded the DOEVisualizer (this folder) e.g. `C:/Users/blablablabla/Downloads/DOEVisualizer`.
5. Type `create_app(raw"C:/Users/blablablabla/Downloads/DOEVisualizer", "app")`. This will create a folder `/app` in the current folder and inside it will be an executable program (e.g. `C:/Users/blablablabla/Downloads/DOEVisualizer/app/bin/julia.exe`). Simply running that should run the DOEVisualizer.
   - If, for some reason, this fails or you want to retry, but the `/app` folder was already created, then you can instead use `create_app(raw"C:/Users/blablablabla/Downloads/DOEVisualizer", "app"; force=true)` (notice the `force=true` at the end).
