# cut
# 利用例： cut(air; lon=1:102, lat=1, n_time=1)
# 通常は値を指定（近い値が選択される）。軸名に n_ をつけるとインデックス指定
# インデックス指定の際は負の値を与えると、後から数える（-1 = lastindex）
# 範囲指定は日付以外は lon=1:180 の形
# ただしlon=1:2:180 とすると2°間隔でサンプリングする（単に間引きにも使える）
# 日付指定時は、DateTime(y,m,d)の形式を使う
# 日付の範囲指定は DateTime..DateTimeの形式を用いる
# 切り出し面の情報保持のため、cutした次元も残す。
function cut(var::YAXArray; kwargs...)
    # lon=n → lon=n:n にして、切り出した次元を残す。
    cuts = map(p -> begin
            p1 = p.first
            p2 = p.second
            if p2 isa DateTime
                t = dims(var, p1) # 時間軸を取り出す
                p2 = t[argmin(abs.(p2 .- t))] # 時間軸の中で、指定の値に最も近い値を取り出す
                p2 = Between(p2, p2) # 軸を残すためにBetween化
                return p1 => p2
            elseif p2 isa IntervalSets.Interval
                p2 = p2
            elseif !(p2 isa AbstractRange)
                p2 = p2:p2
            elseif p2 isa StepRange
                p2 = p2
            else
                p2 = Between(first(p2), last(p2))
            end
            s = string(p1)
            if s[1:2] == "n_"
                p1 = Symbol(s[3:end]) # n_ を削除する
                n = length(axes(var, p1))
                if (first(p2) < 0) && (last(p2) < 0)
                    p2 = (n+1+first(p2)):(n+1+last(p2)) # 最後から数える
                elseif (first(p2) < 0)
                    p2 = (n+1+first(p2)):last(p2)
                elseif (last(p2) < 0)
                    p2 = first(p2):(n+1+last(p2)) # 最後から数える
                end
            elseif (p2 isa Between)
                p2 = p2
            else
                p2 = Near(p2) # Near() を付加する
            end
            p1 => p2
        end, Tuple(kwargs))
    for i in cuts
        if !(i.first in DimensionalData.Dimensions.name(var.axes))
            var_name = var.properties["name"]
            error("$(i.first)-axis is not included in $(var_name).")
        end
    end
    new_var = getindex(var; cuts...) #これで :lon=>1 の形式を lon=1 に変換して渡す
    return new_var
    # metadataにcutした情報を書き込む
    # md = metadata(var)
    # str = ""
    # for i in 1:length(cuts)
    #     str *= string(cuts[i][1]) * "=" * string(cuts[i][2]) * "; "
    # end
    # md["cut"] = str[1:end-2]
    # return rebuild(new_var; metadata=md)
end # cut


# 長さ1の次元を落とす
function dd(var::YAXArray)
    drop_dim_name = name.(filter(d -> length(d) == 1, dims(var)))
    return dropdims(var, dims=drop_dim_name)
end

# arrows用にデータを加工して出力
# skip 間引きの間隔
function data_for_arrows(u_yax, v_yax, skip=4, radius=6371E3, lat=0.0)
    pd_names = name.(filter(d -> length(d) != 1, dims(u_yax))) # 長さが1より大きい次元の名前
    x = collect(lookup(dims(u_yax, pd_names[1])))[1:skip:end]
    y = collect(lookup(dims(u_yax, pd_names[2])))[1:skip:end]
    u = collect(dd(u_yax).data)[1:skip:end, 1:skip:end]
    v = collect(dd(v_yax).data)[1:skip:end, 1:skip:end]

    md = metadata(u_yax)
    x_unit = md["Axis_units_"*String(pd_names[1])]
    y_unit = md["Axis_units_"*String(pd_names[2])]
    f = 1.0

    if (is_lonlat(pd_names[1]) && is_lonlat(pd_names[2])) # lat-lon
        return x, y, u, v, f
    elseif x_unit == y_unit # 単位が同じ場合
        return x, y, u, v, f
    else
        x_fact = real_length(x, pd_names[1], x_unit) / (x[end] - x[1])
        y_fact = real_length(y, pd_names[2], y_unit) / (y[end] - y[1])
        f = (x_fact / y_fact) # 表示用の v にかけるファクター
        return x, y, u, v, f
    end
end
