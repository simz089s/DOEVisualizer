# module excel2var1rep

@info "Pre-compiling..."

# using PackageCompiler

using CSV, DataFrames
using Statistics
using GLMakie#, AbstractPlotting#, Makie
# using GLM, StatsModels

@info "Loading functions..."

function peek(thing)
    println(fieldnames(typeof(thing)))
    println(thing)
end


function read_data(filename)
    df = CSV.File(filename) |> DataFrame

    # First row after title should be indicating if the column is a variable or response (except for test number column)
    types = map(t -> ismissing(t) ? "" : t, df[1, :])
    # num_lvls = num_vars * num_resps
    # num_rows = nrow(df) - 1 # Exclude row indicating if it is a variable or response column
    # idx_miss = [i for (i, t) in enumerate(types) if t == ""] # Missing type column indices
    # select!(df, Not(idx_miss)) # TODO: better way of knowing test number column
    df[1, 1] = 0 # Change Missing test number to 0
    types = df[1, :]
    idx_vars = [i for (i, t) in enumerate(types) if t == "variable"] # Variables column indices
    idx_resps = [i for (i, t) in enumerate(types) if t == "response"] # Responses column indices

    titles = replace.(names(df), " " => "_")
    rename!(df, titles)
    delete!(df, 1) # Remove the row indicating if it is a variable or response column
    # df[!, :] = parse.(Float64, df[!, :]) # Float64 for max compatibility with libraries...
    # df[!, 1] = parse.(Int8, df[!, 1])
    df[!, 2:end] = parse.(Float64, df[!, 2:end])
    vars = select(df, idx_vars)
    resps = select(df, idx_resps)

    df, titles[2:end], vars, resps, length(idx_vars), length(idx_resps)#, num_rows
end


function get_xyzn(df)
    n = size(df)[1] # Number of rows (data points)
    # TODO: better way to select variables
    x = select(df, 1, copycols=false)[!, 1]
    y = select(df, 2, copycols=false)[!, 1]
    z = select(df, 3, copycols=false)[!, 1]

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


# TODO: Find way to make relative size
# Draw points and coordinates
function create_points_coords(lscene, test_nums, resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors)
    for (i, col) in enumerate(colors)
        scatter!(
            lscene,
            scal_x[i:i], scal_y[i:i], scal_z[i:i],
            markersize = scal_plot_unit * 40., marker = :circle,
            color = col,
            show_axis = true,
        )
        text!(
            lscene,
            "#$(test_nums[i, 1])\n$(resp[i, 1])",
            position = Point3f0(
                scal_x[i] + .25 / scal_plot_unit,
                scal_y[i] + .2 / scal_plot_unit,
                scal_z[i] + .2 / scal_plot_unit
            ),
            textsize = scal_plot_unit / 25.,
            color = :black,
            rotation = 3.15,
            overdraw = true,
        )
    end
    lscene.scene[OldAxis]
end


# Draw grid
# TODO: probably use some permutation function to make it more elegant
function create_grid(lscene, scal_uniq_var_vals, num_vars, n_uniq_var_vals)
    for var_dim_idx in 1:num_vars # scal_uniq_var_vals index of the dimension that will draw the line
        # scal_uniq_var_vals index of the other invariant dimensions
        invar_data_dim_idx1 = mod1(var_dim_idx + 1, 3)
        invar_data_dim_idx2 = mod1(var_dim_idx + 2, 3)
        for line_idx in 1:n_uniq_var_vals
            for line_idx2 in 1:n_uniq_var_vals
                invar_data_dim1 = fill(scal_uniq_var_vals[invar_data_dim_idx1][line_idx], n_uniq_var_vals)
                invar_data_dim2 = fill(scal_uniq_var_vals[invar_data_dim_idx2][line_idx2], n_uniq_var_vals)

                # Plot function takes in order x,y,z
                line_data = Array{Array{Float64, 1}, 1}(undef, 3)
                line_data[var_dim_idx] = scal_uniq_var_vals[var_dim_idx]
                line_data[invar_data_dim_idx1] = invar_data_dim1
                line_data[invar_data_dim_idx2] = invar_data_dim2

                lines!(
                    lscene,
                    line_data[1], line_data[2], line_data[3],
                    # linestyle = :dash,
                    linewidth = 2.,
                    # transparency = true,
                    # color = RGBAf0(0., 0., 0., .4),
                    color = :gray,
                    # show_axis = true,
                )
            end
        end
    end
