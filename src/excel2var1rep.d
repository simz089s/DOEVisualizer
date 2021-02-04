module excel2var1rep;

import xlld;

@Excel(
    ArgumentText("TEST arg txt"),
    HelpTopic("TEST help topic"),
    FunctionHelp("TEST fn help"),
    ArgumentHelp(["TEST array"]),
)
double TestFunc(scope double[][] args) nothrow @nogc @safe {
    return 1.5;
}
