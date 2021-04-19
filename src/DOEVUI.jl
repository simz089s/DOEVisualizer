module DOEVUI


using Gtk
import JSON: parsefile

include("DOEVDBManager.jl")
include("DOEVisualizer.jl") # TODO: For release use using DOEVisualizer ?


function on_button_clicked(widget)
    PREFIX = "$(@__DIR__)/../"
    filename_config = PREFIX * "cfg/config.json"
    CONFIG::Dict{String, Union{String, Number}} = parsefile(filename_config, dicttype = Dict{String, Union{String, Number}})
    filename_db = PREFIX * CONFIG["db_path"]
    filename_locale = PREFIX * CONFIG["locale_path"] * CONFIG["locale"] * ".json"
    cm::Symbol = Symbol(CONFIG["default_colormap"])

    LOCALE_TR::Dict{String, Union{String, AbstractArray{Any, 1}}} = parsefile(filename_locale, dicttype = Dict{String, Union{String, AbstractArray{Any, 1}}})

    filename_data::String = isempty(CONFIG["data_path"]) ?
                            open_dialog_native(LOCALE_TR["file_dialog_window_title"]) :
                            PREFIX * CONFIG["data_path"]

    if isempty(filename_db)
        exit("No database file found. Exiting...")
    elseif isempty(filename_data) # If empty data file path in config.json
        filename_data = DOEVisualizer.find_csv("$(@__DIR__)/../res") # or TSV
    end

    # TODO: Implement
    if isempty(filename_data) # If still no CSV data file path in /res/ directory
        # db = DOEVDBManager.setup(filename_db, "HEAT_TREATMENT_DATA_2")
        # query = """
        #     SELECT *
        #     FROM $tablename;
        # """
        # df = get_data(db, query)
        @error "NOT IMPLEMENTED YET: Get data from DB when no CSV file"
        exit(1)
    else
        df, titles, vars, resps, num_vars, num_resps = DOEVisualizer.read_data(filename_data)
        # db = DOEVDBManager.setup(filename_db, splitext(basename(filename_data))[1], df)
        println("Loaded $filename_data")
    end
    # display(df_test)

    @info "Setting up interface and plots..."
    DOEVisualizer.setup(df, titles, vars, resps, num_vars, num_resps, filename_data, cm, CONFIG, LOCALE_TR)
end


function __init__()
    win = GtkWindow("DoE Visualizer")

    btn = GtkButton("Load")
    push!(win, btn)

    signal_connect(on_button_clicked, btn, "clicked")
    # signal_connect(btn, "clicked") do widget
    #     println("Load")
    # end

    showall(win)
end


end
