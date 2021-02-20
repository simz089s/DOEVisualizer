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
extscalx = extx ./ rangex
extscaly = exty ./ rangey
extscalz = extz ./ rangez

scene, layout = layoutscene()

s = layout[1, 1] = LScene(scene)
colors = to_colormap(:RdYlGn_3, n)
sort!(df, :y_yield)
for (idx, col) in enumerate(colors)
    scalx = x / rangex
    scaly = y / rangey
    scalz = z / rangez
    scatter!(
        s,
        [scalx[idx]], [scaly[idx]], [scalz[idx]],
        markersize = 100, marker = :circle,
        color = col,
        show_axis = true,
        camera = cam3d!,
    )
end
xticks!(s.scene, xtickrange=range(extscalx..., length=n), xticklabels=string.(range(extx..., length=n)))
yticks!(s.scene, ytickrange=range(extscaly..., length=n), yticklabels=string.(range(exty..., length=n)))
zticks!(s.scene, ztickrange=range(extscalz..., length=n), zticklabels=string.(range(extz..., length=n)))
# xlims!(s.scene, extscalx)
# ylims!(s.scene, extscaly)
# zlims!(s.scene, extscalz)

display(s.scene)

# end
