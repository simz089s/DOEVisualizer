module DOEVisualizer


@info "Loading libraries..."

# using PackageCompiler
# using BenchmarkTools

using Unicode, Dates, Statistics, LinearAlgebra
# import JSON: parsefile
using CSV, DataFrames
using GLMakie, AbstractPlotting
using GLM#, MultivariateStats, LsqFit
# using Polynomials, OnlineStats, Grassmann, Optim, Interpolations, GridInterpolations, Combinatorics, IterativeSolvers

using Gtk

# include("DOEVUI.jl")
# include("DOEVDBManager.jl")


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


function find_csv(dir)::String
    for file in readdir(dir)
        if Unicode.normalize(last(file, 4), casefold = true) in (".csv", ".tsv") # Find first file that ends with .{c,t}sv (case insensitive)
            return "$dir/$file"
        end
    end
    ""
end


function read_data(filename)
    df = DataFrame(CSV.File(filename))

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


calc_interval(a) = abs(-(extrema(a)...))


function get_interval_scales(a)
    scal = calc_interval(a)
    ext = extrema(a)
    scal, ext, ext ./ scal # For min-max scaling/unity-based normalization
end


function create_plot3(lscene, resp, scal_x, scal_y, scal_z, colors; marker = :circle, markersize = 80)
    n = length(resp)
    scal_xyz = Array{Point3, 1}(undef, n)
    sampled_colors = Array{RGBf0, 1}(undef, n)

    for i = 1 : n
        scal_xyz[i] = Point3(scal_x[i], scal_y[i], scal_z[i])
        sampled_colors[i] = colors[resp[i]]
    end

    splot3 = scatter!(
        lscene,
        scal_x, scal_y, scal_z,
        marker = marker,
        markersize = markersize,
        color = sampled_colors,
        strokecolor = sampled_colors,
        # strokewidth = 0.,
        show_axis = true,
    )
    splot3[1][] = scal_xyz # Re-order points by re-inserting with their sorted order to match colours

    splot3
end

