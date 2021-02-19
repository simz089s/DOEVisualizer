# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames
# using GLM, StatsModels

using GLMakie#, Makie

df = CSV.File("res/heat_treatement_data_2.csv") |> DataFrame

types = df[1, :]
NUM_VARS = count(t -> !ismissing(t) && t == "variable", types)
NUM_RESPS = count(t -> !ismissing(t) && t == "response", types)
# NUM_LVLS = 

select!(df, Not(1))
# titles = replace.(["$(x) ($(y))" for (x, y) in zip(names(df), df[1, :])], " "=>"_")
titles = ["x_stime", "x_t", "x_atime", "y_yield", "y_str", "y_elong"]
rename!(df, titles)
delete!(df, 1)
df[!, :] = parse.(Float64, df[!, :])

# f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
# model = glm(f, select(df, 1:4), Normal(), IdentityLink())

s = fig, axes, obj = scatter(
    df[1], df[2], df[3],
    # colors = (colors, colors, colors),
    markersize = 500,
    # transparency = true, alpha = 0.1,
    # limits = FRect3D( (3, 140, 2), (4, 40, 3) ),
    # scale = (1, 2, 1),
    # axis3d = (
    #     # names = (
    #     #     axisnames = ("x", "y", "z"),
    #     # ),
    #     # scale = (1, .05, 1),
    #     # scale_plot = true,
    #     ticks = (
    #         ranges = Node((3:7, 140:180, 2:5)),
    #     ),
    # ),
)
# yticks!(s, ytickrange=80)

fig

# end
