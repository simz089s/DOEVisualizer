# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames

# using ForwardDiff
# using AutoGrad
# using GLM, StatsModels

using Plots, StatsPlots
# using Gadfly
# using Makie
pyplot()

df = CSV.File("res/heat_treatement_data_2.csv") |> DataFrame

select!(df, Not(1))
# titles = replace.(["$(x) ($(y))" for (x, y) in zip(names(df), df[1, :])], " "=>"_")
titles = ["x_stime", "x_t", "x_atime", "y_yield", "y_str", "y_elong"]
rename!(df, titles)
delete!(df, 1)
df[!, :] = parse.(Float64, df[!, :])

NUM_VARS = 3
NUM_RESPS = 3
NUM_LVLS = 3
low = 1:3
mid = 4:6
high = 7:9

# f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
# model = glm(f, select(df, 1:4), Normal(), IdentityLink())

for (idx, title) ∈ enumerate(names(df[4:4]))
    df_sorted_by_y = select(df, titles[1:3], title)
    df_sorted_by_y = sort!(df_sorted_by_y, title)
    graph = @df df plot(
        df_sorted_by_y[low, 1], df_sorted_by_y[low, 2], df_sorted_by_y[low, 3],
        line=:scatter, zcolor=df_sorted_by_y[low, title], markersize=10, markershape=:circle, c=cgrad([:red3, :red3, :red3]),# marker=([:hex :d], 12, 0.8, Plots.stroke(3, :gray)),
        xaxis=titles[1], yaxis=titles[2], zaxis=titles[3], lab="Low", colorbar=false, arrow=true,
        reuse=false)
    graph = @df df plot!(
        df_sorted_by_y[mid, 1], df_sorted_by_y[mid, 2], df_sorted_by_y[mid, 3],
        line=:scatter, zcolor=df_sorted_by_y[mid, title], markersize=10, markershape=:utriangle, c=cgrad([:yellow, :yellow, :yellow]),
        lab="Medium")
    graph = @df df plot!(
        df_sorted_by_y[high, 1], df_sorted_by_y[high, 2], df_sorted_by_y[high, 3],
        line=:scatter, zcolor=df_sorted_by_y[high, title], markersize=10, markershape=:square, c=cgrad([:green, :green, :green]),
        lab="High")
    display(graph)
end

# end
