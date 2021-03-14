/+
dub.json:
{
    "name": "DOEVisualizerExecutor",
    "targetPath": "../"
}
+/

module doevisualizer;

import std.stdio;
import std.process;
import std.file;
import std.path;

void main(string[] args)
{
    // immutable auto julia = escapeShellCommand("julia");
    // auto pipes = pipeShell(julia, Redirect.stdin | Redirect.stdout | Redirect.stderr);
    auto pipes = pipeProcess(["julia"], Redirect.stdin | Redirect.stdout | Redirect.stderr);
    // scope(exit) wait(pipes.pid);
/*
    // Store lines of output.
    string[] output;
    foreach (line; pipes.stdout.byLine) output ~= line.idup;

    // Store lines of errors.
    string[] errors;
    foreach (line; pipes.stderr.byLine) errors ~= line.idup;
*/
    // auto runIncludeSrc = escapeShellCommand("include(raw")
    //     ~ escapeShellFileName(dirName(thisExePath()) ~ "/DOEVisualizer.jl\")");
    string runIncludeSrc = "include(raw\"" ~ dirName(thisExePath()) ~ "/src/DOEVisualizer.jl\")";
    pipes.stdin.writeln(runIncludeSrc);
    pipes.stdin.writeln("\n");
    pipes.stdin.flush();

    // Close the file
    pipes.stdin.close();
    // otherwise this will wait forever
    wait(pipes.pid);
}
