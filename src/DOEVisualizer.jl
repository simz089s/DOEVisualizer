module DOEVisualizer

@info "Loading libraries..."

# using PackageCompiler

using Unicode, Dates, Statistics
using CSV, DataFrames
using GLMakie, AbstractPlotting
# using GLM, StatsModels

include("DOEVDBManager.jl")
# using DOEVDBManager

@info "Loading functions..."

function peek(thing)
    println(fieldnames(typeof(thing)))
    println(thing)
end


function find_csv(dir)
    for file in readdir(dir)
        if Unicode.normalize(last(file, 4), casefold = true) == ".csv" # Find first file that ends with .csv (case insensitive)
            return "$dir/$file"
        end
    end
    ""
end


function read_data(filename)
    df = CSV.File(filename) |> DataFrame

    # First row after title should be indicating if the column is a variable or response (except for test number column)
    types = map(t -> ismissing(t) ? "" : t, df[1, :])
    # num_lvls = num_vars * num_resps
    # num_rows = nrow(df) - 1 # Exclude row indicating if it is a variable or response column
    # idx_miss = [i for (i, t) in enumerate(types) if t == ""] # Missing type column indices
    # select!(df, Not(idx_miss)) # TODO: better way of knowing test number column (should always be first column?)
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

    (range_x, range_y, range_z,
     ext_x, ext_y, ext_z,
     scal_ext_x, scal_ext_y, scal_ext_z,)
end


# Draw points and coordinates
function create_points_coords(lscene, test_nums, resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors)
    n = nrow(test_nums)
    scal_xyz = Array{Point3f0, 1}(undef, n)
    pos_xyz = Array{Point3f0, 1}(undef, n)
    text_xyz = Array{String, 1}(undef, n)
    sampled_colors = Array{RGBf0, 1}(undef, n)

    for i in 1:n
        scal_xyz[i] = Point3f0( scal_x[i], scal_y[i], scal_z[i] )
        pos_xyz[i] = Point3f0(
            scal_x[i] + .25 / scal_plot_unit,
            scal_y[i] + .2 / scal_plot_unit,
            scal_z[i] + .2 / scal_plot_unit
        )
        text_xyz[i] = "#$(test_nums[i, 1])\n$(resp[i])"
        sampled_colors[i] = colors[resp[i]]
    end

    splot = scatter!(
        lscene,
        scal_x, scal_y, scal_z,
        markersize = scal_plot_unit * 35., marker = :circle,
        color = sampled_colors,
    )
    splot[1].val = scal_xyz # Re-order points by re-inserting with their sorted order to match colours

    annotations!(
        lscene,
        text_xyz,
        pos_xyz,
        textsize = scal_plot_unit / 25.,
        color = :black,
        rotation = 3.15,
        overdraw = true,
    )
end


# Draw grid
# TODO: probably use some permutation function to make it more elegant
function create_grid(lscene, scal_uniq_var_vals, num_vars, n_uniq_var_vals, scal_plot_unit)
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
                scatterlines!(
                    lscene,
                    line_data[1], line_data[2], line_data[3],
                    # linestyle = :dash,
                    # linewidth = 2.,
                    # transparency = true,
                    # color = RGBAf0(0., 0., 0., .4),
                    color = :black,
                    markercolor = :white,
                    markersize = scal_plot_unit * 33., # Just a tiny bit smaller than the coloured ones so they can be covered
                )
            end
        end
    end
end


create_titles(lscene, axis, titles) = axis[:names, :axisnames] = replace.((titles[1], titles[2], titles[3]), "_" => " ")


function create_colorbar(fig, parent, vals, title, cm)
    vals = sort(vals[!, 1])
    n = length(vals)
    vals_range = 1:n

    cbar = Colorbar(
        parent,
        ticks = LinearTicks(n),
        label = title,
        width = 25,
        flipaxis = false,
        flip_vertical_label = true,
        limits = extrema(vals),
        colormap = cm,
        vertical = true,
    )
end


