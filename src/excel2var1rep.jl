# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames
using Colors, Statistics
using GLMakie, AbstractPlotting
# using GLM, StatsModels

function read_data(filename)
    df = CSV.File(filename) |> DataFrame

    # First row after title should be indicating if the column is a variable or response
    types = df[1, :]
    num_vars = count(t -> !ismissing(t) && t == "variable", types)
    num_resps = count(t -> !ismissing(t) && t == "response", types)
    # NUM_LVLS = 
    num_rows = nrow(df) - 1 # Exclude row indicating if it is a variable or response column

    select!(df, Not(1)) # TODO: clarify if (redundant) index row will always be there
    # titles = replace.(["$(x) ($(y))" for (x, y) in zip(names(df), df[1, :])], " "=>"_")
    titles = [:x_stime, :x_t, :x_atime, :y_yield, :y_str, :y_elong] # TODO: find better way to title
    rename!(df, titles)
    delete!(df, 1) # Remove the row indicating if it is a variable or response column
    df[!, :] = parse.(Float64, df[!, :]) # Float64 for max compatibility with libraries...

    df, titles, types, num_vars, num_resps, num_rows
end

function get_xyzn(df)
    n = size(df)[1] # Number of rows (data points)
    # TODO: better way to select variables
    x = select(df, 1, copycols=false)[1]
    y = select(df, 2, copycols=false)[1]
    z = select(df, 3, copycols=false)[1]

    x, y, z, n
end

calc_range(a) = abs(-(extrema(a)...)) # Find interval size max-min of a set of values

function get_ranges(x, y, z)
    range_x = calc_range(x)
    range_y = calc_range(y)
    range_z = calc_range(z)

    ext_x = extrema(x)
    ext_y = extrema(y)
    ext_z = extrema(z)

    # Scale data to data/interval so that the plot is unit/equal sized
    scal_ext_x = ext_x ./ range_x
    scal_ext_y = ext_y ./ range_y
    scal_ext_z = ext_z ./ range_z

    range_x, range_y, range_z,
        ext_x, ext_y, ext_z,
        scal_ext_x, scal_ext_y, scal_ext_z
end

# Draw points and coordinates
function create_points_coords(s, x, y, z, range_x, range_y, range_z, scal_x, scal_y, scal_z, scal_plot_unit, colors)
    for (i, col) in enumerate(colors)
        scatter!(
            s,
            scal_x[i:i], scal_y[i:i], scal_z[i:i],
            markersize = scal_plot_unit * 5, marker = :circle,
            color = col,
            show_axis = true,
        )
        text!(
            s,
            "$((x[i], y[i], z[i]))",
            position = Point3f0(
                scal_x[i] + .5 / range_x,
                scal_y[i] + .1 / range_y,
                scal_z[i] + .2 / range_z
            ),
            textsize = scal_plot_unit / 500,
            color = :black,
            rotation = 3.15,
        )
    end
end

# Draw grid
# TODO: probably use some permutation function to make it more elegant
function create_grid(s, scal_uniq_var_vals, num_vars, n_uniq_var_vals)
    for var_dim_idx in 1:num_vars # scal_uniq_var_vals index of the dimension that will draw the line
        # scal_uniq_var_vals index of the other invariant dimensions
        invar_data_dim_idx1 = mod1(var_dim_idx + 1, 3)
        invar_data_dim_idx2 = mod1(var_dim_idx + 2, 3)
        for line_idx in 1:n_uniq_var_vals
            for line_idx2 in 1:n_uniq_var_vals
                invar_data_dim1 = fill(scal_uniq_var_vals[invar_data_dim_idx1][line_idx], n_uniq_var_vals)
                invar_data_dim2 = fill(scal_uniq_var_vals[invar_data_dim_idx2][line_idx2], n_uniq_var_vals)

                # Plot function takes in order x,y,z
                data = Array{Array{Float64, 1}, 1}(undef, 3)
                data[var_dim_idx] = scal_uniq_var_vals[var_dim_idx]
                data[invar_data_dim_idx1] = invar_data_dim1
                data[invar_data_dim_idx2] = invar_data_dim2

                lines!(
                    s,
                    data[1], data[2], data[3],
                    linestyle = :dash,
                    transparency = true,
                    color = RGBA(0., 0., 0., .4),
                    show_axis = true,
                )
            end
        end
    end
end

