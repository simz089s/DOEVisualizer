# using Distributed
module DOEXL

function read_xls(filename, xlssheet, xlsrange)
    # try
        Taro.init()
    # catch e
    #     if !isa(e, Taro.JavaCall.JavaCallError)
    #         throw(e)
    #     end
    # end
    DataFrame(readxl(filename, xlssheet, xlsrange))
end

end
