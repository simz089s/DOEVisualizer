# module excel2var1rep

# using PackageCompiler

using CSV
using DataFrames

# using ForwardDiff
# using AutoGrad
using Polynomials
# using GLM
# using StatsModels

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
df[!, :] = parse.(Float16, df[!, :])

xs = df[:, 1:3]
ys = df[:, 4:6]

@df df plot(xs[1], xs[2], ys[1], zcolor=ys[1], xaxis="S time", yaxis="Temp.", lab="Yield")

# f(x, y) = 
# grad(x, y) = ForwardDiff.gradient(z -> f(z[1], z[2]), [x, y])

# struct Linear; w; b; end		# user defines a model
# (f::Linear)(x) = (f.w * x .+ f.b)
# # Initialize a model as a callable object with parameters:
# f = Linear(Param(randn(10, 100)), Param(randn(10)))
# f = Linear(Param(xs[1]), Param(xs[2]))
# # SGD training loop:
# for (x, y) in zip(xs[1], ys)
#     loss = @diff sum(abs2, f(x) - y)
#     for w in params(f)
#         g = grad(loss, w)
#         axpy!(-0.01, g, w)
#     end
# end

# f = Polynomial([1, 1, 1, 1]) # Weights go here
model = Polynomials.fit(xs[3], ys[1], 4)

# f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
# model = lm(f, select(df, 3:4), true)

scatter(xs[3], ys[1], markerstrokewidth=0, label="Data")
plot!(model, extrema(xs[3])..., label="deg = 6")

# end
