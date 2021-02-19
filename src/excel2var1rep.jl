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

calc_range(a) = abs(-(extrema(a)...))

x = df[1]
y = df[2]
z = df[3]

scene, layout = layoutscene()

s = layout[1, 1] = LScene(scene)
scatter!(
    s,
    x / calc_range(x), y / calc_range(y), z / calc_range(z),
    markersize = 100, marker = :circle,
    color = to_colormap(:RdYlGn_3, 9),
    show_axis = true,
    # scale_plot = true,
    # transparency = true, alpha = 0.1,
    # shading = false,
)
xticks!(s.scene, xticklabels=string.(x))
yticks!(s.scene, yticklabels=string.(y))
zticks!(s.scene, zticklabels=string.(z))
center!(scene)

# fig
display(s.scene)

# end