function create_plots(lscene, df, vars, titles, title, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm; fig = Figure())
    x = select(vars, 1, copycols = false)[!, 1]
    y = select(vars, 2, copycols = false)[!, 1]
    z = select(vars, 3, copycols = false)[!, 1]
    n = nrow(vars)
    lvls = trunc(Int, sqrt(n))
    resp = select(df, title)[!, 1]

    range_x, range_y, range_z,
        ext_x, ext_y, ext_z,
        scal_ext_x, scal_ext_y, scal_ext_z = get_ranges(x, y, z)
    range_resp = calc_range(resp)

    # The data is unit-scaled down/normalized so that the plot looks isometric-ish/cubic

    xtickrange = range(scal_ext_x..., length = lvls)
    ytickrange = range(scal_ext_y..., length = lvls)
    ztickrange = range(scal_ext_z..., length = lvls)
    # The tick labels should still represent the original range of values
    xticklabels = string.(range(ext_x..., length = lvls))
    yticklabels = string.(range(ext_y..., length = lvls))
    zticklabels = string.(range(ext_z..., length = lvls))

    colors = AbstractPlotting.ColorSampler(to_colormap(cm), extrema(resp))

    uniq_var_vals = [ sort(df[.!nonunique(df, title_var), title_var]) for title_var in titles_vars ] # All unique values per variable
    n_uniq_var_vals = length(uniq_var_vals)
    # Scaled to value/interval
    scal_uniq_var_vals = uniq_var_vals[:, :]
    scal_uniq_var_vals[1] /= range_x
    scal_uniq_var_vals[2] /= range_y
    scal_uniq_var_vals[3] /= range_z

    # Sort to correctly map colors to points in create_points_coords() and for general convenience
    sort!(df, title)

    scal_x = x / range_x
    scal_y = y / range_y
    scal_z = z / range_z
    scal_plot_unit = mean((mean(scal_x), mean(scal_y), mean(scal_z)))

    create_grid(lscene, scal_uniq_var_vals, num_vars, n_uniq_var_vals, scal_plot_unit)

    axis = lscene.scene[OldAxis]
    axis[:showaxis] = true # This should be after initial plot/scene/axis creation but before others that might assume an existing axis

    create_points_coords(lscene, select(df, 1), resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors)

    # Correct tick labels so that they show the original values instead of the scaled down ones
    xticks!(lscene.scene, xtickrange = xtickrange, xticklabels = xticklabels)
    yticks!(lscene.scene, ytickrange = ytickrange, yticklabels = yticklabels)
    zticks!(lscene.scene, ztickrange = ztickrange, zticklabels = zticklabels)

    axis[:showgrid] = false
    # axis[:frame, :axiscolor] = :black
    axis[:ticks, :textcolor] = :black

    create_titles(lscene, axis, titles_vars)

    # scale!(lscene.scene, 1/range_x, 1/range_y, 1/range_z)
    # axis[:scale] = [1/range_x, 1/range_y, 1/range_z]

    fig, lscene
end

create_plots(df, vars, titles, title, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm; fig = Figure()) = create_plots(
    LScene(
        fig[pos_fig...],
        title = title,
        scenekw = (
            camera = cam3d!,
            raw = false,
        ),
    ), df, vars, titles, title, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm, fig = fig)


function loading_bar()
    fig = Figure()
#     ax = Axis(
#         fig,
#     )
#     text!(
#         ax,
#         "LOADING...",
#         position = Point2f0(0., 0.),
#         textsize = .5,
#         color = :black,
#         overdraw = true,
#     )
#     fig
    display(fig) # Triggers built-in loading bar for some reason ¯\_(¬_¬)_/¯
    fig
end


