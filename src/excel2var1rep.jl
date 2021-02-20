# module excel2var1rep

# using PackageCompiler

using CSV, DataFrames
# using GLM, StatsModels

using GLMakie#, Makie

function read_data()
    df = CSV.File("res/heat_treatement_data_2.csv") |> DataFrame
    
    types = df[1, :]
    # NUM_VARS = count(t -> !ismissing(t) && t == "variable", types)
    # NUM_RESPS = count(t -> !ismissing(t) && t == "response", types)
    # NUM_LVLS = 
    
    select!(df, Not(1))
    # titles = replace.(["$(x) ($(y))" for (x, y) in zip(names(df), df[1, :])], " "=>"_")
    titles = [:x_stime, :x_t, :x_atime, :y_yield, :y_str, :y_elong]
    rename!(df, titles)
    delete!(df, 1)
    df[!, :] = parse.(Float64, df[!, :])

    df, titles, types
end

calc_range(a) = abs(-(extrema(a)...))

function get_ranges(df)
    n = size(df)[1]
    x = select(df, 1, copycols=false)[1]
    y = select(df, 2, copycols=false)[1]
    z = select(df, 3, copycols=false)[1]
    range_x = calc_range(x)
    range_y = calc_range(y)
    range_z = calc_range(z)
    ext_x = extrema(x)
    ext_y = extrema(y)
    ext_z = extrema(z)
    scal_ext_x = ext_x ./ range_x
    scal_ext_y = ext_y ./ range_y
    scal_ext_z = ext_z ./ range_z

    n,
    x, y, z,
    range_x, range_y, range_z,
    ext_x, ext_y, ext_z,
    scal_ext_x, scal_ext_y, scal_ext_z
end

function graph()
    df, titles, types = read_data()

    n,
    x, y, z,
    range_x, range_y, range_z,
    ext_x, ext_y, ext_z,
    scal_ext_x, scal_ext_y, scal_ext_z = get_ranges(df)

    xtickrange = range(scal_ext_x..., length=n)
    ytickrange = range(scal_ext_y..., length=n)
    ztickrange = range(scal_ext_z..., length=n)
    xticklabels=string.(range(ext_x..., length=n))
    yticklabels=string.(range(ext_y..., length=n))
    zticklabels=string.(range(ext_z..., length=n))

    ls = scene, layout = layoutscene()
    
    colors = to_colormap(:RdYlGn_3, n)

    titles_resp = view(titles, 4:5)

    for (idx, title) in enumerate(titles_resp)
        s = layout[1, idx] = LScene(scene)

        sort!(df, title)

        for (i, col) in enumerate(colors)
            scal_x = x / range_x
            scal_y = y / range_y
            scal_z = z / range_z

            scatter!(
                s,
                scal_x[i:i], scal_y[i:i], scal_z[i:i],
                markersize = 100, marker = :circle,
                color = col,
                show_axis = true,
                camera = cam3d!,
            )
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
