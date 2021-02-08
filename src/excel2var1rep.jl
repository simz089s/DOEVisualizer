# module excel2var1rep

# using PackageCompiler

using CSV
using DataFrames

# using ForwardDiff
# using AutoGrad
# using Polynomials
using GLM
using StatsModels

using Plots
using StatsPlots
# using PyPlot
# using Gadfly
# using Makie
# using Plotly, PlotlyJS
pyplot()

df = CSV.File("res/heat_treatement_data_2.csv") |> DataFrame

select!(df, Not(1))
# titles = replace.(["$(x) ($(y))" for (x, y) in zip(names(df), df[1, :])], " "=>"_")
titles = ["x_stime", "x_t", "x_atime", "y_yield", "y_str", "y_elong"]
rename!(df, titles)
delete!(df, 1)
df[!, :] = parse.(Float64, df[!, :])

xs = df[:, 1:3]
ys = df[:, 4:6]

f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
model = lm(f, select(df, 1:4))
# f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
# model = lm(f, select(df, 1:4))

@df df plot(xs[1], xs[2], ys[1], line=:scatter, zcolor=ys[1], xaxis="S time", yaxis="Temp.", lab="Yield")
@df df plot!(xs[1], xs[2], predict(model), line=:surface, label="y_yield ~ 1 + x_stime + x_t + x_atime")
@df df plot!(xs[1], xs[2], predict(model), line=:line, label="y_yield ~ 1 + x_stime + x_t + x_atime")

# @df df plot(xs[1], xs[3], ys[1], line=:scatter, zcolor=ys[1], xaxis="S time", yaxis="Temp.", lab="Yield")
# @df df plot!(xs[1], xs[3], predict(model), line=:surface, label="y_yield ~ 1 + x_stime + x_t + x_atime")
# @df df plot!(xs[1], xs[3], predict(model), line=:line, label="y_yield ~ 1 + x_stime + x_t + x_atime")

# @df df plot(xs[2], xs[3], ys[1], line=:scatter, zcolor=ys[1], xaxis="S time", yaxis="Temp.", lab="Yield")
# @df df plot!(xs[2], xs[3], predict(model), line=:surface, label="y_yield ~ 1 + x_stime + x_t + x_atime")
# @df df plot!(xs[2], xs[3], predict(model), line=:line, label="y_yield ~ 1 + x_stime + x_t + x_atime")

# end
