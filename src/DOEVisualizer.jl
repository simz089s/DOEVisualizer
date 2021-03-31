module DOEVisualizer

@info "Loading libraries..."

# using PackageCompiler
# using BenchmarkTools

using Unicode, Dates, Statistics
import JSON: parsefile
using CSV, DataFrames
using GLMakie, AbstractPlotting
using GLM#, StatsModels, MultivariateStats

include("DOEVDBManager.jl")
# using DOEVDBManager

@info "Loading functions..."

# TODO: Use structs to better pass plot information
# struct orthogonal
#     fig
#     sublayouts
#     lscenes
#     cbars
#     pos
# end


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


function get_range_scales(a)
    scal = calc_range(a)
    ext = extrema(a)
    # Scale data to data/interval so that the plot is unit/equal sized
    scal, ext, ext ./ scal
end


# Draw points and coordinates
function create_points_coords(lscene, test_nums, resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors)
    n = nrow(test_nums)
    scal_xyz = Array{Point3, 1}(undef, n)
    text_xyz = Array{String, 1}(undef, n)
    pos_xyz = Array{Point3, 1}(undef, n)
    sampled_colors = Array{RGBf0, 1}(undef, n)

    for i = 1 : n
        scal_xyz[i] = Point3( scal_x[i], scal_y[i], scal_z[i] )
        text_xyz[i] = "#$(test_nums[i, 1])\n$(resp[i])"
        pos_xyz[i] = Point3( scal_x[i], scal_y[i], scal_z[i] + .03 * scal_plot_unit )
        sampled_colors[i] = colors[resp[i]]
    end

    splot = scatter!(
        lscene,
        scal_x, scal_y, scal_z,
        markersize = scal_plot_unit * 35., marker = :circle,
        color = sampled_colors,
        show_axis = true,
    )
    splot[1].val = scal_xyz # Re-order points by re-inserting with their sorted order to match colours

    # # 135° rotation = -√2/2 + √2/2im
    # θ = π * .125 # .25 * .5 = π/4 / 2
    txtplot = annotations!(
        lscene,
        text_xyz,
        pos_xyz,
        textsize = scal_plot_unit * 10.,
        color = :black,
        # rotation = Quaternion(0., sin(θ), cos(θ), 0.),
        align = (:center, :bottom),
        justification = :center,
        space = :screen,
        overdraw = true,
        visible = true,
        show_axis = true,
    )

    splot, txtplot
end


# Draw grid
# TODO: probably use some permutation function to make it more elegant and a set instead of array mod1 indices
function create_grid(lscene, scal_uniq_var_vals, num_vars, scal_plot_unit)
    line_data = Array{Array{Float64, 1}, 1}(undef, 3)

    # scal_uniq_var_vals index of the dimension that will draw the line
    for var_dim_idx = 1 : 3
        # scal_uniq_var_vals index of the other invariant dimensions
        invar_data_dim_idx1 = mod1(var_dim_idx + 1, 3)
        invar_data_dim_idx2 = mod1(var_dim_idx + 2, 3)

        # for line_idx1 = 1 : 3, line_idx2 = 1 : 3
        for idx = 1 : 9
            line_idx1, line_idx2 = fldmod1(idx, 3)
            invar_val1 = scal_uniq_var_vals[invar_data_dim_idx1][line_idx1]
            invar_val2 = scal_uniq_var_vals[invar_data_dim_idx2][line_idx2]

            # Plot function takes in order x,y,z
            line_data[var_dim_idx] = scal_uniq_var_vals[var_dim_idx]
            line_data[invar_data_dim_idx1] = fill(invar_val1, 3)
            line_data[invar_data_dim_idx2] = fill(invar_val2, 3)

            scatterlines!(
                lscene,
                line_data[1], line_data[2], line_data[3],
                color = :black,
                markercolor = :white,
                markersize = scal_plot_unit * 33., # Just a tiny bit smaller than the coloured ones so they can be covered
                show_axis = true,
            )
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


function create_table(fig, parent, df)
    nr = nrow(df)
    nc = ncol(df)
    N = nr * nc
    ax = parent = Axis(
        parent,
        # title = "Data",
        yreversed = true,
    )
    sort!(df, 1) # Sort by test number
    data = string.(reshape(Matrix{Float64}(df), N))
    pos = reshape([Point2(j, i) for i = 1 : nr, j = 1 : nc], N)
    txt = text!(
        ax,
        data,
        position = pos,
        align = (:center, :center),
        justification = :center,
    )
    txtitles = text!(
        ax,
        names(df),
        position = [Point2(i, 0.) for i = 1 : nc],
        align = (:center, :center),
        justification = :center,
    )
    hidedecorations!(ax)
    ax, txt, txtitles
