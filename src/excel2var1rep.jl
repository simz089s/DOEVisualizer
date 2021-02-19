# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames
# using GLM, StatsModels
using Plots#, StatsPlots
pyplot()
# default(show = true)
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

graphs = Array{Plots.Plot{Plots.PyPlotBackend}, 1}(undef, NUM_RESPS)
for (idx, title) ∈ enumerate(names(select(df, 4:6, copycols=false)))
    graphs[idx] = scatter3d(
        df[1], df[2], df[3],
        zcolor=df[title], c=cgrad([:red3, :yellow, :green]),
        markersize=10, markershape=:circle,
        title="$(title) ~ $(titles[1]) + $(titles[2]) + $(titles[3])", lab=title, xaxis=titles[1], yaxis=titles[2], zaxis=titles[3],
        seriestype=:scatter3d, line=:scatter3d,
        # depthshade=false,
        # extra_kwargs=Dict(:series => Dict(:depthshade => false), :plot => Dict(:depthshade => false), :subplot => Dict(:depthshade => false)),
        # arrow=arrow(:closed, :both),
        reuse=false
    )
    # get!(graphs[idx].attr, :depthshade, false)
    # get!(graphs[idx].series_list[1].plotattributes, :depthshade, false)
end
# gui()
display(plot(graphs..., show=true, depthshade=false))

# graph = @df df plot(df_sorted_by_y[1], df_sorted_by_y[2], predict(model), line=:surface)

# close("all")

# end