end


function create_arrows(lscene, vals)
    arrows!(
        lscene,
        fill(Point3f0(vals[1][1], vals[2][1], vals[3][1]), 3),
        [ Point3f0(1, 0, 0), Point3f0(0, 1, 0), Point3f0(0, 0, 1), ],
        arrowcolor = :gray,
        arrowsize = .1,
        linecolor = :black,
        # linewidth = 5.,
        lengthscale = 1.25,
    )
end


create_titles(lscene, axis, titles) = axis[:names, :axisnames] = replace.((titles[1], titles[2], titles[3]), "_" => " ")


function create_plots(lscene, df, titles, title, titles_var, num_vars, num_resps, pos_fig; fig = Figure())
    df_no_test_num = select(df, Not(1))
    x, y, z, n = get_xyzn(df_no_test_num)
    lvls = trunc(Int, sqrt(n))

    range_x, range_y, range_z,
        ext_x, ext_y, ext_z,
        scal_ext_x, scal_ext_y, scal_ext_z = get_ranges(x, y, z)

    # Scale data to data/interval so that the plot is unit/equal sized
    xtickrange = range(scal_ext_x..., length = lvls)
    ytickrange = range(scal_ext_y..., length = lvls)
    ztickrange = range(scal_ext_z..., length = lvls)
    # The tick labels should still represent the original range of values
    xticklabels = string.(range(ext_x..., length = lvls))
    yticklabels = string.(range(ext_y..., length = lvls))
    zticklabels = string.(range(ext_z..., length = lvls))

    colors = to_colormap(:RdYlGn_3, n) # Get N colors from colormap to represent response variable TODO: allow choosing colormap?

    # TODO: better way of knowing variable vs response columns
    titles_vars = view(titles, 1:num_vars)
    titles_resp = view(titles, num_vars+1:num_vars+num_resps)
    uniq_var_vals = sort.([ df_no_test_num[.!nonunique(select(df_no_test_num, title_var)), title_var] for title_var in titles_vars ]) # All unique values per variable
    n_uniq_var_vals = length(uniq_var_vals)
    # Scaled to value/interval
    scal_uniq_var_vals = uniq_var_vals[:, :]
    scal_uniq_var_vals[1] /= range_x
    scal_uniq_var_vals[2] /= range_y
    scal_uniq_var_vals[3] /= range_z

    # Plot point one-by-one individually so we can map colormap to response value
    sort!(df, title)

    scal_x = x / range_x
    scal_y = y / range_y
    scal_z = z / range_z
    scal_plot_unit = mean(mean.((scal_x, scal_y, scal_z)))

    axis = create_points_coords(lscene, select(df, 1), select(df, title), x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors) # TODO: better way of knowing test_nums column

    create_grid(lscene, scal_uniq_var_vals, num_vars, n_uniq_var_vals)

    create_arrows(lscene, scal_uniq_var_vals)

    xticks!(lscene.scene, xtickrange = xtickrange, xticklabels = xticklabels)
    yticks!(lscene.scene, ytickrange = ytickrange, yticklabels = yticklabels)
    zticks!(lscene.scene, ztickrange = ztickrange, zticklabels = zticklabels)

    axis[:showaxis] = true
    axis[:showgrid] = false
    axis[:frame, :axiscolor] = :black
    # axis[:frame, :linecolor] = :black # Unneeded because `showgrid=false`
    axis[:ticks, :textcolor] = :black

    create_titles(lscene, axis, titles_var)

    fig, lscene
end

create_plots(df, titles, title, titles_var, num_vars, num_resps, pos_fig; fig = Figure()) = create_plots(
    LScene(
        fig[pos_fig...],
        title = title,
        scenekw = (
            camera = cam3d!,
            raw = false,
        ),
    ), df, titles, title, titles_var, num_vars, num_resps, pos_fig, fig = fig)


