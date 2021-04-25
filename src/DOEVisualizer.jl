module DOEVisualizer


@info "Loading libraries..."

using Statistics, LinearAlgebra
using DataFrames
using GLMakie, AbstractPlotting
using GLM#, MultivariateStats, LsqFit
# using Polynomials, OnlineStats, Grassmann, Optim, Interpolations, GridInterpolations, Combinatorics, IterativeSolvers

import Gtk: open_dialog, open_dialog_native, save_dialog, save_dialog_native, Null, GtkNullContainer, GtkFileFilter


@info "Loading functions..."

abstract type AbstractDoE end

mutable struct DoePlot <: AbstractDoE
    lscene::AbstractPlotting.MakieLayout.LScene
    ptsVars::Array
    ptsResp::Vector{Real}
    scPlot::Union{AbstractPlotting.FigureAxisPlot, AbstractPlotting.Scatter}
    scAnnot::Union{AbstractPlotting.FigureAxisPlot, AbstractPlotting.Annotations}
    # scGrid::AbstractPlotting.ScatterLines
    regrModel::Union{StatsModels.TableRegressionModel, LinearModel, Vector, Matrix}
    regrInterpVarsPts::Array
    regrInterpRespPts::Vector{Real}
    regrPlot::Union{AbstractPlotting.FigureAxisPlot, AbstractPlotting.Scatter}
    cbar::AbstractPlotting.MakieLayout.Colorbar
    cm::Union{Symbol, String}
    gridPos::Union{Tuple, CartesianIndex}
    DoePlot() = new()
end


function peek(thing)
    println(fieldnames(typeof(thing)))
    println(thing)
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
        # strokecolor = sampled_colors,
        strokewidth = 0.,
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


function create_plots(fig, lscene, df, titles, title_resp, titles_vars, titles_resps, num_vars, num_resps, cm, doeplot, CONFIG)
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

    doeplot.scPlot = plot_pts[1]
    doeplot.scAnnot = plot_pts[2]
    doeplot.ptsVars = [x y z]
    doeplot.ptsResp = resp
    doeplot.cm = cm

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

get_abs_sec(x) = abs(x.second)

