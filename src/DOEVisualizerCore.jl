module DOEVisualizerCore


@info "Loading libraries..."

using Statistics, LinearAlgebra
using Parameters, DataFrames
using GLMakie
using GLM, LsqFit, MultivariateStats
# using MultivariatePolynomials, Optim, IterativeSolvers, GaussianProcess, OnlineStats
# using Interpolations, GridInterpolations
# using Combinatorics, Grassmann
import Gtk: save_dialog_native
# import GLMakie.Makie: show_data

# using IOLogging, LoggingExtras


@info "Loading functions..."

abstract type AbstractDoE end

mutable struct DoePlot <: AbstractDoE
    lscene::Makie.LScene
    ptsVars::Matrix{Real}
    ptsResp::Vector{Real}
    scPlot::Union{Makie.FigureAxisPlot, Makie.Scatter}
    scAnnot::Union{Makie.FigureAxisPlot, Makie.Annotations}
    regrModel::Union{StatisticalModel, LsqFit.LsqFitResult, Array}
    regrInterpVarsPts::Matrix{Real}
    regrInterpRespPts::Vector{Real}
    regrPlot::Union{Makie.FigureAxisPlot, Makie.ScenePlot}
    cbar::Makie.Colorbar
    cm::Union{Symbol, String, Makie.Reverse}
    gridPos::Union{Tuple, CartesianIndex}
    DoePlot() = new()
end


peek(thing) = println("FIELDNAMES : $(fieldnames(typeof(thing)))")#\nTHING : $thing")

calc_interval(a) = abs(-(extrema(a)...)) # TODO

get_interval_scales(a) = calc_interval(a), extrema(a) # For min-max scaling/unity-based normalization

create_titles(lscene, axis, titles) = axis[:names, :axisnames] = replace.((titles[1], titles[2], titles[3]), "_" => " ")

multimodel_lin(x1, x2, x3, c0, c1, c2, c3) = c0 + c1*x1 + c2*x2 + c3*x3
@. multimodel_lin(x, p) = multimodel_lin(x[:, 1], x[:, 2], x[:, 3], p...)
@. multimodel_quad(x, p) = p[1] + (x[:, 1]   * p[2]) + (x[:, 2]   * p[3]) + (x[:, 3]   * p[4]) +
                                  (x[:, 1]^2 * p[5]) + (x[:, 2]^2 * p[6]) + (x[:, 3]^2 * p[7]) +
                                  (x[:, 1] * x[:, 2] * p[8]) + (x[:, 1] * x[:, 3] * p[9]) + (x[:, 2] * x[:, 3] * p[10])
@. multimodel_quad_no_interact(x, p) = p[1] + (x[:, 1]   * p[2]) + (x[:, 2]   * p[3]) + (x[:, 3]   * p[4]) +
                                              (x[:, 1]^2 * p[5]) + (x[:, 2]^2 * p[6]) + (x[:, 3]^2 * p[7])

tss(glmodel::StatisticalModel) = sum(abs2, glmodel.model.rr.y .- mean(glmodel.model.rr.y))#model.mf.data.y)
ess(glmodel::StatisticalModel) = sum(abs2, predict(glmodel) .- mean(glmodel.model.rr.y))#model.mf.data.y)
tss(ys) = sum(abs2, ys .- mean(ys))
ess(ys, ŷs) = sum(abs2, ŷs .- mean(ys))
r_squared(model::LsqFit.LsqFitResult, ys) = 1 - rss(model) / tss(ys)
vif(glmodel::StatisticalModel) = inv(1 - r²(glmodel))
vif(model::LsqFit.LsqFitResult, ys) = inv(1 - r_squared(model, ys))
vif(model, ys) = inv(rss(model) / tss(ys))
vifm(X) = diag(inv(cor(X[:, 2 : end])))
vif_GLM(glmodel::StatisticalModel) = diag(inv(cor(glmodel.model.pp.X[:, 2 : end])))


