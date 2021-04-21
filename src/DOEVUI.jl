module DOEVUI


import Dates: now
import Unicode: normalize
import JSON: parsefile
import CSV: File
using DataFrames
using Gtk

include("DOEVDBManager.jl")
include("DOEVisualizer.jl")


function find_csv(dir)::String
    for file in readdir(dir)
        if normalize(last(file, 4), casefold = true) in (".csv", ".tsv") # Find first file that ends with .{c,t}sv (case insensitive)
            return "$dir/$file"
        end
    end
    ""
end


function read_data(filename)
    df = DataFrame(File(filename))

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


function on_load_button_clicked(w, resp_range_limits, plot3d_regr_opts)
    PREFIX = "$(@__DIR__)/../"
    filename_config = PREFIX * "cfg/config.json"
    CONFIG::Dict{String, Union{String, Number}} = parsefile(filename_config, dicttype = Dict{String, Union{String, Number}})
    filename_db = PREFIX * CONFIG["db_path"]
    filename_locale = PREFIX * CONFIG["locale_path"] * CONFIG["locale"] * ".json"
    cm::Symbol = Symbol(CONFIG["default_colormap"])

    LOCALE_TR::Dict{String, Union{String, AbstractArray{Any, 1}}} = parsefile(filename_locale, dicttype = Dict{String, Union{String, AbstractArray{Any, 1}}})

    filename_data::String = isempty(CONFIG["data_path"]) ?
                            open_dialog_native(LOCALE_TR["file_dialog_window_title"], GtkNullContainer(), ("*.csv", "*.tsv", "*")) :
                            PREFIX * CONFIG["data_path"]

    if isempty(filename_db)
        flush(stdout); flush(stderr); exit("No database file found. Exiting...")
    elseif isempty(filename_data) # If empty data file path in config.json
        filename_data = find_csv("$(@__DIR__)/../res") # or TSV
    end

    # TODO: Implement
    if isempty(filename_data) # If still no CSV data file path in /res/ directory
        # db = DOEVDBManager.setup(filename_db, "HEAT_TREATMENT_DATA_2")
        # query = """
        #     SELECT *
        #     FROM $tablename;
        # """
        # df = get_data(db, query)
        @error "NOT IMPLEMENTED YET: Get data from DB when no CSV file"; flush(stdout); flush(stderr)
        exit(1)
    else
        df, titles, vars, resps, num_vars, num_resps = read_data(filename_data)
        # db = DOEVDBManager.setup(filename_db, splitext(basename(filename_data))[1], df)
        println("Loaded $filename_data"); flush(stdout); flush(stderr)
    end
    # display(df_test)

    filename_save = string("$(@__DIR__)/../res/", replace("$(now()) $(join(titles, '-')).png", r"[^a-zA-Z0-9_\-\.]" => '_'))

    @info "Setting up interface and plots..."; flush(stdout); flush(stderr)
    DOEVisualizer.setup(df, titles, vars, resps, num_vars, num_resps, resp_range_limits, plot3d_regr_opts, filename_save, cm, CONFIG, LOCALE_TR)
end


# function on_settings_button_clicked(w)
# end


function __init__()
    win = GtkWindow("DoE Visualizer")

    grid = GtkGrid()
    push!(win, grid)

    menu = grid[1, 1] = GtkButtonBox(:h)
    load_btn = GtkButton("Load")
    # settings_btn = GtkButton("Settings")
    push!(menu, load_btn)
    # push!(menu, settings_btn)
    
    resp_range_limits_grid = grid[1, 2] = GtkGrid()
    set_gtk_property!(resp_range_limits_grid, :column_spacing, 15)
    resp_range_limits_grid[2, 1], resp_range_limits_grid[3, 1] = GtkLabel("Min"), GtkLabel("Max")
    resp_range_limits_grid[1, 2] = GtkLabel("Response 1")
    resp_range_limits_grid[1, 3] = GtkLabel("Response 2")
    resp_range_limits_grid[1, 4] = GtkLabel("Response 3")
    resp_range_limits_entries1 = resp_range_limits_grid[2, 2], resp_range_limits_grid[3, 2] = GtkEntry(), GtkEntry()
    resp_range_limits_entries2 = resp_range_limits_grid[2, 3], resp_range_limits_grid[3, 3] = GtkEntry(), GtkEntry()
    resp_range_limits_entries3 = resp_range_limits_grid[2, 4], resp_range_limits_grid[3, 4] = GtkEntry(), GtkEntry()
    resp_range_limits_entries = (resp_range_limits_entries1, resp_range_limits_entries2, resp_range_limits_entries3)
    set_gtk_property!.(resp_range_limits_entries1, :placeholder_text, "0")
    set_gtk_property!.(resp_range_limits_entries2, :placeholder_text, "0")
    set_gtk_property!.(resp_range_limits_entries3, :placeholder_text, "0")

    plot3d_regr_grid = grid[1, 3] = GtkGrid()
    set_gtk_property!(plot3d_regr_grid, :column_spacing, 15)
    plot3d_regr_grid[1:2, 1] = GtkLabel("3D plot regression options")
    plot3d_regr_grid[1, 2] = GtkLabel("Density")
    plot3d_regr_grid[1, 3] = GtkLabel("Outer cut")
    plot3d_regr_grid[1, 4] = GtkLabel("Inner cut")
    plot3d_regr_grid[1:2, 5] = GtkLabel("You must have (outer cut + inner cut < density)")
    plot3d_regr_density = plot3d_regr_grid[2, 2] = GtkEntry()
    plot3d_regr_outercut = plot3d_regr_grid[2, 3] = GtkEntry()
    plot3d_regr_innercut = plot3d_regr_grid[2, 4] = GtkEntry()
    set_gtk_property!(plot3d_regr_density, :placeholder_text, "7")
    set_gtk_property!(plot3d_regr_outercut, :placeholder_text, "1")
    set_gtk_property!(plot3d_regr_innercut, :placeholder_text, "1")

    signal_connect(load_btn, "clicked") do w
        resp_range_limits = [tryparse.(Float64, get_gtk_property.(resp_range_limits, :text, String)) for resp_range_limits in resp_range_limits_entries]
        plot3d_regr_opts = tryparse.(Int32, get_gtk_property.((plot3d_regr_density, plot3d_regr_outercut, plot3d_regr_innercut), :text, String))
        on_load_button_clicked(w, resp_range_limits, plot3d_regr_opts)
    end
    # signal_connect(on_settings_button_clicked, settings_btn, "clicked")

    showall(win)
end


end