end


function create_plots(fig, lscene, df, titles, title_resp, titles_vars, titles_resps, num_vars, num_resps, cm)
    resp = df[!, title_resp]

    # Sort to correctly map colors to points in create_points_coords() and for general convenience
    sort!(df, title_resp)

    x = df[!, titles_vars[1]]
    y = df[!, titles_vars[2]]
    z = df[!, titles_vars[3]]
    
    # The data is unit-scaled down/normalized so that the plot looks isometric-ish/cubic

    range_x, ext_x, scal_ext_x = get_range_scales(x)
    range_y, ext_y, scal_ext_y = get_range_scales(y)
    range_z, ext_z, scal_ext_z = get_range_scales(z)

    scal_x = x / range_x
    scal_y = y / range_y
    scal_z = z / range_z
    scal_plot_unit = mean((mean(scal_x), mean(scal_y), mean(scal_z)))

    xtickrange = range(scal_ext_x..., length = 3)
    ytickrange = range(scal_ext_y..., length = 3)
    ztickrange = range(scal_ext_z..., length = 3)
    # The tick labels should still represent the original range of values
    xticklabels = string.(range(ext_x..., length = 3))
    yticklabels = string.(range(ext_y..., length = 3))
    zticklabels = string.(range(ext_z..., length = 3))

    uniq_var_vals = [ sort(df[.!nonunique(df, title_var), title_var]) for title_var in titles_vars ] # All unique values per variable
    # Scaled to value/interval
    scal_uniq_var_vals = [uniq_var_vals[1] / range_x,
                          uniq_var_vals[2] / range_y,
                          uniq_var_vals[3] / range_z]

    colors = AbstractPlotting.ColorSampler(to_colormap(cm), extrema(resp))

    create_grid(lscene, scal_uniq_var_vals, num_vars, scal_plot_unit)

    axis = lscene.scene[OldAxis]
    axis[:showaxis] = true # Just in case `show_axis = true` doesn't work/is forgotten...

    plot_pts = create_points_coords(lscene, select(df, 1), resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors)

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

    plot_pts
end


function create_cm_sliders(fig, parent, resp_df, resp_plot, cbar, pos_sub)
    scal, ext, _ = get_range_scales(resp_df)

    slider = parent[pos_sub...] = IntervalSlider(
        fig,
        range = ext[1] - scal : .1 : ext[2] + scal,
        startvalues = ext,
    )

    slider_lab = parent[pos_sub[1] + 1, pos_sub[2]] = Label(
        fig,
        @lift(string(round.($(slider.interval), digits = 2))),
        tellwidth = false,
    )

    on(slider.interval) do interval
        # println("Select interval for $ -> $interval.")
        ordered_resp = map(x -> parse(Float64, x[4:end]), resp_plot[2].input_args[1].val)
        ext = extrema(ordered_resp)
        lims = (min(slider.interval.val[1], ext[1]), max(slider.interval.val[2], ext[2]))

        cm = cbar.colormap.val
        resp_plot[1].colormap = cm
        col_samp = AbstractPlotting.ColorSampler(to_colormap(cm), lims)
        resp_plot[1].color = [col_samp[resp] for resp in ordered_resp]

        cbar.limits = lims
    end

    slider, slider_lab
end