# Draw points and coordinates
function create_points_coords(lscene, test_nums, resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors, markersize = 50)
    n = nrow(test_nums)
    scal_xyz = Array{Point3, 1}(undef, n)
    text_xyz = Array{String, 1}(undef, n)
    pos_xyz = Array{Point3, 1}(undef, n)
    sampled_colors = Array{RGBf0, 1}(undef, n)

    for i = 1 : n
        scal_xyz[i] = Point3(scal_x[i], scal_y[i], scal_z[i])
        text_xyz[i] = "#$(test_nums[i, 1])\n$(resp[i])"
        pos_xyz[i] = Point3(scal_x[i], scal_y[i], scal_z[i] + .03 * scal_plot_unit)
        sampled_colors[i] = colors[resp[i]]
    end

    splot = scatter!(
        lscene,
        scal_x, scal_y, scal_z,
        marker = :circle,
        markersize = markersize,
        color = sampled_colors,
        show_axis = true,
    )
    splot[1].val = scal_xyz # Re-order points by re-inserting with their sorted order to match colours

    txtplot = annotations!(
        lscene,
        text_xyz,
        pos_xyz,
        color = :black,
        rotations = Billboard(),
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
function create_grid(lscene, scal_uniq_var_vals, num_vars, scal_plot_unit, markersize = 45)
    line_data = Array{Array{Float64, 1}, 1}(undef, 3)

    # scal_uniq_var_vals index of the dimension that will draw the line
    for var_dim_idx = 1 : 3
        # scal_uniq_var_vals index of the other invariant dimensions
        invar_data_dim_idx1 = mod1(var_dim_idx + 1, 3)
        invar_data_dim_idx2 = mod1(var_dim_idx + 2, 3)

        for idx = 1 : 9
            line_idx1, line_idx2 = fldmod1(idx, 3)
            invar_val1 = scal_uniq_var_vals[invar_data_dim_idx1][line_idx1]
            invar_val2 = scal_uniq_var_vals[invar_data_dim_idx2][line_idx2]

            # Plot function takes in order x>y>z so use line_data index to keep track
            line_data[var_dim_idx] = scal_uniq_var_vals[var_dim_idx]
            line_data[invar_data_dim_idx1] = fill(invar_val1, 3)
            line_data[invar_data_dim_idx2] = fill(invar_val2, 3)

            scatterlines!(
                lscene,
                line_data[1], line_data[2], line_data[3],
                color = :black,
                markercolor = :white,
                markersize = markersize,
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


function create_table(fig, parent, df, ax = nothing)
    nr = nrow(df)
    nc = ncol(df)
    N = nr * nc
    if isnothing(ax)
        ax = parent = Axis(
            parent,
            # title = "Data",
            yreversed = true,
        )
    end
    sort!(df, 1) # TODO: Sort by first column or "No_" for test number?
    data = string.(reshape(Matrix{Float64}(df), N))
    pos = reshape([Point2(j, i) for i = 1 : nr, j = 1 : nc], N)
    txt = text!(
        ax,
        data,
        position = pos,
        align = (:center, :center),
        justification = :center,
        # textsize = 1,
        space = :screen,
    )
    txtitles = text!(
        ax,
        names(df),
        position = [Point2(i, 0.) for i = 1 : nc],
        align = (:center, :center),
        justification = :center,
        # textsize = 1,
        space = :screen,
    )
    hidedecorations!(ax)
    ax, txt, txtitles
end


function create_plots(fig, lscene, df, titles, title_resp, titles_vars, titles_resps, num_vars, num_resps, cm, CONFIG)
    resp = df[!, title_resp]

    # Sort to correctly map colors to points in create_points_coords() and for general convenience
    sort!(df, title_resp)

    x = df[!, titles_vars[1]]
    y = df[!, titles_vars[2]]
    z = df[!, titles_vars[3]]
    
    # The data is min-max scaled/unity-based normalized equidistant cube (orthogonal array)
    # "Real" 3D instead of isometric projection however

    interval_x, ext_x, scal_ext_x = get_interval_scales(x)
    interval_y, ext_y, scal_ext_y = get_interval_scales(y)
    interval_z, ext_z, scal_ext_z = get_interval_scales(z)

    scal_x = x / interval_x
    scal_y = y / interval_y
    scal_z = z / interval_z
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
    scal_uniq_var_vals = [uniq_var_vals[1] / interval_x,
                          uniq_var_vals[2] / interval_y,
                          uniq_var_vals[3] / interval_z]

    colors = AbstractPlotting.ColorSampler(to_colormap(cm), extrema(resp))

    create_grid(lscene, scal_uniq_var_vals, num_vars, scal_plot_unit, CONFIG["plot_3d_grid_markersize"])

    axis = lscene.scene[OldAxis]
    axis[:showaxis] = true # TODO: Necessary?

    plot_pts = create_points_coords(lscene, select(df, 1), resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors, CONFIG["plot_3d_markersize"])

    # Correct tick labels so that they show the original values instead of the scaled/normalized ones
    xticks!(lscene.scene, xtickrange = xtickrange, xticklabels = xticklabels)
    yticks!(lscene.scene, ytickrange = ytickrange, yticklabels = yticklabels)
    zticks!(lscene.scene, ztickrange = ztickrange, zticklabels = zticklabels)

    axis[:showgrid] = false
    # axis[:frame, :axiscolor] = :black
    axis[:ticks, :textcolor] = :black

    create_titles(lscene, axis, titles_vars)

    # scale!(lscene.scene, 1/interval_x, 1/interval_y, 1/interval_z)
    # axis[:scale] = [1/interval_x, 1/interval_y, 1/interval_z]

    plot_pts
end


curvef(x1, x2, x3, c1, c2, c3, intercept = 1; p1 = 1, p2 = 1, p3 = 1) = intercept + c1*x1^p1 + c2*x2^p2 + c3*x3^p3
curvef_lin(x, y, z, a, b, c, d) = curvef(x, y, z, b, c, d, a; p1 = 1, p2 = 1, p3 = 1)
# @. multimodel_lin(x, p) = curvef_lin(x[:, 1], x[:, 2], x[:, 3], p...)
# @. multimodel_lin(x, p) = 1 + (x[:, 1] * p[2]) + (x[:, 2] * p[3]) + (x[:, 3] * p[4])
# curvef_quad(x, y, z, a, b, c, d) = curvef(x, y, z, b, c, d, a; p1 = 2, p2 = 2, p3 = 2)
# @. multimodel_quad(x, p) = p[1] + (x[:, 1] * p[2])^2 + (x[:, 2] * p[3])^2 + (x[:, 3] * p[4])^2

function create_plot_regression(fig, parent, df, titles_vars, title_resp, pos_sub, variances, cm, ax = nothing)
    colors = to_colormap(cm, 3) # lower < middle < higher variance
    variances_colors = Dict(first.(variances) .=> colors)
    plots = Vector{AbstractPlotting.ScatterLines}(undef, 3)
    xs = 1 : 3
    if isnothing(ax)
        ax = parent[pos_sub[1], pos_sub[2]] = Axis(
            fig,
            title = "Mean average of $title_resp values\nper single variable value",
            xticks = xs,
        )
    end

    for (i, var_title) ∈ enumerate(titles_vars)
        df = sort(df, [var_title, title_resp])
        ys = df[!, title_resp]

        mids = ys[2:3:end]
        lows = ys[1:3:end]
        highs = ys[3:3:end]
        means = mean.(zip(mids, lows, highs))

        col = variances_colors[var_title]

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


# Interpolate data with linear range, create cartesian product and reshape for plotting
function interp_pairings(x, y, z, len, inner = false, outerval = 1, innerval = 0)
    len = max(3, isodd(len) ? len : len - 1)
    pairings =
        if inner
            mid = ceil(Int, len / 2)
            view(
                reshape(collect(Iterators.product(
                    deleteat!(collect(range(extrema(x)..., length = len)), mid-innerval:mid+innerval)[begin + outerval : end - outerval],
                    deleteat!(collect(range(extrema(y)..., length = len)), mid-innerval:mid+innerval)[begin + outerval : end - outerval],
                    deleteat!(collect(range(extrema(z)..., length = len)), mid-innerval:mid+innerval)[begin + outerval : end - outerval],
                )), (len - 2outerval - 2innerval - 1)^3, 1, 1),
            :, 1, 1)
        else
            view(
                reshape(collect(Iterators.product(
                    range(extrema(x)..., length = len),
                    range(extrema(y)..., length = len),
                    range(extrema(z)..., length = len),
                )), len^3, 1, 1),
            :, 1, 1)
        end
    first.(pairings), getindex.(pairings, 2), last.(pairings)
end


function loading_bar()
    # fig = Figure()
    display(Figure()) # Triggers built-in loading bar for some reason ¯\_(¬_¬)_/¯
    # fig
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


function create_reload_button(fig, parent, lscenes, tbl_ax, regr_axs, regr_grid_layout, pos_fig, pos_subs, pos_regr, cm, CONFIG; but_lab = "Reload", window_title = "Open CSV data file...")
    button = Button(
        parent,
        label = but_lab,
    )

    on(button.clicks) do n
        filename_data = open_dialog_native(window_title)
        println("$(button.label[]) -> $filename_data.")
        if isempty(filename_data) return end

        df, titles, vars, resps, num_vars, num_resps = read_data(filename_data)
        titles_vars = names(vars)
        titles_resps = names(resps)

        # menus = filter(x -> typeof(x) == Menu, fig.content)[1] # TODO: make sure deleting the *right* menu(s)
        # delete!(menus)
        # create_menus(fig, fig[1, 3:4], lscenes[1], df, vars, titles, titles_vars, titles_resps, num_vars, num_resps, pos_fig, cm) # TODO: better way to choose parent position
        loading_bar()
        reload_plot(fig, lscenes[1], df, titles, titles_resps[1], titles_vars, titles_resps, num_vars, num_resps, pos_fig, pos_subs[1], cm, CONFIG)
        reload_plot(fig, lscenes[2], df, titles, titles_resps[2], titles_vars, titles_resps, num_vars, num_resps, pos_fig, pos_subs[2], cm, CONFIG)
        reload_plot(fig, lscenes[3], df, titles, titles_resps[3], titles_vars, titles_resps, num_vars, num_resps, pos_fig, pos_subs[3], cm, CONFIG)
        reload_table(fig, df, tbl_ax)
        reload_regr(fig, regr_grid_layout, df, titles_vars, titles_resps[1], (pos_regr[1] + 0, pos_regr[2]), cm, regr_axs[1])
        reload_regr(fig, regr_grid_layout, df, titles_vars, titles_resps[2], (pos_regr[1] + 2, pos_regr[2]), cm, regr_axs[2])
        reload_regr(fig, regr_grid_layout, df, titles_vars, titles_resps[3], (pos_regr[1] + 4, pos_regr[2]), cm, regr_axs[3])

        display(fig) # TODO: display() should not be called in callback?
    end

    button
end


function create_cm_menu(fig, parent, splots, cbars, cm_sliders, cms; menu_prompt = "Select color palette...")
    menu = Menu(
        parent,
        options = vcat("Reverse current", cms),
        prompt = menu_prompt,
    )

    on(menu.selection) do sel
        println("Select colormap -> $sel.")
        for (splot, cbar, slider) in zip(splots, cbars, cm_sliders)
            ordered_resp = map(x -> parse(Float64, x[4:end]), splot[2].input_args[1].val)
            ext_resp = extrema(ordered_resp)
            lims = (min(slider.interval.val[1], ext_resp[1]), max(slider.interval.val[2], ext_resp[2]))
            if sel == "Reverse current" sel = Reverse(cbar.colormap[]) end

            splot[1].colormap = sel
            col_samp = AbstractPlotting.ColorSampler(to_colormap(sel), lims)
            splot[1].color = [col_samp[resp] for resp in ordered_resp]

            cbar.colormap = sel
            cbar.limits = lims
        end
    end

    menu
end


function create_cm_sliders(fig, parent, resp_df, resp_plot, cbar, pos_sub)
    scal, ext, _ = get_interval_scales(resp_df)

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


function reload_plot(fig, lscene, df, titles, title_resp, titles_vars, titles_resps, num_vars, num_resps, pos_fig, pos_sub, cm, CONFIG)
    # Delete previous plot objects
    empty!(lscene.scene.plots)
    # delete!(filter(x -> typeof(x) == LScene, fig.content)[1]) # Remake LScene instead of modify
    cbar = filter(x -> typeof(x) == Colorbar, fig.content)[1]
    delete!(cbar)

    plots_gridlayout = content(fig[pos_fig...])
    lscene.title.val = title_resp
    plot_new = create_plots(fig, lscene, df, titles, title_resp, titles_vars, titles_resps, num_vars, num_resps, cm, CONFIG["plot_3d_markersize"])
    plots_gridlayout[pos_sub...] = lscene
    plots_gridlayout[pos_sub[1], pos_sub[2] + 1] = create_colorbar(fig, fig[pos_fig...], select(df, title_resp), title_resp, cm)
end


function reload_table(fig, df, ax)
    empty!(ax)
    create_table(fig, fig, df, ax)
end


function reload_regr(fig, grid_layout, df, titles_vars, title_resp, pos_reg_anchor, cm, ax)
    ax.title = "Mean average of $title_resp values\nper single variable value"
    empty!(ax)
    fm = @eval @formula($(Symbol(title_resp)) ~ $(Symbol(titles_vars[1])) + $(Symbol(titles_vars[2])) + $(Symbol(titles_vars[3])))
    model_ols = lm(fm, df)
    variances = sort!(deleteat!(coefnames(model_ols) .=> diag(vcov(model_ols)), 1), by = x -> abs(x.second))
    create_plot_regression(fig, grid_layout, df, titles_vars, title_resp, pos_reg_anchor, variances, cm, ax)
end


function setup(df, titles, vars, resps, num_vars, num_resps, filename_data, cm, CONFIG, LOCALE_TR)
    titles_vars = names(vars)
    titles_resps = names(resps)
    filename_save = string("$(@__DIR__)/../res/", replace("$(now()) $(join(vcat(titles_vars, titles_resps), '-')).png", r"[^a-zA-Z0-9_\-\.]" => '_'))
    pos_fig = (2, 1:4)
    cms = [:RdYlGn_4, :RdYlGn_6, :RdYlGn_8, :RdYlGn_10, :redgreensplit, :diverging_gwr_55_95_c38_n256, :watermelon, :cividis]
    if cm ∉ cms pushfirst!(cms, cm) end
    cm_variances = Symbol(CONFIG["colormap_variance_comparison"])
    cm_regr3d = Symbol(CONFIG["colormap_3d_regression"])

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
    pos_plots = [(1, 1), (1, 3), (4, 1)]

    lscene1 = basic_ls(main_fig, pos_fig, title)
    plot1 = create_plots(main_fig, lscene1, df, titles, titles_resps[1], titles_vars, titles_resps, num_vars, num_resps, cm, CONFIG)
    plot_sublayout[pos_plots[1]...] = lscene1
    cbar1 = plot_sublayout[pos_plots[1][1], pos_plots[1][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 1), titles_resps[1], cm)

    lscene2 = basic_ls(main_fig, pos_fig, title)
    plot2 = create_plots(main_fig, lscene2, df, titles, titles_resps[2], titles_vars, titles_resps, num_vars, num_resps, cm, CONFIG)
    plot_sublayout[pos_plots[2]...] = lscene2
    cbar2 = plot_sublayout[pos_plots[2][1], pos_plots[2][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 2), titles_resps[2], cm)

    lscene_main = basic_ls(main_fig, pos_fig, title)
    plot_main = create_plots(main_fig, lscene_main, df, titles, titles_resps[3], titles_vars, titles_resps, num_vars, num_resps, cm, CONFIG)
    plot_sublayout[pos_plots[3]...] = lscene_main
    cbar_main = plot_sublayout[pos_plots[3][1], pos_plots[3][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 3), titles_resps[3], cm)
    cam_main = cameracontrols(lscene_main.scene)
    # cam_main = cam3d!(lscene_main.scene)

    lscene1.scene.camera = lscene_main.scene.camera
    lscene2.scene.camera = lscene_main.scene.camera
    lscene1.scene.camera_controls[] = cam_main
    lscene2.scene.camera_controls[] = cam_main

    lscenes = [lscene1, lscene2, lscene_main]

    cm_slider1, cm_slider_lab1 = create_cm_sliders(main_fig, plot_sublayout, resps[!, 1], plot1, cbar1, (2, 1:2))
    cm_slider2, cm_slider_lab2 = create_cm_sliders(main_fig, plot_sublayout, resps[!, 2], plot2, cbar2, (2, 3:4))
    cm_slider_main, cm_slider_lab_main = create_cm_sliders(main_fig, plot_sublayout, resps[!, 3], plot_main, cbar_main, (5, 1:2))

    @info "Creating data table..."
    tbl_ax, tbl_txt, tbl_titles = create_table(main_fig, main_fig, df)
    plot_sublayout[4:6, 3:4] = tbl_ax

    @info "Creating regressions and interpolations..."
    sym_var1 = Symbol(titles_vars[1])
    sym_var2 = Symbol(titles_vars[2])
    sym_var3 = Symbol(titles_vars[3])
    fm1 = @eval @formula($(Symbol(titles_resps[1])) ~ $sym_var1 + $sym_var2 + $sym_var3)
    fm2 = @eval @formula($(Symbol(titles_resps[2])) ~ $sym_var1 + $sym_var2 + $sym_var3)
    fm3 = @eval @formula($(Symbol(titles_resps[3])) ~ $sym_var1 + $sym_var2 + $sym_var3)
    model_ols1 = lm(fm1, df)
    model_ols2 = lm(fm2, df)
    model_ols3 = lm(fm3, df)
    get_abs_sec(x) = abs(x.second)
    variances1 = sort!(deleteat!(coefnames(model_ols1) .=> diag(vcov(model_ols1)), 1), by = get_abs_sec)
    variances2 = sort!(deleteat!(coefnames(model_ols2) .=> diag(vcov(model_ols2)), 1), by = get_abs_sec)
    variances3 = sort!(deleteat!(coefnames(model_ols3) .=> diag(vcov(model_ols3)), 1), by = get_abs_sec)

    resolution = markersize, density = CONFIG["plot_3d_regression_markersize"], CONFIG["plot_3d_regression_density"]
    marker = :rect
    var1, var2, var3 = eachcol(vars)
    x̂, ŷ, ẑ = interp_pairings(var1, var2, var3, 3 + 2 * density, true, CONFIG["plot_3d_regression_outer_cut"], CONFIG["plot_3d_regression_inner_cut"])
    xrange, yrange, zrange = calc_interval(var1), calc_interval(var2), calc_interval(var3)
    scal_x̂, scal_ŷ, scal_ẑ = x̂ / xrange, ŷ / yrange, ẑ / zrange

    @info "Creating comparison plots..."
    regress_sublayout = main_fig[1:pos_fig[1], pos_fig[2][end] + 1] = GridLayout()
    pos_reg_cbar = (1, 1)
    pos_reg_anchor = (3, 1)
    regr1 = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[1], (pos_reg_anchor[1] + 0, pos_reg_anchor[2]), variances1, cm_variances)
    regr2 = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[2], (pos_reg_anchor[1] + 2, pos_reg_anchor[2]), variances2, cm_variances)
    regr3 = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[3], (pos_reg_anchor[1] + 4, pos_reg_anchor[2]), variances3, cm_variances)
    regress_sublayout[pos_reg_anchor[1] + 0, pos_reg_anchor[2]] = regr1
    regress_sublayout[pos_reg_anchor[1] + 2, pos_reg_anchor[2]] = regr2
    regress_sublayout[pos_reg_anchor[1] + 4, pos_reg_anchor[2]] = regr3
    cbar_regr = regress_sublayout[pos_reg_cbar...] = Colorbar(
        main_fig,
        label = LOCALE_TR["cbar_regr_lab"],
        limits = (1, 3),
        colormap = cgrad(cm_variances, 3, categorical = true),
        vertical = false,
        labelpadding = 5.,
        ticksize = 0.,
        ticklabelsvisible = false,
    )
    cbar_regr_labs = regress_sublayout[pos_reg_cbar[1] + 1, pos_reg_cbar[2]] = grid!(permutedims(hcat([Label(main_fig, lab, tellwidth = false) for lab in LOCALE_TR["cbar_regr_labs"]])))
    rowsize!(regress_sublayout, pos_reg_cbar[1], Relative(.03)) # For colorbar
    rowsize!(regress_sublayout, pos_reg_cbar[1] + 1, Relative(.001)) # For colorbar labels

    @info "Creating new generated points..."
    resp1 = df[!, titles_resps[1]]
    resp2 = df[!, titles_resps[2]]
    resp_main = df[!, titles_resps[3]]
    resp_pred1 = curvef_lin.(x̂, ŷ, ẑ, coef(model_ols1)...)
    resp_pred2 = curvef_lin.(x̂, ŷ, ẑ, coef(model_ols2)...)
    resp_pred3 = curvef_lin.(x̂, ŷ, ẑ, coef(model_ols3)...)
    plot_regr3d_1 = create_plot3(lscene1, resp_pred1, scal_x̂, scal_ŷ, scal_ẑ, AbstractPlotting.ColorSampler(to_colormap(cm_regr3d), extrema(resp_pred1)); marker = marker, markersize = markersize)
    plot_regr3d_2 = create_plot3(lscene2, resp_pred2, scal_x̂, scal_ŷ, scal_ẑ, AbstractPlotting.ColorSampler(to_colormap(cm_regr3d), extrema(resp2)); marker = marker, markersize = markersize)
    plot_regr3d_main = create_plot3(lscene_main, resp_pred3, scal_x̂, scal_ŷ, scal_ẑ, AbstractPlotting.ColorSampler(to_colormap(cm_regr3d), extrema(resp_main)); marker = marker, markersize = markersize)

    @info "Creating other widgets..."
    save_button = create_save_button(main_fig, main_fig[1, 1], filename_save; but_lab = LOCALE_TR["save_but_lab"])
    reload_button = create_reload_button(main_fig, main_fig[1, 2], lscenes, tbl_ax, [regr1, regr2, regr3], regress_sublayout, pos_fig, pos_plots, pos_reg_anchor, cm, CONFIG; but_lab = LOCALE_TR["reload_but_lab"], window_title = LOCALE_TR["file_dialog_window_title"])
    cm_menu = create_cm_menu(main_fig, main_fig, [plot1, plot2, plot_main], [cbar1, cbar2, cbar_main], [cm_slider1, cm_slider2, cm_slider_main], cms; menu_prompt = LOCALE_TR["cm_menu_prompt"])
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