function create_plot_regression(fig, parent, df, titles_vars, title_resp, pos_sub, model, cm, ax = nothing)
    colors = to_colormap(cm, 3) # lower < middle < higher variance
    all_means = Vector{Vector{Float32}}(undef, 3)
    intervals = Vector{Float32}(undef, 3)
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
        all_means[i] = means
        intervals[i] = calc_interval(means)

        eb = errorbars!(
            ax,
            xs .+ .05 * i, mids, mids - lows, highs - mids,
            color = :black,
        )
    end
    ordered_colors = last.(sort(first.(sort(1:3 .=> intervals, by = last)) .=> colors, by = first))
    for i = 1 : 3
        sc = plots[i] = scatterlines!(
            ax,
            xs .+ .05 * i, all_means[i],
            color = ordered_colors[i],
            markercolor = ordered_colors[i],
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


function create_save_button(fig, parent, filename_save; but_lab = "Save")
    button = Button(
        parent,
        label = but_lab,
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename_save.")
        # filename = save_dialog_native(but_lab, Null(), (GtkFileFilter(mimetype = "text/csv"), GtkFileFilter(mimetype = "text/tsv")))
        filename = save_dialog_native(but_lab, GtkNullContainer(), ("*.csv", "*.tsv", "*"))
        fig.scene.center = false
        save(isempty(filename) ? filename_save : filename, fig.scene)
        fig.scene.center = true
        display(fig) # TODO: display() should not be called in callback?
    end

    button
end


function create_cm_menu(fig, parent, doeplots, cm_sliders, cms; menu_prompt = "Select color palette...")
    menu = Menu(
        parent,
        options = vcat("Reverse current", cms),
        prompt = menu_prompt,
    )

    on(menu.selection) do cm
        println("Select colormap -> $cm.")
        for (slider, doeplot) in zip(cm_sliders, doeplots)
            ordered_resp = doeplot.ptsResp
            ordered_resp_pred = doeplot.regrInterpRespPts
            ext_resp = extrema(ordered_resp)
            lims = (min(slider.interval.val[1], ext_resp[1]), max(slider.interval.val[2], ext_resp[2]))
            if cm == "Reverse current" cm = Reverse(doeplot.cm) end
            doeplot.cm = cm

            doeplot.scPlot.attributes.colormap = cm
            doeplot.regrPlot.attributes.colormap = cm
            col_samp = AbstractPlotting.ColorSampler(to_colormap(cm), lims)
            doeplot.scPlot.attributes.color = [col_samp[resp] for resp in ordered_resp]
            doeplot.regrPlot.attributes.color = [col_samp[resp] for resp in ordered_resp_pred]

            doeplot.cbar.colormap = cm
            doeplot.cbar.limits = lims
        end
    end

    menu
end


function create_cm_sliders(fig, parent, doeplot, resp_range_limits, pos_sub, slider_precision = .01)
    scal, ext, _ = get_interval_scales(doeplot.ptsResp)
    slider_min = isnothing(resp_range_limits[1]) ? ext[1] - scal : min(resp_range_limits[1], ext[1])
    slider_max = isnothing(resp_range_limits[2]) ? ext[2] + scal : max(resp_range_limits[2], ext[2])

    slider = parent[pos_sub...] = IntervalSlider(
        fig,
        range = slider_min : slider_precision : slider_max,
        startvalues = ext,#(slider_min, slider_max),
    )

    slider_lab = parent[pos_sub[1] + 1, pos_sub[2]] = Label(
        fig,
        @lift(string(round.($(slider.interval), digits = 2))),
        tellwidth = false,
    )

    on(slider.interval) do interval
        ordered_resp = doeplot.ptsResp
        ordered_resp_pred = doeplot.regrInterpRespPts
        ext = extrema(ordered_resp)
        lims = (min(slider.interval.val[1], ext[1]), max(slider.interval.val[2], ext[2]))

        cm = doeplot.cm
        doeplot.scPlot.attributes.colormap = cm
        doeplot.regrPlot.attributes.colormap = cm
        col_samp = AbstractPlotting.ColorSampler(to_colormap(cm), lims)
        doeplot.scPlot.attributes.color = [col_samp[resp] for resp in ordered_resp]
        doeplot.regrPlot.attributes.color = [col_samp[resp] for resp in ordered_resp_pred]

        doeplot.cbar.limits = lims
    end

    slider, slider_lab
end


function setup(df, titles, vars, resps, num_vars, num_resps, filename_save, cm, CONFIG, LOCALE_TR)
    titles_vars = names(vars)
    titles_resps = names(resps)
    pos_fig = (2, 1:4)
    cms = [:RdYlGn_4, :RdYlGn_6, :RdYlGn_8, :RdYlGn_10, :redgreensplit, :diverging_gwr_55_95_c38_n256, :watermelon, :cividis]
    if cm ∉ cms pushfirst!(cms, cm) end
    cm_variances = Symbol(CONFIG["colormap_variance_comparison"])
    cm_regr3d = Symbol(CONFIG["colormap_3d_regression"])
    resp_range_limits = CONFIG["resp_range_limits"]

    doeplot1 = DoePlot()
    doeplot2 = DoePlot()
    doeplot3 = DoePlot()

    doeplot1.gridPos = doeplot2.gridPos = doeplot3.gridPos = pos_fig

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

    lscene1 = doeplot1.lscene =  basic_ls(main_fig, pos_fig, title)
    plot1 = create_plots(main_fig, lscene1, df, titles, titles_resps[1], titles_vars, titles_resps, num_vars, num_resps, cm, doeplot1, CONFIG)
    plot_sublayout[pos_plots[1]...] = lscene1
    cbar1 = doeplot1.cbar = plot_sublayout[pos_plots[1][1], pos_plots[1][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 1), titles_resps[1], cm)
    # cam1 = lscene1.scene.camera
    
    lscene2 = doeplot2.lscene =  basic_ls(main_fig, pos_fig, title)
    plot2 = create_plots(main_fig, lscene2, df, titles, titles_resps[2], titles_vars, titles_resps, num_vars, num_resps, cm, doeplot2, CONFIG)
    plot_sublayout[pos_plots[2]...] = lscene2
    cbar2 = doeplot2.cbar = plot_sublayout[pos_plots[2][1], pos_plots[2][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 2), titles_resps[2], cm)
    # cam2 = lscene2.scene.camera

    lscene3 = doeplot3.lscene =  basic_ls(main_fig, pos_fig, title)
    plot3 = create_plots(main_fig, lscene3, df, titles, titles_resps[3], titles_vars, titles_resps, num_vars, num_resps, cm, doeplot3, CONFIG)
    plot_sublayout[pos_plots[3]...] = lscene3
    cbar3 = doeplot3.cbar = plot_sublayout[pos_plots[3][1], pos_plots[3][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 3), titles_resps[3], cm)
    # cam3 = lscene3.scene.camera

    camc3 = cameracontrols(lscene3.scene)#cam3d!(lscene3.scene)
    lscene1.scene.camera = lscene3.scene.camera
    lscene2.scene.camera = lscene3.scene.camera
    lscene1.scene.camera_controls[] = camc3
    lscene2.scene.camera_controls[] = camc3

    lscenes = [lscene1, lscene2, lscene3]

    @info "Creating data table..."
    tbl_ax, tbl_txt, tbl_titles = create_table(main_fig, main_fig, df)
    plot_sublayout[4:6, 3:4] = tbl_ax

    @info "Performing regressions..."
    sym_var1 = Symbol(titles_vars[1])
    sym_var2 = Symbol(titles_vars[2])
    sym_var3 = Symbol(titles_vars[3])
    sym_resp1 = Symbol(titles_resps[1])
    sym_resp2 = Symbol(titles_resps[2])
    sym_resp3 = Symbol(titles_resps[3])
    fm1 = @eval @formula($sym_resp1 ~ $sym_var1 + $sym_var2 + $sym_var3)
    fm2 = @eval @formula($sym_resp2 ~ $sym_var1 + $sym_var2 + $sym_var3)
    fm3 = @eval @formula($sym_resp3 ~ $sym_var1 + $sym_var2 + $sym_var3)
    model_ols1 = lm(fm1, df)
    model_ols2 = lm(fm2, df)
    model_ols3 = lm(fm3, df)
    doeplot1.regrModel = model_ols1
    doeplot2.regrModel = model_ols2
    doeplot3.regrModel = model_ols3

    resolution = markersize, density = CONFIG["plot_3d_regression_markersize"], CONFIG["plot_3d_regression_density"]
    outercut = CONFIG["plot_3d_regression_outer_cut"]
    innercut = CONFIG["plot_3d_regression_inner_cut"]
    marker = :rect
    var1, var2, var3 = eachcol(vars)
    x̂, ŷ, ẑ = interp_pairings(var1, var2, var3, 3 + 2 * density, true, outercut, innercut)
    xrange, yrange, zrange = calc_interval(var1), calc_interval(var2), calc_interval(var3)
    scal_x̂, scal_ŷ, scal_ẑ = x̂ / xrange, ŷ / yrange, ẑ / zrange

    @info "Generating comparison plots..."
    regress_sublayout = main_fig[1:pos_fig[1], pos_fig[2][end] + 1] = GridLayout()
    pos_reg_cbar = (1, 1)
    pos_reg_anchor = (3, 1)
    regr1 = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[1], (pos_reg_anchor[1] + 0, pos_reg_anchor[2]), model_ols1, cm_variances)
    regr2 = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[2], (pos_reg_anchor[1] + 2, pos_reg_anchor[2]), model_ols2, cm_variances)
    regr3 = create_plot_regression(main_fig, regress_sublayout, df, titles_vars, titles_resps[3], (pos_reg_anchor[1] + 4, pos_reg_anchor[2]), model_ols3, cm_variances)
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

    @info "Interpolating new points and computing predicted responses..."
    resp1 = df[!, titles_resps[1]]
    resp2 = df[!, titles_resps[2]]
    resp3 = df[!, titles_resps[3]]
    resp_pred1 = curvef_lin.(x̂, ŷ, ẑ, coef(model_ols1)...)
    resp_pred2 = curvef_lin.(x̂, ŷ, ẑ, coef(model_ols2)...)
    resp_pred3 = curvef_lin.(x̂, ŷ, ẑ, coef(model_ols3)...)
    plot_regr3d_1 = create_plot3(lscene1, resp_pred1, scal_x̂, scal_ŷ, scal_ẑ, AbstractPlotting.ColorSampler(to_colormap(cm_regr3d), extrema(resp_pred1)); marker = marker, markersize = markersize)
    plot_regr3d_2 = create_plot3(lscene2, resp_pred2, scal_x̂, scal_ŷ, scal_ẑ, AbstractPlotting.ColorSampler(to_colormap(cm_regr3d), extrema(resp2)); marker = marker, markersize = markersize)
    plot_regr3d_3 = create_plot3(lscene3, resp_pred3, scal_x̂, scal_ŷ, scal_ẑ, AbstractPlotting.ColorSampler(to_colormap(cm_regr3d), extrema(resp3)); marker = marker, markersize = markersize)

    doeplot1.regrInterpVarsPts = doeplot2.regrInterpVarsPts = doeplot3.regrInterpVarsPts = [x̂ ŷ ẑ]
    doeplot1.regrInterpRespPts = resp_pred1
    doeplot2.regrInterpRespPts = resp_pred2
    doeplot3.regrInterpRespPts = resp_pred3
    doeplot1.regrPlot = plot_regr3d_1
    doeplot2.regrPlot = plot_regr3d_2
    doeplot3.regrPlot = plot_regr3d_3

    @info "Creating other widgets..."

    save_button = create_save_button(main_fig, main_fig[1, 1], filename_save; but_lab = LOCALE_TR["save_but_lab"])

    cm_slider1, cm_slider_lab1 = create_cm_sliders(main_fig, plot_sublayout, doeplot1, resp_range_limits[1], (2, 1:2), CONFIG["slider_precision"])
    cm_slider2, cm_slider_lab2 = create_cm_sliders(main_fig, plot_sublayout, doeplot2, resp_range_limits[2], (2, 3:4), CONFIG["slider_precision"])
    cm_slider3, cm_slider_lab3 = create_cm_sliders(main_fig, plot_sublayout, doeplot3, resp_range_limits[3], (5, 1:2), CONFIG["slider_precision"])
    cm_menu = create_cm_menu(main_fig, main_fig, [doeplot1, doeplot2, doeplot3], [cm_slider1, cm_slider2, cm_slider3], cms; menu_prompt = LOCALE_TR["cm_menu_prompt"])

    button_sublayout = main_fig[1, 1:4] = grid!(hcat(save_button, cm_menu))

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


end