# TODO: use regression instead of middle value?
function create_plot_regression(fig, parent, df, titles_vars, title_resp, pos_sub, cm)
    f = @eval @formula($(Symbol(title_resp)) ~ $(Symbol(titles_vars[1])) + $(Symbol(titles_vars[2])) + $(Symbol(titles_vars[3])))
    model = glm(f, df, Normal(), IdentityLink())
    # ŷ = predict(model)
    ctbl = coeftable(model)
    Zs = sort!(deleteat!(ctbl.rownms .=> ctbl.cols[3], 1), by = x -> abs(getfield(x, :second)))
    colors = to_colormap(:RdYlGn_4, 3) # red:yellow:green :: low variance:medium variance:high variance
    var_colors = Dict(first.(Zs) .=> colors)
    xs = 1 : 3
    ax = parent[pos_sub[1], pos_sub[2]] = Axis(fig, title = "Mean average of $title_resp values\nper single variable value", xticks = xs,)
    plots = Vector{AbstractPlotting.ScatterLines}(undef, 3)

    for (i, var_title) ∈ enumerate(titles_vars)
        df = sort(df, [var_title, title_resp])
        ys = df[!, title_resp]
        mids = ys[2:3:end]
        lows = ys[1:3:end]
        highs = ys[3:3:end]
        means = mean.(zip(mids, lows, highs))
        col = var_colors[var_title]

        eb = errorbars!(
            ax,
            xs .+ .05 * i, mids, mids - lows, highs - mids,
            color = :black,
        )

        sc = plots[i] = scatterlines!(
            ax,
            xs .+ .05 * i, means,
            color = col,
            markercolor = col,
        )
    end

    leg = parent[pos_sub[1] + 1, pos_sub[2]] = Legend(
        fig,
        plots,
        titles_vars,
        orientation = :horizontal,
        tellwidth = false,
    )

    rowsize!(parent, pos_sub[1] + 1, Relative(.05))

    ax
end


function loading_bar()
    fig = Figure()
#     ax = Axis(
#         fig,
#     )
#     text!(
#         ax,
#         "LOADING...",
#         position = Point2(0., 0.),
#         textsize = .5,
#         color = :black,
#         overdraw = true,
#     )
#     fig
    display(fig) # Triggers built-in loading bar for some reason ¯\_(¬_¬)_/¯
    fig
end