function create_plot3(lscene, resp, scal_x, scal_y, scal_z, title_resp, colors, col_lims; marker = :circle, markersize = 80)
    n = length(resp)
    scal_xyz = Array{Point3, 1}(undef, n)
    sampled_colors = Array{RGBf, 1}(undef, n)

    for i = 1 : n
        scal_xyz[i] = Point3(scal_x[i], scal_y[i], scal_z[i])
        sampled_colors[i] = Makie.interpolated_getindex(colors, resp[i], col_lims)
    end

    splot3 = scatter!(
        lscene,
        scal_x, scal_y, scal_z,
        marker = marker,
        markersize = markersize,
        color = sampled_colors,
        # strokecolor = sampled_colors,
        strokewidth = 0.,
        label = title_resp,
        show_axis = true,
    )
    splot3[1][] = scal_xyz # Re-order points by re-inserting with their sorted order to match colours

    splot3
end

# Draw points and coordinates
function create_points_coords(lscene, test_nums, resp, title_resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors, markersize = 50)
    n = nrow(test_nums)
    scal_xyz = Array{Point3, 1}(undef, n)
    text_xyz = Array{String, 1}(undef, n)
    pos_xyz = Array{Point3, 1}(undef, n)
    sampled_colors = Array{RGBf, 1}(undef, n)
    col_lims = extrema(resp)

    for i = 1 : n
        scal_xyz[i] = Point3(scal_x[i], scal_y[i], scal_z[i])
        text_xyz[i] = "#$(test_nums[i, 1])\n$(resp[i])"
        pos_xyz[i] = Point3(scal_x[i], scal_y[i], scal_z[i] + .03 * scal_plot_unit)
        sampled_colors[i] = Makie.interpolated_getindex(colors, resp[i], col_lims)
    end

    splot = scatter!(
        lscene,
        scal_x, scal_y, scal_z,
        marker = :circle,
        markersize = markersize,
        color = sampled_colors,
        label = title_resp,
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
        space = :data,
        overdraw = false,
        visible = true,
        show_axis = true,
    )

    splot, txtplot
end


# Draw grid
function create_grid(lscene, scal_uniq_var_vals, title_resp, num_vars, scal_plot_unit, markersize = 45)
    grid_plots = Matrix{Makie.ScatterLines}(undef, 3, 9)
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

            grid_plots[var_dim_idx, idx] = scatterlines!(
                lscene,
                line_data[1], line_data[2], line_data[3],
                color = :black,
                markercolor = :white,
                markersize = markersize,
                label = title_resp,
                show_axis = true,
                # inspectable = false,
            )
        end
    end

    grid_plots
