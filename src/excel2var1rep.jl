# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames
# using GLM, StatsModels
using Plots#, StatsPlots
pyplot()
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

# low = 1 : NUM_VARS
# mid = NUM_VARS + 1 : 2 * NUM_VARS
# high = 2 * NUM_VARS + 1 : 3 * NUM_VARS

# f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
# model = glm(f, select(df, 1:4), Normal(), IdentityLink())

# mutable struct NoDepthShade end
# @recipe function no_depthshade(::NoDepthShade)
#     depthshade --> false
# end

graphs = Array{Plots.Plot{Plots.PyPlotBackend}, 1}(undef, NUM_RESPS)
for (idx, title) ∈ enumerate(names(select(df, 4:6, copycols=false)))
    graphs[idx] = scatter3d(
        df[1], df[2], df[3],
        zcolor=df[title], markersize=10, markershape=:circle, c=cgrad([:red3, :yellow, :green]),
        title="$(title) ~ $(titles[1]) + $(titles[2]) + $(titles[3])", lab=title, xaxis=titles[1], yaxis=titles[2], zaxis=titles[3],
        seriestype=:scatter3d, line=:scatter3d,
        # extra_kwargs=Dict(:series => Dict(:depthshade => false), :plot => Dict(:depthshade => false), :subplot => Dict(:depthshade => false)),
        # depthshade=false,
        # arrow=arrow(:closed, :both),
        reuse=false,
    )
    graphs[idx] = scatter3d!(graphs[idx], depthshade=false)
    # get!(graphs[idx][:extra_kwargs], :depthshade, false)
    # get(graphs[idx][:extra_kwargs][:plot], :depthshade, false)
    # get(graphs[idx][:extra_kwargs][:subplot], :depthshade, false)
    # get(graphs[idx][:extra_kwargs][:series], :depthshade, false)
end
# display(scatter3d(graphs..., extra_kwargs=Dict( :plot => Dict(:depthshade=>false), :subplot => Dict(:depthshade=>false), :series => Dict(:depthshade=>false) )))
display(scatter3d(graphs...))

# graph = @df df plot(df_sorted_by_y[1], df_sorted_by_y[2], predict(model), line=:surface)

# close("all")

# end
