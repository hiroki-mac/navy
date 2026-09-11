
# open netcdf file and write axis info to metadata
function open_nc(file::String; dim=false)
    if dim != false && occursin("*", file) # 複数ファイルの連結オープン
        files = glob(file)
        cb = Cube(open_mfdataset(DimArray(files, dim)))
        f = files[1]
    elseif dim == false && !occursin("*", file)
        cb = Cube(open_dataset(file)) # ファイルオープン
        f = file
    elseif dim != false && !occursin("*", file)
        error("use wildcard * to open multiple files.")
    else
        error("set axis for concating in keyword \"dim=\".")
    end
    axes = DimensionalData.Dimensions.name(cb.axes) # 軸一覧を取得
    # 各軸について unit と long_name と positive を取得して、metadataに書き込む
    for x in axes
        metadata(cb)["Axis_units_$(x)"] = ncgetatt(f, String(x), "units")
        metadata(cb)["Axis_long_name_$(x)"] = ncgetatt(f, String(x), "long_name")
        if (ncgetatt(f, String(x), "positive") == nothing)
            metadata(cb)["Axis_positive_$(x)"] = "up"
        else
            metadata(cb)["Axis_positive_$(x)"] = ncgetatt(f, String(x), "positive")
        end
    end
    # ファイル情報をmetadaに書き込む
    metadata(cb)["file_path"] = abspath(f)
    return cb
end #open_nc
