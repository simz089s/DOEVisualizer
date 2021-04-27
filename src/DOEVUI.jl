module DOEVUI


import Dates: now
import Unicode: normalize
import JSON: parsefile
import CSV: File
using DataFrames
using Taro
# using TableView
using Gtk
import Distributed: addprocs, @fetchfrom, remotecall_fetch
# using IOLogging, LoggingExtras

include("DOEVDBManager.jl")
include("DOEVisualizer.jl")

# try Taro.init() catch e if !isa(e, Taro.JavaCall.JavaCallError) throw(e) end end


function find_data_file(dir, valid_file_ext)
    for file in readdir(dir)
        if occursin(valid_file_ext, normalize(last(file, 4), casefold = true)) # Find first valid data file given by readdir()
            return "$dir/$file"
        end
    end
    ""
end


function read_data(filename, xlsrange = "A1:A1", xlssheet = "Sheet1")
    df = if occursin(r"[ct]sv$", filename)
        fixtype = parse
        DataFrame(File(filename))
    elseif occursin(r"(xlsx?)$|(ods)$", filename)
        fixtype = convert
        DataFrame(readxl(filename, xlssheet, xlsrange))
    end

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
    df[!, 2:end] = fixtype.(Float64, df[!, 2:end])
    vars = select(df, idx_vars)
    resps = select(df, idx_resps)

    df, titles[2:end], vars, resps, length(idx_vars), length(idx_resps)#, num_rows
end


function on_load_button_clicked(w, CONFIG_NEW)
    # try Taro.init() catch e if !isa(e, Taro.JavaCall.JavaCallError) throw(e) end end

    PREFIX = "$(@__DIR__)/../"
    filename_config = PREFIX * "cfg/config.json"
    CONFIG = mergewith!((v1, v2) -> isnothing(v2) ? v1 : v2, parsefile(filename_config, dicttype = Dict{String, Union{String, Number, Vector}}), CONFIG_NEW)
    filename_db = PREFIX * CONFIG["db_path"]
    filename_locale = PREFIX * CONFIG["locale_path"] * CONFIG["locale"] * ".json"
    cm = Symbol(CONFIG["default_colormap"])
    valid_file_ext = r"\.([ct]sv$|xlsx?$|ods$)"
    xlsrange = "A3:G13"
    xlssheet = "Sheet1"

    LOCALE_TR = parsefile(filename_locale, dicttype = Dict{String, Union{String, Array{Any, 1}}})

    filename_data = isempty(CONFIG["data_path"]) ?
                    open_dialog_native(LOCALE_TR["file_dialog_window_title"], GtkNullContainer(), ("*.csv", "*.tsv", "*.ods", "*.xls", "*.xlsx", "*")) :
                    PREFIX * CONFIG["data_path"]

    if isempty(filename_db)
        flush(stdout); flush(stderr); exit("No database file found. Exiting...")
    elseif isempty(filename_data) # If empty data file path in config.json
        filename_data = find_data_file("$(@__DIR__)/../res", valid_file_ext)
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
        df, titles, vars, resps, num_vars, num_resps = read_data(filename_data, xlsrange, xlssheet)
        # db = DOEVDBManager.setup(filename_db, splitext(basename(filename_data))[1], df)
        println("Loaded $filename_data"); flush(stdout); flush(stderr)
    end
    # display(df_test)

    filename_save = string("$(@__DIR__)/../res/", replace("$(now()) $(join(titles, '-')).png", r"[^a-zA-Z0-9_\-\.]" => '_'))

    @info "Setting up interface and plots..."; flush(stdout); flush(stderr)
    DOEVisualizer.setup(df, titles, vars, resps, num_vars, num_resps, filename_save, cm, CONFIG, LOCALE_TR)
end


function on_settings_button_clicked(w)
end


