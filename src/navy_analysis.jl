
# func: mean 平均, median 中央値, middle 値の範囲の真ん中
#       std 標準偏差, var 分散, maximum 最大値, minimum 最小値
#       sum 合計,
function ope(func, var; dims=false::Union{Symbol,Integer}, drop=false::Bool)
    if dims == false
        new_var = func(var)
    else
        new_var = mapslices(func, var; dims=dims)
    end
    # 不要次元を落とす
    if drop
        new_var = dropdims(new_var, dims=dims)
    end
    # metadataにopeした情報を書き込む
    md = metadata(var)
    md["operation"] = "$(func) along $(dims)-axis."
    return rebuild(new_var; metadata=md)
end

# integral using Trapz Pkg
# TODO:
#  -lon, lat が deg のときに rad に変える ← YAXArrayが単位を保持してないかも
#
function integral(var::YAXArray; dims=false::Union{Symbol,Integer}, drop=false::Bool)
    dims_val = map(x -> begin    # 軸配列を取得。
            dd = getproperty(var, x)
            if lookup(dd).order isa DimensionalData.ReverseOrdered
                -dd.val                   # ReversedOrderなら符号を反転させる
            else
                dd.val
            end
        end, dims)
    new_var = mapslices(x -> trapz(dims_val, x), var; dims=dims)
    # 不要次元を落とす
    if drop
        new_var = dropdims(new_var, dims=dims)
    end
    # metadataにopeした情報を書き込む
    md = metadata(var)
    md["operation"] = "integral along $(dims)-axis"
    return rebuild(new_var; metadata=md)
end
