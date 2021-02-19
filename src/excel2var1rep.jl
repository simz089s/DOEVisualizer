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

x = df[1]
y = df[2]
z = df[3]

scene, layout = layoutscene()

s = layout[1, 1] = LScene(scene)
scatter!(
    s,
    x, .1 * y, z,
    markersize = 300, marker = :circle,
    colormap = :RdYlGn_3,# colorrange = 1:80,
    # scale_plot = true,
    show_axis = true,
    # transparency = true, alpha = 0.1,
    # limits = FRect3D( (3, 140, 2), (4, 40, 3) ),
    # scale = (1, 1, 1),
    # axis = (
        # names = (
        #     axisnames = ("x", "y", "z"),
        # ),
        # scale = (1, .05, 1),
        # scale_plot = true,
        # ticks = (
        #     ranges = Node((3:7, 140:180, 2:5)),
        # ),
        # grid = (
        #     linewidth = (0, .5, 0),
        # ),
    # ),
)
# scale!(scene, 1, 1/100, 1)
yticks!(s.scene, yticklabels=string.(y))

# fig
display(scene)

# end