function __init__()
    CONFIG = parsefile("$(@__DIR__)/../cfg/config.json")
    margin_space = 15

    win = GtkWindow("DoE Visualizer")

    grid = GtkGrid()
    push!(win, grid)

    resp_range_limits_grid = grid[1, 1] = GtkGrid()
    set_gtk_property!(resp_range_limits_grid, :column_spacing, margin_space)
    set_gtk_property!(resp_range_limits_grid, :margin, margin_space)
    resp_range_limits_grid[1:3, 1] = GtkLabel("Response range limits")
    resp_range_limits_grid[2, 2], resp_range_limits_grid[3, 2] = GtkLabel("Min"), GtkLabel("Max")
    row_offset = 2
    resp_range_limits_entries = Vector{Tuple{Gtk.GtkEntryLeaf, Gtk.GtkEntryLeaf}}(undef, 3)
    for row = 1 : 3
        resp_range_limits_grid[1, row + row_offset] = GtkLabel("Response $row")
        resp_range_limits_entries[row] = resp_range_limits_grid[2, row + row_offset], resp_range_limits_grid[3, row + row_offset] = GtkEntry(), GtkEntry()
        # set_gtk_property!.(resp_range_limits_entries[row], :placeholder_text, "0")
    end

    plot3d_regr_grid = grid[1, 2] = GtkGrid()
    set_gtk_property!(plot3d_regr_grid, :column_spacing, margin_space)
    set_gtk_property!(plot3d_regr_grid, :margin, margin_space)
    plot3d_regr_grid[1:3, 1] = GtkLabel("3D plot regression options")
    row_offset = 1
    plot3d_regr_entries::Vector{Pair{String, Union{String, Gtk.GtkEntryLeaf}}} = [
        "plot_3d_regression_density" => "Density",
        "plot_3d_regression_outer_cut" => "Outer cut",
        "plot_3d_regression_inner_cut" => "Inner cut",
    ]
    for (row, (key, txt)) in enumerate(plot3d_regr_entries)
        plot3d_regr_grid[1, row + row_offset] = GtkLabel(txt)
        plot3d_regr_entries[row] = _, plot3d_regr_grid[2:3, row + row_offset] = plot3d_regr_entries[row].first => GtkEntry()
        set_gtk_property!(plot3d_regr_entries[row].second, :placeholder_text, CONFIG[key])
    end
    plot3d_regr_grid[2:3, 5] = GtkLabel("You must have (outer cut + inner cut < density)")

    menu = grid[1, 3] = GtkButtonBox(:h)
    set_gtk_property!(menu, :margin, 2margin_space)
    load_btn = GtkButton("Visualize")
    settings_btn = GtkButton("Settings")
    push!(menu, load_btn)
    push!(menu, settings_btn)

    # sp = GtkSpinner()
    # grid[1, 4] = sp
    # proc_id = addprocs(1)[1]

    # get!(CONFIG, "resp_range_limits", [tryparse.(Float64, get_gtk_property.(resp_range_limits, :text, String)) for resp_range_limits in resp_range_limits_entries])
    # foreach(p -> let (key, entry) = p; CONFIG[key] = tryparse(Int32, get_gtk_property(entry, :text, String)) end, plot3d_regr_entries)
    # on_load_button_clicked(nothing, CONFIG)
    signal_connect(load_btn, "clicked") do w
        get!(CONFIG, "resp_range_limits", [tryparse.(Float64, get_gtk_property.(resp_range_limits, :text, String)) for resp_range_limits in resp_range_limits_entries])
        foreach(p -> let (key, entry) = p; CONFIG[key] = tryparse(Int32, get_gtk_property(entry, :text, String)) end, plot3d_regr_entries)
        try
            on_load_button_clicked(w, CONFIG)
        catch e
            showerror(stderr, e)
            # display(sprint(showerror, e, catch_backtrace()))
        # finally
        #     Taro.JavaCall.destroy()
        end
        # start(sp)
        # @Gtk.sigatom begin
        #     @async begin
        #         s = @fetchfrom proc_id begin
        #             vizGUI = Threads.@spawn on_load_button_clicked(w, CONFIG)
        #             wait(vizGUI)
        #         end
        #         @Gtk.sigatom begin
        #             stop(sp)
        #             display("AAAAAAAAAAAAAAAA $s")
        #         end
        #     end
        # end
    end

    signal_connect(on_settings_button_clicked, settings_btn, "clicked")

    showall(win)
end


end
