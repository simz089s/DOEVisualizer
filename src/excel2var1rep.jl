# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames
# using GLM, StatsModels

using GLMakie#, Makie

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

function graph()
    df, titles, types, num_vars, num_resps, num_rows = read_data("res/heat_treatement_data_2.csv") # TODO: better way to get filename/path

    x, y, z, n = get_xyzn(df)

    range_x, range_y, range_z,
        ext_x, ext_y, ext_z,
        scal_ext_x, scal_ext_y, scal_ext_z = get_ranges(x, y, z)

    # Scale data to data/interval so that the plot is unit/equal sized
    xtickrange = range(scal_ext_x..., length=n)
    ytickrange = range(scal_ext_y..., length=n)
    ztickrange = range(scal_ext_z..., length=n)
    # The tick labels should still represent the original range of values
    xticklabels = string.(range(ext_x..., length=n))
    yticklabels = string.(range(ext_y..., length=n))
    zticklabels = string.(range(ext_z..., length=n))

    ls = scene, layout = layoutscene()
    
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

    for (idx, title) in enumerate(titles_resp)
        s = layout[div(idx, 2, RoundUp), idx%2] = LScene(scene) # Lay out plots in grid fashion (div or % determines columnwise or rowwise)

        # Plot point one-by-one individually so we can map colormap to response value
        sort!(df, title)

        scal_x = x / range_x
        scal_y = y / range_y
        scal_z = z / range_z

        # Draw points
        for (i, col) in enumerate(colors)
            scatter!(
                s,
                scal_x[i:i], scal_y[i:i], scal_z[i:i],
                markersize = 100, marker = :circle,
                color = col,
                show_axis = true,
                camera = cam3d!,
            )
        end
        
        # Draw grid
        # TODO: probably use some permutation function to make it more elegant
        for var_dim_idx in 1:num_vars # scal_uniq_var_vals index of the dimension that will draw the line
            # scal_uniq_var_vals index of the other invariant dimensions
            invar_data_dim_idx1 = mod1(var_dim_idx + 1, 3)
            invar_data_dim_idx2 = mod1(var_dim_idx + 2, 3)
            for line_idx in 1:n_uniq_var_vals
                invar_data_dim1 = fill(scal_uniq_var_vals[invar_data_dim_idx1][line_idx], n_uniq_var_vals)
                invar_data_dim2 = fill(scal_uniq_var_vals[invar_data_dim_idx2][line_idx], n_uniq_var_vals)
                data = Array{Array{Float64, 1}, 1}(undef, 3)
                data[var_dim_idx] = scal_uniq_var_vals[var_dim_idx]
                data[invar_data_dim_idx1] = invar_data_dim1
                data[invar_data_dim_idx2] = invar_data_dim2
                lines!(
                    s,
                    data[1], data[2], data[3],
                    linestyle = :dash,
                    # color = colors,
                    show_axis = true,
                )
            end
        end

        xticks!(s.scene, xtickrange=xtickrange, xticklabels=xticklabels)
        yticks!(s.scene, ytickrange=ytickrange, yticklabels=yticklabels)
        zticks!(s.scene, ztickrange=ztickrange, zticklabels=zticklabels)
        # display(s.scene)
    end
    
    display(scene)
end

graph()

# f = @formula(y_yield ~ 1 + x_stime + x_t + x_atime)
# model = glm(f, select(df, 1:4), Normal(), IdentityLink())

# end

# grid
# label
# optimize (cache) scal_ / range_