end


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
    for i in 1:nr
        data[i] = "#" * replace(data[i], ".0" => "")
    end
    pos = reshape([Point2(j, i) for i = 1 : nr, j = 1 : nc], N)
    txt = text!(
        ax,
        data,
        position = pos,
        align = (:center, :center),
        justification = :center,
        space = :data,
    )
    txtitles = text!(
        ax,
        names(df),
        position = [Point2(i, 0.) for i = 1 : nc],
        align = (:center, :center),
        justification = :center,
        space = :data,
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

    interval_x, ext_x = get_interval_scales(x)
    interval_y, ext_y = get_interval_scales(y)
    interval_z, ext_z = get_interval_scales(z)
    scal_ext_x = ext_x ./ interval_x
    scal_ext_y = ext_y ./ interval_y
    scal_ext_z = ext_z ./ interval_z

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

    colors = to_colormap(cm)

    plot_grids = create_grid(lscene, scal_uniq_var_vals, title_resp, num_vars, scal_plot_unit, CONFIG["plot_3d_grid_markersize"])

    axis = lscene.scene[OldAxis]
    axis[:showaxis] = true # TODO: Necessary?

    plot_pts = create_points_coords(lscene, select(df, 1), resp, title_resp, x, y, z, scal_x, scal_y, scal_z, scal_plot_unit, colors, CONFIG["plot_3d_markersize"])

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

    plot_pts, plot_grids
end


function create_comparison_plot(fig, parent, df, titles_vars, title_resp, pos_sub, model, cm, ax = nothing)
    colors = categorical_colors(cm, 3) # lower < middle < higher variance
    all_means = Vector{Vector{Float32}}(undef, 3)
    intervals = Vector{Float32}(undef, 3)
    plots = Vector{Makie.ScatterLines}(undef, 3)
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
function interp_pairings(x, y, z, len)
    len = max(3, isodd(len) ? len : len - 1)
    pairings =
        view(
            reshape(collect(Iterators.product(
                range(extrema(x)..., length = len),
                range(extrema(y)..., length = len),
                range(extrema(z)..., length = len),
            )), len^3, 1, 1),
        :, 1, 1)
    first.(pairings), getindex.(pairings, 2), last.(pairings)
end

# For "carving/slicing out" the outer or inner sides of the cube
function interp_pairings(x, y, z, len, outercut, innercut)
    len = max(3, isodd(len) ? len : len - 1)
    mid = trunc(Int, middle(1, len - 2outercut))
    pairings =
        view(
            reshape(collect(Iterators.product(
                deleteat!(collect(range(extrema(x)..., length = len)[1 + outercut : len - outercut]), mid - innercut : mid + innercut),
                deleteat!(collect(range(extrema(y)..., length = len)[1 + outercut : len - outercut]), mid - innercut : mid + innercut),
                deleteat!(collect(range(extrema(z)..., length = len)[1 + outercut : len - outercut]), mid - innercut : mid + innercut),
            )), (len - 2outercut - 2innercut - 1)^3, 1, 1),
        :, 1, 1)
    first.(pairings), getindex.(pairings, 2), last.(pairings)
end

# For surface only
function interp_pairings_surf(x, y, z, len)
    len = max(3, isodd(len) ? len : len - 1)
    len_sq = len^2
    xyz = (x, y, z)
    surf_points = Vector{Vector{Float64}}(undef, 3)
    surf_points[1], surf_points[2], surf_points[3] = Vector{Float64}(), Vector{Float64}(), Vector{Float64}()

    for dim_const_idx = 1 : 3
        dim_var1_idx = mod1(dim_const_idx + 1, 3)
        dim_var2_idx = mod1(dim_const_idx + 2, 3)

        dim_var1_range = range(extrema(xyz[dim_var1_idx])..., len)
        dim_var2_range = range(extrema(xyz[dim_var2_idx])..., len)
        dim_var_data = Iterators.product(dim_var1_range, dim_var2_range)
        dim_var_data_first = reshape(first.(dim_var_data), len_sq)
        dim_var_data_last = reshape(last.(dim_var_data), len_sq)
        dim_const_extrema = extrema(xyz[dim_const_idx])
        surf_points[dim_const_idx] = vcat(surf_points[dim_const_idx], fill(dim_const_extrema[1], len_sq), fill(dim_const_extrema[2], len_sq))
        surf_points[dim_var1_idx] = vcat(surf_points[dim_var1_idx], dim_var_data_first, dim_var_data_first)
        surf_points[dim_var2_idx] = vcat(surf_points[dim_var2_idx], dim_var_data_last, dim_var_data_last)
    end
    surf_points[1], surf_points[2], surf_points[3]
end


function create_save_button(fig, parent, filename_save; but_lab = "Save")
    button = Button(
        parent,
        label = but_lab,
    )

    on(button.clicks) do n
        println("$(button.label[]) -> $filename_save.")
        filename = save_dialog_native(but_lab)
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
            col_samp = to_colormap(cm)
            doeplot.scPlot.attributes.color = [Makie.interpolated_getindex(col_samp, resp, lims) for resp in ordered_resp]
            doeplot.regrPlot.attributes.color = [Makie.interpolated_getindex(col_samp, resp, lims) for resp in ordered_resp_pred]

            doeplot.cbar.colormap = cm
            doeplot.cbar.limits = lims
        end
    end

    menu
end


function create_cm_sliders(fig, parent, doeplot, resp_range_limits, pos_sub, slider_precision = .01)
    scal, ext = get_interval_scales(doeplot.ptsResp)
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
        col_samp = to_colormap(cm)
        doeplot.scPlot.attributes.color = [Makie.interpolated_getindex(col_samp, resp, lims) for resp in ordered_resp]
        doeplot.regrPlot.attributes.color = [Makie.interpolated_getindex(col_samp, resp, lims) for resp in ordered_resp_pred]

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
    cm_comparison_plots = Symbol(CONFIG["colormap_comparison_plots"])
    cm_regr3d = Symbol(CONFIG["colormap_3d_regression"])
    resp_range_limits = CONFIG["resp_range_limits"]
    interact_effect = CONFIG["interact_effect"]

    doeplot1 = DoePlot()
    doeplot2 = DoePlot()
    doeplot3 = DoePlot()

    doeplot1.gridPos = doeplot2.gridPos = doeplot3.gridPos = pos_fig

    @info "Creating main plot..."
    main_fig = Figure()
    basic_ls(main_fig, pos_fig, title) = LScene(
        main_fig[pos_fig...],
        # title = title,
        scenekw = (
            camera = cam3d!,
            raw = false,
        ),
    )
    plot_sublayout = main_fig[pos_fig...] = GridLayout()
    pos_plots = [(1, 1), (1, 3), (4, 1)]

    lscene1 = doeplot1.lscene = basic_ls(main_fig, pos_fig, titles_resps[1])
    plot1, grids1 = create_plots(main_fig, lscene1, df, titles, titles_resps[1], titles_vars, titles_resps, num_vars, num_resps, cm, doeplot1, CONFIG)
    plot_sublayout[pos_plots[1]...] = lscene1
    cbar1 = doeplot1.cbar = plot_sublayout[pos_plots[1][1], pos_plots[1][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 1), titles_resps[1], cm)
    # cam1 = lscene1.scene.camera
    
    lscene2 = doeplot2.lscene = basic_ls(main_fig, pos_fig, titles_resps[2])
    plot2, grids2 = create_plots(main_fig, lscene2, df, titles, titles_resps[2], titles_vars, titles_resps, num_vars, num_resps, cm, doeplot2, CONFIG)
    plot_sublayout[pos_plots[2]...] = lscene2
    cbar2 = doeplot2.cbar = plot_sublayout[pos_plots[2][1], pos_plots[2][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 2), titles_resps[2], cm)
    # cam2 = lscene2.scene.camera

    lscene3 = doeplot3.lscene = basic_ls(main_fig, pos_fig, titles_resps[3])
    plot3, grids3 = create_plots(main_fig, lscene3, df, titles, titles_resps[3], titles_vars, titles_resps, num_vars, num_resps, cm, doeplot3, CONFIG)
    plot_sublayout[pos_plots[3]...] = lscene3
    cbar3 = doeplot3.cbar = plot_sublayout[pos_plots[3][1], pos_plots[3][2] + 1] = create_colorbar(main_fig, main_fig, select(resps, 3), titles_resps[3], cm)
    # cam3 = lscene3.scene.camera

    camc3 = cameracontrols(lscene3.scene)#cam3d!(lscene3.scene)
    lscene1.scene.camera = lscene3.scene.camera
    lscene2.scene.camera = lscene3.scene.camera
    lscene1.scene.camera_controls = camc3
    lscene2.scene.camera_controls = camc3

    lscenes = [lscene1, lscene2, lscene3]

    @info "Creating data table..."
    tbl_ax, tbl_txt, tbl_titles = create_table(main_fig, main_fig, df)
    table_sublayout = plot_sublayout[4:6, 3:4] = GridLayout(alignmode = Outside())
    table_sublayout[1, 1] = tbl_ax

    @info "Performing regressions..."
    sym_var1 = Symbol(titles_vars[1])
    sym_var2 = Symbol(titles_vars[2])
    sym_var3 = Symbol(titles_vars[3])
    sym_resp1 = Symbol(titles_resps[1])
    sym_resp2 = Symbol(titles_resps[2])
    sym_resp3 = Symbol(titles_resps[3])
    fm1 = @eval @formula($sym_resp1 ~ $sym_var1*$sym_var1 + $sym_var2*$sym_var2 + $sym_var3*$sym_var3)
    fm2 = @eval @formula($sym_resp2 ~ $sym_var1*$sym_var1 + $sym_var2*$sym_var2 + $sym_var3*$sym_var3)
    fm3 = @eval @formula($sym_resp3 ~ $sym_var1*$sym_var1 + $sym_var2*$sym_var2 + $sym_var3*$sym_var3)
    p0s = fill(.5, 10)
    model_ols1 = interact_effect ? curve_fit(multimodel_quad, Matrix(vars), resps[!, 1], p0s) : lm(fm1, df)
    model_ols2 = interact_effect ? curve_fit(multimodel_quad, Matrix(vars), resps[!, 2], p0s) : lm(fm2, df)
    model_ols3 = interact_effect ? curve_fit(multimodel_quad, Matrix(vars), resps[!, 3], p0s) : lm(fm3, df)
    doeplot1.regrModel = model_ols1
    doeplot2.regrModel = model_ols2
    doeplot3.regrModel = model_ols3

    resolution = markersize, density = CONFIG["plot_3d_regression_markersize"], CONFIG["plot_3d_regression_density"]
    outercut = CONFIG["plot_3d_regression_outer_cut"]
    innercut = CONFIG["plot_3d_regression_inner_cut"]
    surface_only = CONFIG["plot_3d_regression_surface_only"]
    marker = :rect
    var1, var2, var3 = eachcol(vars)
    x̂, ŷ, ẑ = surface_only ? interp_pairings_surf(var1, var2, var3, density) : interp_pairings(var1, var2, var3, density, outercut, innercut)
    xrange = calc_interval(var1)
    yrange = calc_interval(var2)
    zrange = calc_interval(var3)
    scal_x̂ = x̂ / xrange
    scal_ŷ = ŷ / yrange
    scal_ẑ = ẑ / zrange
    doeplot1.regrInterpVarsPts = doeplot2.regrInterpVarsPts = doeplot3.regrInterpVarsPts = [x̂ ŷ ẑ]

    coef_model_ols1 = coef(model_ols1)
    coef_model_ols2 = coef(model_ols2)
    coef_model_ols3 = coef(model_ols3)
    coef_model_ols1_round = round.(coef_model_ols1, sigdigits = 4)
    coef_model_ols2_round = round.(coef_model_ols2, sigdigits = 4)
    coef_model_ols3_round = round.(coef_model_ols3, sigdigits = 4)

    tbl_ax.title =
        if interact_effect
            # y = p₀ + p₁x₁ + p₂x₂ + p₃x₃ + p₄x₁² + p₅x₂² + p₆x₃²
            # + p₇x₁x₂ ⋅ p₈x₁x₃ ⋅ p₉x₂x₃
            "y_$sym_resp1 ≈ " *
            "$(coef_model_ols1_round[1]) + " *
            "$(coef_model_ols1_round[2])x₁ + " *
            "$(coef_model_ols1_round[3])x₂ + " *
            "$(coef_model_ols1_round[4])x₃ + " *
            "$(coef_model_ols1_round[5])x₁² + " *
            "$(coef_model_ols1_round[6])x₂² + " *
            "$(coef_model_ols1_round[7])x₃² + " *
            "\n$(coef_model_ols1_round[8])x₁x₂ ⋅ $(coef_model_ols1_round[9])x₁x₃ ⋅ $(coef_model_ols1_round[10])x₂x₃" *
            "\n" *
            "y_$sym_resp2 ≈ " *
            "$(coef_model_ols2_round[1]) + " *
            "$(coef_model_ols2_round[2])x₁ + " *
            "$(coef_model_ols2_round[3])x₂ + " *
            "$(coef_model_ols2_round[4])x₃ + " *
            "$(coef_model_ols2_round[5])x₁² + " *
            "$(coef_model_ols2_round[6])x₂² + " *
            "$(coef_model_ols2_round[7])x₃² + " *
            "\n$(coef_model_ols2_round[8])x₁x₂ ⋅ $(coef_model_ols2_round[9])x₁x₃ ⋅ $(coef_model_ols2_round[10])x₂x₃" *
            "\n" *
            "y_$sym_resp3 ≈ " *
            "$(coef_model_ols3_round[1]) + " *
            "$(coef_model_ols3_round[2])x₁ + " *
            "$(coef_model_ols3_round[3])x₂ + " *
            "$(coef_model_ols3_round[4])x₃ + " *
            "$(coef_model_ols3_round[5])x₁² + " *
            "$(coef_model_ols3_round[6])x₂² + " *
            "$(coef_model_ols3_round[7])x₃² + " *
            "\n$(coef_model_ols3_round[8])x₁x₂ ⋅ $(coef_model_ols3_round[9])x₁x₃ ⋅ $(coef_model_ols3_round[10])x₂x₃"
        else
            # y = p₀ + p₁x₁ + p₂x₂ + p₃x₃ + p₄x₁² + p₅x₂² + p₆x₃²
            "y_$sym_resp1 ≈ " *
            "$(coef_model_ols1_round[1]) + " *
            "$(coef_model_ols1_round[2])x₁ + " *
            "$(coef_model_ols1_round[3])x₂ + " *
            "$(coef_model_ols1_round[4])x₃ + " *
            "$(coef_model_ols1_round[5])x₁² + " *
            "$(coef_model_ols1_round[6])x₂² + " *
            "$(coef_model_ols1_round[7])x₃²" *
            "\n" *
            "y_$sym_resp2 ≈ " *
            "$(coef_model_ols2_round[1]) + " *
            "$(coef_model_ols2_round[2])x₁ + " *
            "$(coef_model_ols2_round[3])x₂ + " *
            "$(coef_model_ols2_round[4])x₃ + " *
            "$(coef_model_ols2_round[5])x₁² + " *
            "$(coef_model_ols2_round[6])x₂² + " *
            "$(coef_model_ols2_round[7])x₃²" *
            "\n" *
            "y_$sym_resp3 ≈ " *
            "$(coef_model_ols3_round[1]) + " *
            "$(coef_model_ols3_round[2])x₁ + " *
            "$(coef_model_ols3_round[3])x₂ + " *
            "$(coef_model_ols3_round[4])x₃ + " *
            "$(coef_model_ols3_round[5])x₁² + " *
            "$(coef_model_ols3_round[6])x₂² + " *
            "$(coef_model_ols3_round[7])x₃²"
        end
    # tbl_ax.titlesize = 18
    println(tbl_ax.title[])

    @info "Generating comparison plots..."
    regress_sublayout = main_fig[1:pos_fig[1], pos_fig[2][end] + 1] = GridLayout()
    pos_reg_cbar = (1, 1)
    pos_reg_anchor = (3, 1)
    regr1 = create_comparison_plot(main_fig, regress_sublayout, df, titles_vars, titles_resps[1], (pos_reg_anchor[1] + 0, pos_reg_anchor[2]), model_ols1, cm_comparison_plots)
    regr2 = create_comparison_plot(main_fig, regress_sublayout, df, titles_vars, titles_resps[2], (pos_reg_anchor[1] + 2, pos_reg_anchor[2]), model_ols2, cm_comparison_plots)
    regr3 = create_comparison_plot(main_fig, regress_sublayout, df, titles_vars, titles_resps[3], (pos_reg_anchor[1] + 4, pos_reg_anchor[2]), model_ols3, cm_comparison_plots)
    regress_sublayout[pos_reg_anchor[1] + 0, pos_reg_anchor[2]] = regr1
    regress_sublayout[pos_reg_anchor[1] + 2, pos_reg_anchor[2]] = regr2
    regress_sublayout[pos_reg_anchor[1] + 4, pos_reg_anchor[2]] = regr3
    cbar_regr = regress_sublayout[pos_reg_cbar...] = Colorbar(
        main_fig,
        label = LOCALE_TR["cbar_regr_lab"],
        limits = (1, 3),
        colormap = cgrad(cm_comparison_plots, 3, categorical = true),
        vertical = false,
        labelpadding = 5.,
        ticksize = 0.,
        ticklabelsvisible = false,
    )
    cbar_regr_labs = regress_sublayout[pos_reg_cbar[1] + 1, pos_reg_cbar[2]] = grid!(permutedims(hcat([Label(main_fig, lab, tellwidth = false) for lab in LOCALE_TR["cbar_regr_labs"]])))
    rowsize!(regress_sublayout, pos_reg_cbar[1], Relative(.03)) # For colorbar
    rowsize!(regress_sublayout, pos_reg_cbar[1] + 1, Relative(.001)) # For colorbar labels

    @info "Interpolating new points and computing predicted responses..."
    resp1 = doeplot1.ptsResp
    resp2 = doeplot2.ptsResp
    resp3 = doeplot3.ptsResp
    multimodel = interact_effect ? multimodel_quad : multimodel_quad_no_interact
    resp_pred1 = multimodel(doeplot1.regrInterpVarsPts, coef_model_ols1)
    resp_pred2 = multimodel(doeplot2.regrInterpVarsPts, coef_model_ols2)
    resp_pred3 = multimodel(doeplot3.regrInterpVarsPts, coef_model_ols3)
    # extrema1 = (min(minimum(resp1), minimum(resp_pred1)), max(maximum(resp1), maximum(resp_pred1)))
    # extrema2 = (min(minimum(resp2), minimum(resp_pred2)), max(maximum(resp2), maximum(resp_pred2)))
    # extrema3 = (min(minimum(resp3), minimum(resp_pred3)), max(maximum(resp3), maximum(resp_pred3)))
    regr_colors = to_colormap(cm_regr3d)
    plot_regr3d_1 = create_plot3(lscene1, resp_pred1, scal_x̂, scal_ŷ, scal_ẑ, titles_resps[1], regr_colors, extrema(resp1); marker = marker, markersize = markersize)
    plot_regr3d_2 = create_plot3(lscene2, resp_pred2, scal_x̂, scal_ŷ, scal_ẑ, titles_resps[2], regr_colors, extrema(resp2); marker = marker, markersize = markersize)
    plot_regr3d_3 = create_plot3(lscene3, resp_pred3, scal_x̂, scal_ŷ, scal_ẑ, titles_resps[3], regr_colors, extrema(resp3); marker = marker, markersize = markersize)

    doeplot1.regrInterpRespPts = resp_pred1
    doeplot2.regrInterpRespPts = resp_pred2
    doeplot3.regrInterpRespPts = resp_pred3
    doeplot1.regrPlot = plot_regr3d_1
    doeplot2.regrPlot = plot_regr3d_2
    doeplot3.regrPlot = plot_regr3d_3

    # cbar1.attributes.limits = extrema1
    # cbar2.attributes.limits = extrema2
    # cbar3.attributes.limits = extrema3
    # new_colors1 = map(resp -> regr_colors1[resp], resp1)
    # new_colors2 = map(resp -> regr_colors2[resp], resp1)
    # new_colors3 = map(resp -> regr_colors3[resp], resp1)
    # plot1[1].attributes.color = new_colors1
    # plot2[1].attributes.color = new_colors2
    # plot3[1].attributes.color = new_colors3

    @info "Creating other widgets..."

    inspector = DataInspector(main_fig)
    # Create tooltips for real points
    for (i, plot_resps) in enumerate((plot1, plot2, plot3) .=> (resp1, resp2, resp3))
        get!(plot_resps.first[1].attributes, :inspector_label, (self, idx, pos) -> begin
            pos = pos .* (xrange, yrange, zrange)
            display_text = GLMakie.Makie.position2string(pos)
            display_text = replace(display_text,   "x:" =>   "$(titles_vars[1]):")
            display_text = replace(display_text, "\ny:" => "\n$(titles_vars[2]):")
            display_text = replace(display_text, "\nz:" => "\n$(titles_vars[3]):")
            multimodel = interact_effect ? multimodel_quad : multimodel_quad_no_interact
            return display_text * "\n$(titles_resps[i]): $(plot_resps.second[idx])"
        end)
    end
    # Create tooltips for grid point (predicted values)
    # TODO:
    for (i, grids_coefs) in enumerate((grids1, grids2, grids3) .=> (coef_model_ols1, coef_model_ols2, coef_model_ols3))
        for grids in grids_coefs.first
            get!(grids.attributes, :inspector_label, (self, idx, pos) -> begin
                pos = pos .* (xrange, yrange, zrange)
                display_text = GLMakie.Makie.position2string(pos)
                display_text = replace(display_text,   "x:" =>   "$(titles_vars[1]):")
                display_text = replace(display_text, "\ny:" => "\n$(titles_vars[2]):")
                display_text = replace(display_text, "\nz:" => "\n$(titles_vars[3]):")
                multimodel = interact_effect ? multimodel_quad : multimodel_quad_no_interact
                return display_text * "\n$(titles_resps[i]): $(only(multimodel(reshape(pos, 1, 3), grids_coefs.second)))"
            end)
        end
    end
    # Create tooltips for predicted points
    for (i, plot_coefs) in enumerate((plot_regr3d_1, plot_regr3d_2, plot_regr3d_3) .=> (coef_model_ols1, coef_model_ols2, coef_model_ols3))
        get!(plot_coefs.first.attributes, :inspector_label, (self, idx, pos) -> begin
            pos = pos .* (xrange, yrange, zrange)
            display_text = GLMakie.Makie.position2string(pos)
            display_text = replace(display_text,   "x:" =>   "$(titles_vars[1]):")
            display_text = replace(display_text, "\ny:" => "\n$(titles_vars[2]):")
            display_text = replace(display_text, "\nz:" => "\n$(titles_vars[3]):")
            multimodel = interact_effect ? multimodel_quad : multimodel_quad_no_interact
            return display_text * "\n$(titles_resps[i]): $(only(multimodel(reshape(pos, 1, 3), plot_coefs.second)))"
        end)
    end

    save_button = create_save_button(main_fig, main_fig[1, 1], filename_save; but_lab = LOCALE_TR["save_but_lab"])

    cm_slider1, cm_slider_lab1 = create_cm_sliders(main_fig, plot_sublayout, doeplot1, resp_range_limits[1], (2, 1:2), CONFIG["slider_precision"])
    cm_slider2, cm_slider_lab2 = create_cm_sliders(main_fig, plot_sublayout, doeplot2, resp_range_limits[2], (2, 3:4), CONFIG["slider_precision"])
    cm_slider3, cm_slider_lab3 = create_cm_sliders(main_fig, plot_sublayout, doeplot3, resp_range_limits[3], (5, 1:2), CONFIG["slider_precision"])
    cm_menu = create_cm_menu(main_fig, main_fig, [doeplot1, doeplot2, doeplot3], [cm_slider1, cm_slider2, cm_slider3], cms; menu_prompt = LOCALE_TR["cm_menu_prompt"])

    button_sublayout = main_fig[1, 1:4] = grid!(hcat(save_button, cm_menu))

    trim!(main_fig.layout)

    GLMakie.activate!(;
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
