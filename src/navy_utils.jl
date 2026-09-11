# 有効数字1桁で、1, 2, 5 始まりの数字に四捨五入する
function round125(x)
    x == 0 && return 0
    s = sign(x)
    x = abs(x)
    exp10 = floor(Int, log10(x))
    base = 10.0^exp10
    m = x / base
    candidates = [1, 2, 5, 10]
    lead = candidates[argmin(abs.(candidates .- m))]
    return s * lead * base
end

# 与えた範囲内の a×10^n を返す
function nice_numbers(xmin, xmax; a_values=false)
    xmin > xmax && ((xmin, xmax) = (xmax, xmin))
    result = Float64[]
    nmin = floor(Int, log10(xmin))
    nmax = ceil(Int, log10(xmax))
    if a_values isa Vector
        a_values = a_values
    elseif (nmax - nmin) >= 3
        a_values = [1, 2, 5]
    elseif (nmax - nmin) == 2
        a_values = [1, 2, 3, 5, 7]
    else
        a_values = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    end
    for n in nmin:nmax
        scale = 10.0^n
        for a in a_values
            x = a * scale
            xmin <= x <= xmax && push!(result, x)
        end
    end
    sort!(result)
end

# 最初の有効数字を取得
function first_significant_digit(x)
    x == 0 && return 0
    x = abs(x)
    Int(floor(x / 10^floor(log10(x))))
end
# 最初の2桁有効数字を取得
function first_two_significant_digits(x)
    x == 0 && return 0
    x = abs(x)
    p = floor(log10(x))
    Int(floor(x / 10^(p - 1)))
end

function real_length(x, xname, unit, radius=6371E3, lat=0.0)
    if unit == "m"
        len = x[end] - x[1]
    elseif unit == "km"
        len = (x[end] - x[1]) * 1E3
    elseif is_lon(xname)
        len = (x[end] - x[1]) / 360.0 * 2 * pi * radius * cos(lat * deg2rad)
    elseif is_lat(xname)
        len = (x[end] - x[1]) / 360.0 * 2 * pi * radius
    else
        error("unit $unit is not supported yet.")
    end
    return len
end


function is_lonlat(dim_name)
    name = lowercase(string(dim_name))
    name in ["lon", "longitude", "x", "lat", "latitude", "y"]
end
function is_lon(dim_name)
    name = lowercase(string(dim_name))
    name in ["lon", "longitude", "x"]
end
function is_lat(dim_name)
    name = lowercase(string(dim_name))
    name in ["lat", "latitude", "y"]
end
