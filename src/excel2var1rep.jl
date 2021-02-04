# module excel2var1rep

# using PackageCompiler

using CSV
using DataFrames

using GLM
using AutoGrad

using Plots
using StatsPlots
# using PyPlot
# using Gadfly
# using Makie
# using Plotly, PlotlyJS
pyplot()

df = CSV.File("res/heat_treatement_data_2.csv") |> DataFrame

select!(df, Not(1))
titles = ["$(x) ($(y))" for (x, y) in zip(names(df), df[1, :])]
rename!(df, titles)
delete!(df, 1)
df[!, :] = parse.(Float16, df[!, :])

xs = df[:, 1:3]
ys = df[:, 4:6]

@df df plot(xs[1], xs[2], ys[1], zcolor=ys[1], xaxis="S time", yaxis="Temp.", lab="Yield")

struct Linear
    w
    b
end
(f::Linear)(x) = (f.w * x .+ f.b)

# Initialize a model as a callable object with parameters:
f = Linear(Param(randn(10, 100)), Param(randn(10)))

# SGD training loop:
for (x, y) in df
    loss = @diff sum(abs2, f(x) - y)
    for w in params(f)
        g = grad(loss, w)
        axpy!(-0.01, g, w)
    end
end

# end
