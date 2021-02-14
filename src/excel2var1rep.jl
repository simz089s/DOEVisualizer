# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames
# using GLM, StatsModels

using PyPlot#, StatsPlots
# using Makie

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

# using3D()
# fig = figure()
# ax = fig.add_subplot(projection="3d")
# cm = get_cmap(:tab20)
# colours = [cm(v/10) for v in 1:NUM_VARS*NUM_RESPS]
# colours = [c for c in 1:NUM_VARS*NUM_RESPS]
colours = [.1 .85 .87 .89 .91 .93 .95 .97 .99]

graphs = Array{Any, 1}(undef, NUM_RESPS)
for (idx, title) ∈ enumerate(names(select(df, 4:6, copycols=false)))
    graphs[idx] = scatter3D(
        df[1], df[2], df[3],
        marker="o", s=200, c=colours, edgecolors="black",
        # zcolor=df[title], markersize=10, markershape=:circle, c=cgrad([:red3, :yellow, :green]),
        # lab=title, xaxis=titles[1], yaxis=titles[2], zaxis=titles[3],
        # reuse=false,
        depthshade=false,
    )
    # get!(graphs[idx].attr, :depthshade, false)
    # get!(graphs[idx].series_list[1].plotattributes, :depthshade, false)
end
# plot3D(graphs...)

# graph = @df df plot(df_sorted_by_y[1], df_sorted_by_y[2], predict(model), line=:surface)

# close("all")

# end