function create_save_button(fig, parent, lscene, filename)
    button = Button(
        parent,
        label = "Save",
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename.")
        lscene.scene.center = false
        AbstractPlotting.save(filename, lscene.scene)
        lscene.scene.center = true
        display(fig) # TODO: display() should not be called in callback?
    end

    button
end


function create_reload_button(fig, parent, lscene, filename, pos_fig, cm)
    button = Button(
        parent,
        label = "Reload",
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename.")
        df, titles, vars, resps, num_vars, num_resps = read_data(filename)
        titles_vars = names(vars)
        titles_resps = names(resps)
        menus = filter(x -> typeof(x) == Menu, fig.content)[1] # TODO: make sure deleting the *right* menu(s)
        delete!(menus)
        create_menus(fig, fig[1, 3:4], lscene, df, vars, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm) # TODO: better way to choose parent position
        reload_plot(fig, lscene, df, vars, titles, titles_resps[1], titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm)
    end

    button
end


function create_menus(fig, parent, lscene, df, vars, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm)
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
        reload_plot(fig, lscene, df, vars, titles, s, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm)
    end

    # parent = grid!(hvcat(2, menu_vars, menu_resp))#, tellheight = false, tellwidth = false)

    menu_resp
    # menu_vars, menu_resp
end


# TODO: Should display or leave that to caller?
# Find way to re-render properly (+ memory management)
function reload_plot(fig, lscene, df, vars, titles, title, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm)
    lbar = loading_bar()

    parent = fig[ pos_fig[1], max(pos_fig[2]...) + 1 ]
    # fig_content = parent.fig.content
    fig_content = fig.content

    # Delete previous plot objects
    # for i in 1:length(lscene.scene)
    #     delete!(lscene.scene, lscene.scene[end])
    # end
    empty!(lscene.scene.plots)
    cbar = filter(x -> typeof(x) == Colorbar, fig_content)[1]
    delete!(cbar)
    # GC.gc(true)
    # delete!(filter(x -> typeof(x) == LScene, fig_content)[1]) # TODO: Remake LScene instead of modify?

    lscene.title.val = title
    new_fig, new_lscene = create_plots(lscene, df, vars, titles, title, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm, fig = fig)
    create_colorbar(fig, parent, select(df, title), title, cm)
    display(new_fig)
end


function setup(df, titles, vars, resps, num_vars, num_resps, filename_data)
    pos_fig = (2, 1:3)
    titles_vars = names(vars)
    titles_resps = names(resps)
    default_resp = select(resps, 1)
    default_resp_title = names(default_resp)[1]
    cm = :RdYlGn_3
    filename_save = string("$(@__DIR__)/../", replace("$(now()) $default_resp_title $(join(titles_vars, '-')).png", r"[^a-zA-Z0-9_\-\.]" => '_'))

    @info "Creating main plot..."
    main_fig, main_ls = create_plots(df, vars, titles, default_resp_title, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm)
    @info "Creating other widgets..."
    cbar = create_colorbar(main_fig, main_fig[ pos_fig[1], max(pos_fig[2]...) + 1 ], default_resp, default_resp_title, cm)

    save_button = create_save_button(main_fig, main_fig[1, 1], main_ls, filename_save)
    menus = create_menus(main_fig, main_fig[1, 3:4], main_ls, df, vars, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm) # Created before reload button to be updated
    reload_button = create_reload_button(main_fig, main_fig[1, 2], main_ls, filename_data, pos_fig, cm)

    # main_fig[2, 2] = grid!(hvcat(2, toggles, toggles_labels, save_button, save_button), tellheight = false, tellwidth = false)
    trim!(main_fig.layout)

    set_window_config!(
        # renderloop = renderloop,
        # vsync = false,
        # framerate = 30.0,
        # float = false,
        # pause_rendering = false,
        focus_on_show = true,
        # decorated = true,
        title = "DoE Visualizer"
    )

    display(main_fig)
end


function __init__()
    filename_db, filename_data = args

    if isempty(filename_db)
        exit("No database file found. Exiting...")
    elseif isempty(filename_data)
        filename_data = find_csv("$(@__DIR__)/../res")
    end

    if isempty(filename_data)
        db = DOEVDBManager.setup(filename_db, "HEAT_TREATMENT_DATA_2")
        query = """
            SELECT *
            FROM $tablename;
        """
        df = get_data(db, query)
    else
        df, titles, vars, resps, num_vars, num_resps = read_data(filename_data)
        db = DOEVDBManager.setup(filename_db, splitext(basename(filename_data))[1], df)
    end

    # display(df_test)

    @info "Setting up interface and plots..."
    setup(df, titles, vars, resps, num_vars, num_resps, filename_data)

    # f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
    # model = glm(f, select(df, 1:4), Normal(), IdentityLink())
end


args = (
    "$(@__DIR__)/../db.db",
    raw"",
)
# args = readline()

end
