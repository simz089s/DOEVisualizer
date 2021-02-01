module funcs;

import xlld;

@Register(ArgumentText("Array to add"),
          HelpTopic("Adds all cells in an array"),
          FunctionHelp("Adds all cells in an array"),
          ArgumentHelp(["The array to add"]))
double FuncAddEverything(double[][] args) nothrow @nogc {
    import std.algorithm: fold;
    import std.math: isNaN;

    double ret = 0;
    foreach(row; args)
        ret += row.fold!((a, b) => b.isNaN ? 0.0 : a + b)(0.0);
    return ret;
}

// @Excel(
//     ArgumentText("TEST arg txt"),
//     HelpTopic("TEST help topic"),
//     FunctionHelp("TEST fn help"),
//     ArgumentHelp(["TEST array"]),
// )
// double TestFunc(double[][] args) nothrow @safe {
//     return 1.5;
// }
