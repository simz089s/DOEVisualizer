# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames

# using ForwardDiff
# using AutoGrad
using GLM, StatsModels

using Plots, StatsPlots
# using Gadfly
# using Makie
pyplot()

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

low = 1 : NUM_VARS
mid = NUM_VARS + 1 : 2 * NUM_VARS
high = 2 * NUM_VARS + 1 : 3 * NUM_VARS

f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
model = glm(f, select(df, 1:4), Normal(), IdentityLink())

graphs = Array{Plots.Plot{Plots.PyPlotBackend}, 1}(undef, NUM_RESPS)
for (idx, title) ∈ enumerate(names(select(df, 4:6, copycols=false)))
    df_sorted_by_y = select(df, titles[1:3], title)
    df_sorted_by_y = sort!(df_sorted_by_y, title)
    graph = @df df plot(
        df_sorted_by_y[low, 1], df_sorted_by_y[low, 2], df_sorted_by_y[low, 3],
        line=:scatter, zcolor=df_sorted_by_y[low, title], markersize=10, markershape=:circle, c=cgrad([:red3, :red3, :red3]),
        lab="Low", xaxis=titles[1], yaxis=titles[2], zaxis=titles[3], colorbar=false,
        reuse=false)
    graph = @df df plot!(
        df_sorted_by_y[mid, 1], df_sorted_by_y[mid, 2], df_sorted_by_y[mid, 3],
        line=:scatter, zcolor=df_sorted_by_y[mid, title], markersize=10, markershape=:utriangle, c=cgrad([:yellow, :yellow, :yellow]),
        lab="Medium")
    graph = @df df plot!(
        df_sorted_by_y[high, 1], df_sorted_by_y[high, 2], df_sorted_by_y[high, 3],
        line=:scatter, zcolor=df_sorted_by_y[high, title], markersize=10, markershape=:square, c=cgrad([:green, :green, :green]),
        lab="High")
        graphs[idx] = graph
end
display(plot(graphs...))

# graph = @df df plot(df_sorted_by_y[1], df_sorted_by_y[2], predict(model), line=:surface)

# end