# function __init__()
#     PREFIX = "$(@__DIR__)/../"
#     filename_config = PREFIX * "cfg/config.json"
#     CONFIG::Dict{String, Union{String, Number}} = parsefile(filename_config, dicttype = Dict{String, Union{String, Number}})
#     filename_db = PREFIX * CONFIG["db_path"]
#     filename_locale = PREFIX * CONFIG["locale_path"] * CONFIG["locale"] * ".json"
#     cm::Symbol = Symbol(CONFIG["default_colormap"])

#     LOCALE_TR::Dict{String, Union{String, AbstractArray{Any, 1}}} = parsefile(filename_locale, dicttype = Dict{String, Union{String, AbstractArray{Any, 1}}})

#     filename_data::String = isempty(CONFIG["data_path"]) ?
#                             open_dialog_native(LOCALE_TR["file_dialog_window_title"]) :
#                             PREFIX * CONFIG["data_path"]

#     if isempty(filename_db)
#         exit("No database file found. Exiting...")
#     elseif isempty(filename_data) # If empty data file path in config.json
#         filename_data = find_csv("$(@__DIR__)/../res") # or TSV
#     end

#     # TODO: Implement
#     if isempty(filename_data) # If still no CSV data file path in /res/ directory
#         # db = DOEVDBManager.setup(filename_db, "HEAT_TREATMENT_DATA_2")
#         # query = """
#         #     SELECT *
#         #     FROM $tablename;
#         # """
#         # df = get_data(db, query)
#         @error "NOT IMPLEMENTED YET: Get data from DB when no CSV file"
#         exit(1)
#     else
#         df, titles, vars, resps, num_vars, num_resps = read_data(filename_data)
#         # db = DOEVDBManager.setup(filename_db, splitext(basename(filename_data))[1], df)
#         println("Loaded $filename_data")
#     end
#     # display(df_test)

#     @info "Setting up interface and plots..."
#     setup(df, titles, vars, resps, num_vars, num_resps, filename_data, cm, CONFIG, LOCALE_TR)
# end


end