function create_save_button(fig, parent, filename; but_lab = "Save")
    button = Button(
        parent,
        label = but_lab,
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename.")
        fig.scene.center = false
        save(filename, fig.scene)
        fig.scene.center = true
        display(fig) # TODO: display() should not be called in callback?
    end

    button
end


function create_reload_button(fig, parent, lscenes, tbl_txt, tbl_titles, filename, pos_fig, cm; but_lab = "Reload")
    button = Button(
        parent,
        label = but_lab,
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename.")
        df, titles, vars, resps, num_vars, num_resps = read_data(filename)
        titles_vars = names(vars)
        titles_resps = names(resps)
        # menus = filter(x -> typeof(x) == Menu, fig.content)[1] # TODO: make sure deleting the *right* menu(s)
        # delete!(menus)
        # create_menus(fig, fig[1, 3:4], lscenes[1], df, vars, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm) # TODO: better way to choose parent position
        loading_bar()
        reload_plot(fig, lscenes[1], df, titles, titles_resps[1], titles_vars, titles_resps, num_vars, num_resps, pos_fig, (1, 1), cm)
        reload_plot(fig, lscenes[2], df, titles, titles_resps[2], titles_vars, titles_resps, num_vars, num_resps, pos_fig, (1, 3), cm)
        reload_plot(fig, lscenes[3], df, titles, titles_resps[3], titles_vars, titles_resps, num_vars, num_resps, pos_fig, (2, 1), cm)
        reload_table(fig, df, tbl_txt, tbl_titles)
        # GC.gc(true)
        display(fig) # TODO: display() should not be called in callback?
    end

    button
end


# function create_menus(fig, parent, lscene, df, vars, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm)
#     # menu_vars = Menu(
#     #     parent,
#     #     options = titles[1:3],
#     #     prompt = "Select variables...",
#     #     halign = :left,
#     #     width = 5,
#     # )

#     menu_resp = Menu(
#         parent,
#         options = titles_resps,
#         prompt = "Select response...",
#         # halign = :right,
#     )

#     on(menu_resp.selection) do s
#         println("Select response -> $s.")
#         reload_plot(fig, lscene, df, vars, titles, s, titles_vars, titles_resps, num_vars, num_resps, pos_fig, (2, 1), cm)
#     end

#     # parent = grid!(hvcat(2, menu_vars, menu_resp))#, tellheight = false, tellwidth = false)

#     menu_resp
#     # menu_vars, menu_resp
# end


function create_cm_menu(fig, parent, splots, cbars, cm_sliders, cm; menu_prompt = "Select color palette...")
    menu = Menu(
        parent,
        options = [cm, :seaborn_bright, :seaborn_bright6, :seaborn_colorblind, :seaborn_colorblind6, :seaborn_dark, :seaborn_dark6, :seaborn_deep, :seaborn_deep6, :seaborn_icefire_gradient, :seaborn_muted, :seaborn_muted6, :seaborn_pastel, :seaborn_pastel6, :seaborn_rocket_gradient],
        prompt = menu_prompt,
    )

    on(menu.selection) do sel
        println("Select colormap -> $sel.")
        for (splot, cbar, slider) in zip(splots, cbars, cm_sliders)
            ordered_resp = map(x -> parse(Float64, x[4:end]), splot[2].input_args[1].val)
            ext_resp = extrema(ordered_resp)
            lims = (min(slider.interval.val[1], ext_resp[1]), max(slider.interval.val[2], ext_resp[2]))

            splot[1].colormap = sel
            col_samp = AbstractPlotting.ColorSampler(to_colormap(sel), lims)
            splot[1].color = [col_samp[resp] for resp in ordered_resp]

            cbar.colormap = sel
            cbar.limits = lims
        end
    end

    menu
end


# TODO: Should display or leave that to caller?
# Find way to re-render properly (+ memory management)
function reload_plot(fig, lscene, df, titles, title_resp, titles_vars, titles_resps, num_vars, num_resps, pos_fig, pos_sub, cm)
    # lbar = loading_bar()

    # Delete previous plot objects
    # for i in 1:length(lscene.scene)
    #     delete!(lscene.scene, lscene.scene[end])
    # end
    empty!(lscene.scene.plots)
    cbar = filter(x -> typeof(x) == Colorbar, fig.content)[1]
    delete!(cbar)
    # GC.gc(true)
    # delete!(filter(x -> typeof(x) == LScene, fig.content)[1]) # TODO: Remake LScene instead of modify?

    plots_gridlayout = content(fig[pos_fig...])
    lscene.title.val = title_resp
    plot_new = create_plots(fig, lscene, df, titles, title_resp, titles_vars, titles_resps, num_vars, num_resps, cm)
    plots_gridlayout[pos_sub...] = lscene
    plots_gridlayout[pos_sub[1], pos_sub[2] + 1] = create_colorbar(fig, fig[pos_fig...], select(df, title_resp), title_resp, cm)
    # display(fig)
end


function reload_table(fig, df, plot_txt, plot_titles)
    nr = nrow(df)
    nc = ncol(df)
    N = nr * nc
    sort!(df, 1) # Sort by test number
    data = string.(reshape(Matrix{Float64}(df), N))
    # pos = reshape([Point2(j, i) for i = 1 : nr, j = 1 : nc], N)
    plot_txt[1].val = data
    plot_titles[1].val = names(df)
end


function setup(df, titles, vars, resps, num_vars, num_resps, filename_data, intlcl)
    titles_vars = names(vars)
    titles_resps = names(resps)
    filename_save = string("$(@__DIR__)/../res/", replace("$(now()) $(join(vcat(titles_vars, titles_resps), '-')).png", r"[^a-zA-Z0-9_\-\.]" => '_'))
    pos_fig = (2, 1:4)
    cm = :RdYlGn_3

    @info "Creating main plot..."
    main_fig = Figure()
    basic_ls(main_fig, pos_fig, title) = LScene(
        main_fig[pos_fig...],
        title = title,
        scenekw = (
            camera = cam3d!,
            raw = false,
        ),
    )
    plot_sublayout = main_fig[pos_fig...] = GridLayout()

    lscene1 = basic_ls(main_fig, pos_fig, title)
    plot1 = create_plots(main_fig, lscene1, df, titles, titles_resps[1], titles_vars, titles_resps, num_vars, num_resps, cm)
    plot_sublayout[1, 1] = lscene1
    cbar1 = plot_sublayout[1, 2] = create_colorbar(main_fig, main_fig, select(resps, 1), titles_resps[1], cm)

    lscene2 = basic_ls(main_fig, pos_fig, title)
    plot2 = create_plots(main_fig, lscene2, df, titles, titles_resps[2], titles_vars, titles_resps, num_vars, num_resps, cm)
    plot_sublayout[1, 3] = lscene2
    cbar2 = plot_sublayout[1, 4] = create_colorbar(main_fig, main_fig, select(resps, 2), titles_resps[2], cm)

    lscene_main = basic_ls(main_fig, pos_fig, title)
    plot_main = create_plots(main_fig, lscene_main, df, titles, titles_resps[3], titles_vars, titles_resps, num_vars, num_resps, cm)
    plot_sublayout[4, 1] = lscene_main
    cbar_main = plot_sublayout[4, 2] = create_colorbar(main_fig, main_fig, select(resps, 3), titles_resps[3], cm)
    cam_main = cameracontrols(lscene_main.scene)
    # cam_main = cam3d!(lscene_main.scene)

    lscene1.scene.camera = lscene_main.scene.camera
    lscene1.scene.camera_controls[] = cam_main
    lscene2.scene.camera = lscene_main.scene.camera
    lscene2.scene.camera_controls[] = cam_main

    lscenes = [lscene1, lscene2, lscene_main]

    cm_slider1, cm_slider_lab1 = create_cm_sliders(main_fig, plot_sublayout, resps[!, 1], plot1, cbar1, (2, 1:2))
    cm_slider2, cm_slider_lab2 = create_cm_sliders(main_fig, plot_sublayout, resps[!, 2], plot2, cbar2, (2, 3:4))
    cm_slider_main, cm_slider_lab_main = create_cm_sliders(main_fig, plot_sublayout, resps[!, 3], plot_main, cbar_main, (5, 1:2))

    tbl_ax, tbl_txt, tbl_titles = create_table(main_fig, main_fig, df)
    plot_sublayout[4:6, 3:4] = tbl_ax

    regress_sublayout = main_fig[1:pos_fig[1], pos_fig[2][end] + 1] = GridLayout()
    pos_reg_cbar = (1, 1)
    pos_reg_anchor = (3, 1)
    regr1 = regress_sublayout[pos_reg_anchor[1] + 0, pos_reg_anchor[2]] = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[1], (pos_reg_anchor[1] + 0, pos_reg_anchor[2]), cm)
    regr2 = regress_sublayout[pos_reg_anchor[1] + 2, pos_reg_anchor[2]] = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[2], (pos_reg_anchor[1] + 2, pos_reg_anchor[2]), cm)
    regr3 = regress_sublayout[pos_reg_anchor[1] + 4, pos_reg_anchor[2]] = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[3], (pos_reg_anchor[1] + 4, pos_reg_anchor[2]), cm)
    cbar_regr = regress_sublayout[pos_reg_cbar...] = Colorbar(
        main_fig,
        label = intlcl["cbar_regr_lab"],
        limits = (1, 3),
        colormap = cgrad(:RdYlGn_4, 3, categorical = true),
        vertical = false,
        labelpadding = 5.,
        ticksize = 0.,
        ticklabelsvisible = false,
    )
    rowsize!(regress_sublayout, pos_reg_cbar[1], Relative(.03))
    cbar_regr_labs = regress_sublayout[pos_reg_cbar[1] + 1, pos_reg_cbar[2]] = grid!(permutedims(hcat([Label(main_fig, lab, tellwidth = false) for lab in intlcl["cbar_regr_labs"]])))
    rowsize!(regress_sublayout, pos_reg_cbar[1] + 1, Relative(.001))

    @info "Creating other widgets..."
    save_button = create_save_button(main_fig, main_fig[1, 1], filename_save; but_lab = intlcl["save_but_lab"])
    reload_button = create_reload_button(main_fig, main_fig[1, 2], lscenes, tbl_txt, tbl_titles, filename_data, pos_fig, cm; but_lab = intlcl["reload_but_lab"])
    # menus = create_menus(main_fig, main_fig[1, 3:4], lscene1, df, vars, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm) # Created before reload button to be updated
    cm_menu = create_cm_menu(main_fig, main_fig, [plot1, plot2, plot_main], [cbar1, cbar2, cbar_main], [cm_slider1, cm_slider2, cm_slider_main], cm; menu_prompt = intlcl["cm_menu_prompt"])
    button_sublayout = main_fig[1, 1:4] = grid!(hcat(save_button, reload_button, cm_menu))

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

    # TODO: Implement
    if isempty(filename_data)
        # db = DOEVDBManager.setup(filename_db, "HEAT_TREATMENT_DATA_2")
        # query = """
        #     SELECT *
        #     FROM $tablename;
        # """
        # df = get_data(db, query)
        @error "NOT IMPLEMENTED YET: Get data from DB when no CSV file"
        exit(1)
    else
        df, titles, vars, resps, num_vars, num_resps = read_data(filename_data)
        # db = DOEVDBManager.setup(filename_db, splitext(basename(filename_data))[1], df)
    end
    # display(df_test)

    intlcl = parsefile("$(@__DIR__)/../cfg/DOEVconfig.json")

    @info "Setting up interface and plots..."
    setup(df, titles, vars, resps, num_vars, num_resps, filename_data, intlcl)
end


args = (
    "$(@__DIR__)/../db.db",
    raw"",
)
# args = readline()

end
