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

n = size(df)[1]
x = select(df, 1, copycols=false)[1]
y = select(df, 2, copycols=false)[1]
z = select(df, 3, copycols=false)[1]
rangex = calc_range(x)
rangey = calc_range(y)
rangez = calc_range(z)
extx = extrema(x)
exty = extrema(y)
extz = extrema(z)
scalx = x / rangex
scaly = y / rangey
scalz = z / rangez
extscalx = extx ./ rangex
extscaly = exty ./ rangey
extscalz = extz ./ rangez

scene, layout = layoutscene()

s = layout[1, 1] = LScene(scene)
sort!(df, :y_yield)
scatter!(
    s,
    scalx, scaly, scalz,
    markersize = 100, marker = :circle,
    color = to_colormap(:RdYlGn_3, n),
    show_axis = true,
    # scale_plot = true,
    # transparency = true, alpha = 0.1,
    # shading = false,
    # limits = FRect3D( (3, 140, 2), (4, 40, 3) ),
)
xticks!(s.scene, xticklabels=string.(range(extx..., length=n)))
yticks!(s.scene, yticklabels=string.(range(exty..., length=n)))
zticks!(s.scene, zticklabels=string.(range(extz..., length=n)))
xlims!(s.scene, extscalx)
ylims!(s.scene, extscaly)
zlims!(s.scene, extscalz)

display(s.scene)

# end