function create_plots(df, titles, title, num_vars, num_resps, num_rows, pos_fig)
    x, y, z, n = get_xyzn(df)

    range_x, range_y, range_z,
        ext_x, ext_y, ext_z,
        scal_ext_x, scal_ext_y, scal_ext_z = get_ranges(x, y, z)

    # Scale data to data/interval so that the plot is unit/equal sized
    xtickrange = range(scal_ext_x..., length = n)
    ytickrange = range(scal_ext_y..., length = n)
    ztickrange = range(scal_ext_z..., length = n)
    # The tick labels should still represent the original range of values
    xticklabels = string.(range(ext_x..., length = n))
    yticklabels = string.(range(ext_y..., length = n))
    zticklabels = string.(range(ext_z..., length = n))

    fig = Figure()

    colors = to_colormap(:RdYlGn_3, n) # Get N colors from colormap to represent response variable TODO: allow choosing colormap?

    # TODO: better way of knowing variable vs response columns
    titles_vars = view(titles, 1:num_vars)
    titles_resp = view(titles, num_vars+1:num_vars+num_resps)
    uniq_var_vals = [ df[.!nonunique(select(df, title_var)), title_var] for title_var in titles_vars ] # All unique values per variable
    n_uniq_var_vals = length(uniq_var_vals)
    # Scaled to value/interval
    scal_uniq_var_vals = uniq_var_vals[:, :]
    scal_uniq_var_vals[1] /= range_x
    scal_uniq_var_vals[2] /= range_y
    scal_uniq_var_vals[3] /= range_z

    lscene = LScene(
        fig[pos_fig...],
        scenekw = (
            camera = cam3d!,
            raw = false,
        ),
    )

    # Plot point one-by-one individually so we can map colormap to response value
    sort!(df, title)

    scal_x = x / range_x
    scal_y = y / range_y
    scal_z = z / range_z
    scal_plot_unit = mean((range_x, range_y, range_z))

    create_points_coords(lscene, x, y, z, range_x, range_y, range_z, scal_x, scal_y, scal_z, scal_plot_unit, colors)

    create_grid(lscene, scal_uniq_var_vals, num_vars, n_uniq_var_vals)

    xticks!(lscene.scene, xtickrange = xtickrange, xticklabels = xticklabels)
    yticks!(lscene.scene, ytickrange = ytickrange, yticklabels = yticklabels)
    zticks!(lscene.scene, ztickrange = ztickrange, zticklabels = zticklabels)

    fig
end

function create_save_button(fig, parent, filename)
    button = Button(
        parent,
        label = "Save",
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename.")
        fig.scene.center = false
        save(filename, fig.scene)
    end

    button
end

function create_refresh_button(fig, parent, filename)
    button = Button(
        parent,
        label = "Refresh",
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename.")
    end

    button
end

function create_menus(fig, parent)
    menu = Menu(parent, options = ["viridis", "heat", "blues"])

    # funcs = [sqrt, x->x^2, sin, cos]
    # menu2 = Menu(parent, options = zip(["Square Root", "Square", "Sine", "Cosine"], funcs))

    menu, menu2
end

# function create_toggles(fig)
#     toggles = [ Toggle(fig, active = false), Toggle(fig, active = false), Toggle(fig, active = true), ]
#     labels = [ Label( fig, lift(x -> x ? "active" : "inactive", t.active) ) for t in toggles ]

#     toggles, labels
# end

function main(args)
    filename_data = args[1]
    filename_save = args[2]

    df, titles, types, num_vars, num_resps, num_rows = read_data(filename_data) # TODO: better way to get filename/path

    main_fig = create_plots(df, titles, titles[1], num_vars, num_resps, num_rows, (2, 1:3))

    save_button = create_save_button(main_fig, main_fig[1, 1], filename_save)
    refresh_button = create_refresh_button(main_fig, main_fig[1, 2], filename_save)
    menus = create_menus(main_fig, main_fig[1, 3])
    # toggles, toggles_labels = create_toggles(main_fig)

    # main_fig[2, 2] = grid!(hvcat(2, toggles, toggles_labels, save_button, save_button), tellheight = false, tellwidth = false)
    trim!(main_fig.layout)

    display(main_fig)
end

args = (
    "res/heat_treatement_data_2.csv",
    "taguchi.png",
)
# args = readline()
main(args)

# f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
# model = glm(f, select(df, 1:4), Normal(), IdentityLink())

# menu en-haut
# multi-select plot
# refresh data
# streamlined use

# end