function create_save_button(fig, parent, lscene, filename)
    button = Button(
        parent,
        label = "Save",
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename.")
        lscene.scene.center = false
        save(filename, lscene.scene)
        lscene.scene.center = true
        display(fig)
    end

    button
end


function create_load_button(fig, parent, lscene, titles_vars, filename, pos_fig, cm)
    button = Button(
        parent,
        label = "Load",
    )

    on(button.clicks) do n
        df, titles, _, _, num_vars, num_resps = read_data(filename)
        println("$(button.label[]) -> $filename.")
        reload_plot(fig, lscene, df, titles, lscene.title.val, titles_vars, num_vars, num_resps, pos_fig, cm)
    end

    button
end


function create_menus(fig, parent, lscene, df, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm)
    # menu_vars = Menu(
    #     parent,
    #     options = titles[1:3],
    #     prompt = "Select variables...",
    #     halign = :left,
    #     width = 5,
    # )
        
    menu_resp = Menu(
        parent,
        options = titles_resps,
        prompt = "Select response...",
        # halign = :right,
    )

    on(menu_resp.selection) do s
        println("Select response -> $s.")
        reload_plot(fig, lscene, df, titles, s, titles_vars, num_vars, num_resps, pos_fig, cm)
    end

    # parent = grid!(hvcat(2, menu_vars, menu_resp))#, tellheight = false, tellwidth = false)

    menu_resp
    # menu_vars, menu_resp
end


# Find way to re-render properly (+ memory management)
function reload_plot(fig, lscene, df, titles, title, titles_vars, num_vars, num_resps, pos_fig, cm)
    parent = fig[ pos_fig[1] + 1, pos_fig[2] ]
    fig_content = parent.fig.content

    # Delete previous plot objects
    for i in 1:length(lscene.scene.plots)
        delete!(lscene.scene, lscene.scene.plots[1])
    end
    cbar = filter(x -> typeof(x) == Colorbar, fig_content)[1]
    delete!(cbar)
    GC.gc(true)

    lscene.title.val = title
    new_fig, new_lscene = create_plots(lscene, df, titles, title, titles_vars, num_vars, num_resps, pos_fig, fig = fig)
    cbar = Colorbar(
        parent,
        colormap = cm,
        limits = extrema(df[!, title]),
        label = title,
        height = 25,
        vertical = false,
    )
    display(new_fig)
end


function setup(df, titles, vars, resps, num_vars, num_resps, filename_data, filename_save)
    pos_fig = (2, 1:3)
    titles_vars = names(vars)
    titles_resps = names(resps)
    default_resp = select(resps, 1)
    default_resp_title = names(default_resp)[1]
    cm = :RdYlGn_3

    main_fig, main_ls = create_plots(df, titles, default_resp_title, titles_vars, num_vars, num_resps, pos_fig) # TODO: Generate which response plot by default?
    cbar = Colorbar(
        main_fig[ pos_fig[1] + 1, pos_fig[2] ],
        colormap = cm,
        limits = extrema(Array(default_resp)),
        label = default_resp_title,
        height = 25,
        vertical = false,
        ticks = LinearTicks(5),
    )

    save_button = create_save_button(main_fig, main_fig[1, 1], main_ls, filename_save)
    refresh_button = create_load_button(main_fig, main_fig[1, 2], main_ls, titles_vars, filename_data, pos_fig, cm)
    menus = create_menus(main_fig, main_fig[1, 3], main_ls, df, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm)

    # main_fig[2, 2] = grid!(hvcat(2, toggles, toggles_labels, save_button, save_button), tellheight = false, tellwidth = false)
    trim!(main_fig.layout)

    display(main_fig)
end


function main(args)
    filename_data = args[1]
    filename_save = args[2]

    df, titles, vars, resps, num_vars, num_resps = read_data(filename_data) # TODO: better way to get filename/path

    @info "Setting up interface and plots..."
    setup(df, titles, vars, resps, num_vars, num_resps, filename_data, filename_save)
end


args = (
    "res/heat_treatement_data_2.csv",
    "taguchi.png",
)
# args = readline()
main(args)

# f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
# model = glm(f, select(df, 1:4), Normal(), IdentityLink())

# end
