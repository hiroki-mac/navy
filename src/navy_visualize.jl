# draw
# aspect: プロット領域のアスペクト比
# crange: カラートーン/等値線の範囲
# cmap; カラーマップ
# [colormap list] https://docs.makie.org/stable/explanations/colors#Colormaps
# anim: アニメーションする方向の軸
# aint: アニメーションの間隔（秒）
# asave: アニメーションを保存するファイル名
# [map projection list] https://proj.org/en/stable/operations/projections/all_images.html
#
function draw2D(var, plot_type::Symbol; aspect=2, crange=nothing, cmap=:jet, anim=false, aint=0.2, asave=false,
    map=false, mdest="+proj=ortho", xrange=nothing, yrange=nothing)

    if anim isa Symbol
        var2d = Observable(getindex(var; anim => 1:1))
    else
        var2d = Observable(var)
    end

    if crange isa StepRange
        minmax = (first(crange), last(crange))
        crange = crange
        cdiv = Integer(round((last(crange) - first(crange)) / step(crange)))
        cmap = cgrad(cmap, cdiv; categorical=true)
    elseif crange isa AbstractRange
        minmax = (first(crange), last(crange))
        crange = first(crange):10:last(crange)
    elseif crange isa Number
        cmin = @lift(floor(minimum($var2d), sigdigits=2))
        cmax = @lift(ceil(maximum($var2d), sigdigits=2))
        minmax = @lift(($cmin, $cmax))
        crange = Integer(crange)
        cmap = cgrad(cmap, crange; categorical=true)
    else
        cmin = @lift(floor(minimum($var2d), sigdigits=2))
        cmax = @lift(ceil(maximum($var2d), sigdigits=2))
        minmax = @lift(($cmin, $cmax))
        cstep = @lift(round125(abs($cmax - $cmin) / 10.0))
        crange = @lift($cmin:max($cstep, 1.0):$cmax)
    end


    md = metadata(var)
    # metadata for axes
    pd_names = name.(filter(d -> length(d) != 1, dims(var2d[]))) # 長さが1より大きい次元の名前
    x_name = md["Axis_long_name_"*String(pd_names[1])]
    y_name = md["Axis_long_name_"*String(pd_names[2])]
    x_unit = md["Axis_units_"*String(pd_names[1])]
    y_unit = md["Axis_units_"*String(pd_names[2])]
    x_label = x_name * " (" * x_unit * ")"
    y_label = y_name * " (" * y_unit * ")"
    x_positive = md["Axis_positive_"*String(pd_names[1])]
    y_positive = md["Axis_positive_"*String(pd_names[2])]
    title = md["long_name"]

    # metadata for colorbar
    if haskey(md, "var_desc")
        cb_label = md["var_desc"] * " (" * md["units"] * ")"
    else
        cb_label = md["name"] * " (" * md["units"] * ")"
    end


    fig = Figure()
    if map == false
        ax = Axis(fig[1, 1], xlabel=x_label, ylabel=y_label, title=title, aspect=aspect,
            xticks=LinearTicks(7), yticks=LinearTicks(7))
    else
        ax = GeoAxis(fig[1, 1], dest=mdest, source="+proj=latlong +datum=WGS84", xlabel=x_label, ylabel=y_label,
            title=title, aspect=aspect)
    end
    if xrange isa StepRange
        xlims!(ax, first(xrange), last(xrange))
        ax.xticks = collect(xrange)
    elseif xrange isa AbstractRange
        xlims!(ax, first(xrange), last(xrange))
    end
    if yrange isa StepRange
        ylims!(ax, first(yrange), last(yrange))
        ax.yticks = collect(yrange)
    elseif yrange isa AbstractRange
        ylims!(ax, first(yrange), last(yrange))
    end


    Makie.tightlimits!(ax)
    if y_positive == "down"
        ax.yreversed = true
    end


    # 巨大ファイル対応 (GLMakeiは1辺が20000点を超えると落ちる)
    nmax = maximum(size(var2d[]))  # 軸の中で最多の点数を取得
    if nmax < 20000
        if plot_type == :heatmap
            pl = heatmap!(ax, @lift(dd($var2d)); colorrange=minmax, colormap=cmap)
            # elseif plot_type == :image
            #     pl = image!(ax, @lift(dd($var2d)); colorrange=minmax, colormap=cmap)
        elseif plot_type == :contourf
            pl = contourf!(ax, @lift(dd($var2d)); levels=crange, colormap=cmap)
        elseif plot_type == :contour
            if String(cmap) in keys(Colors.color_names) # 単色指定
                pl = contour!(ax, @lift(dd($var2d)); levels=crange, color=cmap, labels=true)
            else # カラーマップ指定
                pl = contour!(ax, @lift(dd($var2d)); levels=crange, colormap=cmap, labels=true)
            end
        elseif plot_type == :surface
            pl = surface!(ax, @lift(shift_for_geomap(dd($var2d))); colorrange=minmax, colormap=cmap, shading=NoShading, depth_shift=1)
        end
        Label(fig[end+1, 1], @lift(label_singlton_dims($var2d)); tellwidth=false, tellheight=true, halign=:right, height=16, justification=:right)

        if plot_type in (:heatmap, :contourf, :surface)
            if aspect > 1
                cb = Colorbar(fig[end+1, 1], pl; vertical=false, flipaxis=false,
                    label=cb_label, tellwidth=false)
            else
                cb = Colorbar(fig[1, end+1], pl; label=cb_label, tellheight=false)
            end
        end
    else
        n = Integer(ceil(nmax / 20000))
        # 縦横それぞれ n 分割する
        imax, jmax = size(dd(var2d[]))
        iint, jint = Integer(ceil(imax / n)), Integer(ceil(jmax / n))
        minval = minimum(var2d[])
        maxval = maximum(var2d[])
        pl = []
        for j in 0:(n-1)
            for i in 0:(n-1)
                ist, jst = max(1, 1 + iint * i - 1), max(1, 1 + jint * j - 1) # 1つ分オーバーラップ
                ied, jed = min(iint * (i + 1), imax), min(jint * (j + 1), jmax)
                #        heatmap!(ax, var[ist:ied, jst:jed]; colorrange=(minval, maxval))
                pln = image!(ax, dd(var2d[])[ist:ied, jst:jed]; colorrange=(minval, maxval), colormap=cmap)
                push!(pl, pln)
            end
        end
        Label(fig[end+1, 1], label_singlton_dims(var2d[]); tellwidth=false, tellheight=true, halign=:right, height=16, justification=:right)
        if aspect > 1
            cb = Colorbar(fig[end+1, :], pl[1]; vertical=false, flipaxis=false,
                label=cb_label, tellwidth=false)
        else
            cb = Colorbar(fig[:, end+1], pl[1]; label=cb_label, tellheight=false)
        end
    end

    label_misc(fig, plot_type, md)

    display(fig)
    add_minor_ticks(ax)


    if anim isa Symbol
        if asave isa String
            stream = VideoStream(fig; format="mp4", framerate=Integer(round(1.0 / aint)))
            recordframe!(stream)
        end

        imax = length(dims(var, anim))
        # アニメーションの状態をまとめる
        state = (frame=Observable(1), play=Observable(true), quit=Observable(false), rewind=Observable(false))
        cond = Condition()
        # do構文の中身が関数として、register_player_keysの第1引数として渡される。
        register_player_keys(fig, state, imax, cond) do frame
            var2d[] = getindex(var; anim => frame:frame)
        end

        # 再生ループ と キーボード操作処理（GLMakie）
        while !state.quit[]
            if state.play[]
                state.frame[] += 1
                if state.frame[] > imax
                    break
                end
                var2d[] = getindex(var; anim => state.frame[]:state.frame[])
                if asave isa String
                    recordframe!(stream)
                else
                    sleep(float(aint))
                end
            elseif state.rewind[]
                state.frame[] -= 1
                if state.frame[] < 1
                    break
                end
                var2d[] = getindex(var; anim => state.frame[]:state.frame[])
                if asave isa String
                    recordframe!(stream)
                else
                    sleep(float(aint))
                end
            else
                wait(cond)
            end
        end
        asave isa String && save(asave, stream)
    end
    return fig, ax, pl
end

function draw1D(vars, plot_type::Symbol; aspect=2, exch=false, xrange=nothing, yrange=nothing,
    xscale=identity, yscale=identity, anim=false, aint=0.2, asave=false, labels=false, legend=:rb)

    if vars isa Tuple
        var = vars[1]
        labels == false && (labels = map(string, collect(1:1:20)))
    else
        var = vars
    end


    if anim isa Symbol
        var1d = Observable(getindex(var; anim => 1:1))
    else
        var1d = Observable(var)
    end

    md = metadata(var)
    # metadata for axes
    pd_names = name.(filter(d -> length(d) != 1, dims(var1d[]))) # 長さが1より大きい次元の名前
    x_name = md["Axis_long_name_"*String(pd_names[1])]
    x_unit = md["Axis_units_"*String(pd_names[1])]
    x_label = x_name * " (" * x_unit * ")"
    x_positive = md["Axis_positive_"*String(pd_names[1])]
    if haskey(md, "var_desc")
        y_label = md["var_desc"] * " (" * md["units"] * ")"
    else
        y_label = md["name"] * " (" * md["units"] * ")"
    end
    title = md["long_name"]

    fig = Figure()
    #    Makie.tightlimits!(ax)
    if exch == false
        ax = Axis(fig[1, 1], xlabel=x_label, ylabel=y_label, title=title, aspect=aspect, xscale=xscale, yscale=yscale, xticks=LinearTicks(7), yticks=LinearTicks(7))
        if !(yrange isa AbstractRange)
            ymin = @lift(floor(minimum($var1d), sigdigits=2))
            ymax = @lift(ceil(maximum($var1d), sigdigits=2))
            @lift (ylims!(ax, $ymin, $ymax))
        end
    else # x-y軸の入れ替え
        ax = Axis(fig[1, 1], xlabel=y_label, ylabel=x_label, title=title, aspect=aspect, xscale=xscale, yscale=yscale, xticks=LinearTicks(7), yticks=LinearTicks(7))
        if !(xrange isa AbstractRange)
            xmin = @lift(floor(minimum($var1d), sigdigits=2))
            xmax = @lift(ceil(maximum($var1d), sigdigits=2))
            @lift (xlims!(ax, $xmin, $xmax))
        end
    end

    xscale == log10 && (ax.xticks = nice_numbers(ax.xaxis.attributes[:limits][][1], ax.xaxis.attributes[:limits][][2]))
    yscale == log10 && (ax.yticks = nice_numbers(ax.yaxis.attributes[:limits][][1], ax.yaxis.attributes[:limits][][2]))
    if xrange isa StepRange
        xlims!(ax, first(xrange), last(xrange))
        ax.xticks = collect(xrange)
    elseif xrange isa AbstractRange
        xlims!(ax, first(xrange), last(xrange))
    end
    if yrange isa StepRange
        ylims!(ax, first(yrange), last(yrange))
        ax.yticks = collect(yrange)
    elseif yrange isa AbstractRange
        ylims!(ax, first(yrange), last(yrange))
    end

    if x_positive == "down"
        exch == false ? (ax.xreversed = true) : (ax.yreversed = true)
    end

    # axislegend()
    Label(fig[end+1, 1], @lift(label_singlton_dims($var1d)); tellwidth=false, tellheight=true, halign=:right, height=16, justification=:right)
    label_misc(fig, plot_type, md)

    if vars isa Tuple
        for i in 1:length(vars)
            if exch == false
                xval = dd(vars[i]).axes[1].val
                yval = dd(vars[i]).data
            else
                xval = dd(vars[i]).data
                yval = dd(vars[i]).axes[1].val
            end
            if plot_type == :lines
                pl = lines!(ax, xval, yval; label=labels[i])
            end
        end
        if !(legend == false)
            axislegend(position=legend)
        end
    else
        if exch == false
            xval = @lift(dd($var1d).axes[1].val)
            yval = @lift(dd($var1d).data)
        else
            xval = @lift(dd($var1d).data)
            yval = @lift(dd($var1d).axes[1].val)
        end
        if plot_type == :lines
            pl = lines!(ax, xval, yval)
        end
    end
    display(fig)
    add_minor_ticks(ax)

    if anim isa Symbol
        if asave isa String
            stream = VideoStream(fig; format="mp4", framerate=Integer(round(1.0 / aint)))
            recordframe!(stream)
        end

        imax = length(dims(var, anim))
        # アニメーションの状態をまとめる
        state = (frame=Observable(1), play=Observable(true), quit=Observable(false), rewind=Observable(false))
        cond = Condition()
        # do構文の中身が関数として、register_player_keysの第1引数として渡される。
        register_player_keys(fig, state, imax, cond) do frame
            var1d[] = getindex(var; anim => frame:frame)
        end

        # 再生ループ と キーボード操作処理（GLMakie）
        while !state.quit[]
            if state.play[]
                state.frame[] += 1
                if state.frame[] > imax
                    break
                end
                var1d[] = getindex(var; anim => state.frame[]:state.frame[])
                if asave isa String
                    recordframe!(stream)
                else
                    sleep(float(aint))
                end
            elseif state.rewind[]
                state.frame[] -= 1
                if state.frame[] < 1
                    break
                end
                var1d[] = getindex(var; anim => state.frame[]:state.frame[])
                if asave isa String
                    recordframe!(stream)
                else
                    sleep(float(aint))
                end
            else
                wait(cond)
            end
        end
        asave isa String && save(asave, stream)

        # Sキーで再生/一時停止（GLMakie）古いコード
        #     cond = Condition()
        #     play = false
        #     on(events(fig).keyboardbutton) do event
        #         if event.action == Keyboard.press && event.key == Keyboard.s
        #             notify(cond)
        #             play = true
        #         end
        #     end

        #     for i in 2:length(dims(var, anim))

        #         if play == true # Sキーで再生/一時停止（GLMakie）
        #             wait(cond)
        #             play = false
        #         end

        #         var1d[] = getindex(var; anim => i:i)
        #         if asave isa String
        #             recordframe!(stream)
        #         else
        #             sleep(float(aint))
        #         end
        #     end
        #     asave isa String && save(asave, stream)
    end
    return fig, ax, pl
end

function drawVect(var1, var2, plot_type=:arrows2d; aspect=2, exch=false, anim=false, aint=0.2, asave=false,
    map=false, skip=4, scale=0.5, xrange=nothing, yrange=nothing, cmap=:viridis)

    if anim isa Symbol
        u = Observable(getindex(var1; anim => 1:1))
        v = Observable(getindex(var2; anim => 1:1))
    else
        u = Observable(var1)
        v = Observable(var2)
    end

    md1 = metadata(var1)
    md2 = metadata(var2)
    # metadata for axes
    pd_names = name.(filter(d -> length(d) != 1, dims(u[]))) # 長さが1より大きい次元の名前
    x_name = md1["Axis_long_name_"*String(pd_names[1])]
    y_name = md1["Axis_long_name_"*String(pd_names[2])]
    x_unit = md1["Axis_units_"*String(pd_names[1])]
    y_unit = md1["Axis_units_"*String(pd_names[2])]
    x_label = x_name * " (" * x_unit * ")"
    y_label = y_name * " (" * y_unit * ")"
    x_positive = md1["Axis_positive_"*String(pd_names[1])]
    y_positive = md1["Axis_positive_"*String(pd_names[2])]
    title = "(" * md1["long_name"] * ", " * md2["long_name"] * ")"

    # metadata for colorbar
    if haskey(md1, "var_desc")
        cb_label = md1["var_desc"] * ", " * md2["var_desc"] * " (" * md1["units"] * ")"
    else
        cb_label = md1["name"] * ", " * md2["name"] * " (" * md1["units"] * ")"
    end

    fig = Figure()

    if map == false
        ax = Axis(fig[1, 1], xlabel=x_label, ylabel=y_label, title=title, aspect=aspect,
            xticks=LinearTicks(7), yticks=LinearTicks(7))
    else
        ax = GeoAxis(fig[1, 1], dest=mdest, source="+proj=latlong +datum=WGS84", xlabel=x_label, ylabel=y_label,
            title=title, aspect=aspect)
    end
    if xrange isa StepRange
        xlims!(ax, first(xrange), last(xrange))
        ax.xticks = collect(xrange)
    elseif xrange isa AbstractRange
        xlims!(ax, first(xrange), last(xrange))
    end
    if yrange isa StepRange
        ylims!(ax, first(yrange), last(yrange))
        ax.yticks = collect(yrange)
    elseif yrange isa AbstractRange
        ylims!(ax, first(yrange), last(yrange))
    end


    Makie.tightlimits!(ax)
    if y_positive == "down"
        ax.yreversed = true
    end

    if plot_type == :arrows2d
        data = @lift(data_for_arrows($u, $v, skip))
        x1 = @lift($data[1])
        x2 = @lift($data[2])
        v1 = @lift($data[3])
        v2 = @lift($data[4] * $data[5]) # 表示用のベクトル y 成分（子午面場にも対応）
        f2 = @lift($data[5])            # 作用させたファクター
        pl = arrows2d!(ax, x1, x2, v1, v2; markerspace=:pixel, shaftwidth=1.2, tipwidth=7, tiplength=5, lengthscale=scale)
        display(fig)
        v1_len = round(maximum(abs.(v1[] / 2)), sigdigits=1)
        v2_len = round(maximum(abs.(v2[] / f2[] / 2)), sigdigits=1) * f2[]
        arrow_legend(fig, ax, scale, v1_len, v2_len,
            string(v1_len) * " " * md1["units"], string(v2_len / f2[]) * " " * md2["units"])

    elseif plot_type == :streamplot
        data = @lift(data_for_arrows($u, $v, skip))
        x1 = @lift($data[1])
        x2 = @lift($data[2])
        v1 = @lift($data[3])
        v2 = @lift($data[4] * $data[5]) # 表示用のベクトル y 成分（子午面場にも対応）
        f2 = @lift($data[5])            # 作用させたファクター

        v1_itp = @lift(Interpolations.interpolate(($x1, $x2), $v1, Gridded(Linear())))   # 補間関数化
        v2_itp = @lift(Interpolations.interpolate(($x1, $x2), $v2, Gridded(Linear())))
        strm = @lift((p) -> Point2f($v1_itp(p[1], p[2]), $v2_itp(p[1], p[2]))) # ベクトル関数化

        pl = streamplot!(ax, strm, x1, x2; colormap=cmap, density=1, arrow_size=10, maxsteps=9E3, stepsize=0.05)

        if !isapprox(f2[], 1.0)
            cb_label = "|(" * md1["name"] * ", " * md2["name"] * ")| " * "(" * md1["units"] * ")" * " [" * md2["name"] * " is scaled]"
        else
            cb_label = "|(" * md1["name"] * ", " * md2["name"] * ")| " * "(" * md1["units"] * ")"
        end

        if aspect > 1
            cb = Colorbar(fig[end+1, :], pl; vertical=false, flipaxis=false,
                label=cb_label, tellwidth=false)
        else
            cb = Colorbar(fig[:, end+1], pl; label=cb_label, tellheight=false)
        end


    end
    Label(fig[end+1, 1], @lift(label_singlton_dims($u)); tellwidth=false, tellheight=true, halign=:right, height=16, justification=:right)
    label_misc(fig, plot_type, md1)

    display(fig)
    add_minor_ticks(ax)

    if anim isa Symbol
        if asave isa String
            stream = VideoStream(fig; format="mp4", framerate=Integer(round(1.0 / aint)))
            recordframe!(stream)
        end

        imax = length(dims(var1, anim))
        # アニメーションの状態をまとめる
        state = (frame=Observable(1), play=Observable(true), quit=Observable(false), rewind=Observable(false))
        cond = Condition()
        # do構文の中身が関数として、register_player_keysの第1引数として渡される。
        register_player_keys(fig, state, imax, cond) do frame
            u[] = getindex(var1; anim => frame:frame)
            v[] = getindex(var2; anim => frame:frame)
        end

        # 再生ループ と キーボード操作処理（GLMakie）
        while !state.quit[]
            if state.play[]
                state.frame[] += 1
                if state.frame[] > imax
                    break
                end
                u[] = getindex(var1; anim => state.frame[]:state.frame[])
                v[] = getindex(var2; anim => state.frame[]:state.frame[])
                if asave isa String
                    recordframe!(stream)
                else
                    sleep(float(aint))
                end
            elseif state.rewind[]
                state.frame[] -= 1
                if state.frame[] < 1
                    break
                end
                u[] = getindex(var1; anim => state.frame[]:state.frame[])
                v[] = getindex(var2; anim => state.frame[]:state.frame[])
                if asave isa String
                    recordframe!(stream)
                else
                    sleep(float(aint))
                end
            else
                wait(cond)
            end
        end
        asave isa String && save(asave, stream)
    end

    return fig, ax, pl

end


# 長さ1の次元情報のラベル用文字列を生成する
function label_singlton_dims(var::YAXArray)
    md = metadata(var)
    dd_names = name.(filter(d -> length(d) == 1, dims(var))) # 長さ1の次元の名前
    dd_units = map(x -> begin
            unit = md["Axis_units_"*String(x)]
            if (occursin("since", unit))
                ""
            else
                " " * unit
            end
        end, dd_names) # 長さ1の次元の単位
    ddims = dims(var, dd_names)
    dd_label = ""
    for i in 1:length(dd_names)
        if ddims[i].val[1] isa AbstractArray
            slice_val = string(ddims[i].val[1][1], "–", ddims[i].val[1][end])
        else
            slice_val = values(ddims[i]).val[1]
        end
        dd_label *= string(dd_names[i], " = ", slice_val, dd_units[i], "\n")
    end
    return dd_label
end

function label_misc(fig, plot_type, md)
    # Labels
    Label(fig[0, :], Dates.format(now(), "yyyy-mm-dd HH:MM"); tellwidth=false, fontsize=10.0, halign=:right, height=0)
    Label(fig[0, :], md["file_path"]; tellwidth=false, fontsize=10.0, halign=:left, height=0)
    if haskey(md, "operation")
        Label(fig[end+1, :], "Operation: " * md["operation"]; tellwidth=false, fontsize=10.0, halign=:right, height=0)
    end
    if haskey(md, "cut")
        Label(fig[end+1, :], md["cut"]; tellwidth=false, fontsize=10.0, halign=:right, height=0)
    end
    # 図に残すメタデータ
    fig.attributes[:operation] = haskey(md, "operation") ? md["operation"] : ""
    fig.attributes[:file] = md["file_path"]
    fig.attributes[:draw] = string(plot_type) * " with " #TODO kwargs情報を付加する
end

# minor ticks を上手に描画する
function add_minor_ticks(ax)
    if ax.xscale[] != log10
        dx = first_two_significant_digits(ax.xaxis.tickvalues[][2] - ax.xaxis.tickvalues[][1])
        if dx % 7 == 0
            ax.xminorticks = IntervalsBetween(7, true)
        elseif dx % 6 == 0
            ax.xminorticks = IntervalsBetween(3, true)
        elseif dx % 5 == 0
            ax.xminorticks = IntervalsBetween(5, true)
        elseif dx % 4 == 0
            ax.xminorticks = IntervalsBetween(4, true)
        elseif dx % 3 == 0
            ax.xminorticks = IntervalsBetween(3, true)
        else
            ax.xminorticks = IntervalsBetween(2, true)
        end
        ax.xminorticksvisible = true
    end
    if ax.yscale[] != log10
        dy = first_two_significant_digits(ax.yaxis.tickvalues[][2] - ax.yaxis.tickvalues[][1])
        if dy % 7 == 0
            ax.yminorticks = IntervalsBetween(7, true)
        elseif dy % 6 == 0
            ax.yminorticks = IntervalsBetween(3, true)
        elseif dy % 5 == 0
            ax.yminorticks = IntervalsBetween(5, true)
        elseif dy % 4 == 0
            ax.yminorticks = IntervalsBetween(4, true)
        elseif dy % 3 == 0
            ax.yminorticks = IntervalsBetween(3, true)
        else
            ax.yminorticks = IntervalsBetween(2, true)
        end
        ax.yminorticksvisible = true
    end
end

# 図をpngまたはpdfで保存して、外部ツールをつかって、コメントをメタデータとして書き込む。
function save_fig(fname="makie.png"::String, fig=current_figure()::Figure)
    save(fname, fig)
    comment =
        "File: " * fig.attributes[:file].val * "\n" *
        #"Cut: " * fig.attributes[:cut].val * "\n" *
        "Operation: " * fig.attributes[:operation].val * "\n" *
        "Draw: " * fig.attributes[:draw].val * "\n"
    if fname[end-2:end] == "png"
        run(`mogrify -set comment "$comment" $fname`)
    elseif fname[end-2:end] == "pdf"
        run(`exiftool -overwrite_original -Title="$comment" $fname`)
    end
end

# アニメーションのキーボード操作のための関数
function register_player_keys(update_func, fig, state, imax, cond)
    on(events(fig).keyboardbutton) do event
        if event.action != Keyboard.press
            return
        end
        if event.key == Keyboard.s
            state.play[] = !state.play[]
            state.rewind[] = false
            notify(cond)
        elseif event.key == Keyboard.r
            state.rewind[] = !state.rewind[]
            state.play[] = false
            notify(cond)
        elseif event.key == Keyboard.right
            state.frame[] = min(state.frame[] + 1, imax)
            update_func(state.frame[])
        elseif event.key == Keyboard.left
            state.frame[] = max(state.frame[] - 1, 1)
            update_func(state.frame[])
        elseif event.key == Keyboard.q
            state.quit[] = true
            notify(cond)
        end
    end
end

# lonの範囲を -180:180 に変換した後に、東西方向に1周分のデータがある場合は、
# lon = 180 の点を lon = -180 をコピーして追加する。
# GeoMakieでの描画のため
function shift_for_geomap(var::YAXArray; lonname=:lon)
    # lon軸取得
    lon_dim = dims(var, lonname)
    lon_old = collect(lookup(lon_dim))
    # 格子間隔
    dlon = lon_old[2] - lon_old[1]
    # 0:360 -> -180:180
    lon_new = mod.(lon_old .+ 180, 360) .- 180
    # 昇順並べ替え
    perm = sortperm(lon_new)
    lon_new = lon_new[perm]
    # lon次元番号
    dim_index = findfirst(name.(dims(var)) .== lonname)
    # データ並べ替え
    inds = ntuple(i -> Colon(), ndims(var))  # Colon()は : を表す
    inds = Base.setindex(inds, perm, dim_index) # (perm, :, :, :) を返す
    var_new = var[inds...]
    data_new = var_new.data
    if isapprox(lon_new[end] + dlon, lon_new[1] + 360.0)    # cyclic判定
        lon_new = vcat(lon_new, lon_new[end] + dlon)
        first_slice = selectdim(data_new, dim_index, 1:1)
        data_new = cat(data_new, first_slice; dims=dim_index)
    end
    # 新しい軸
    new_dims = collect(dims(var_new))
    new_dims[dim_index] = rebuild(lon_dim; val=lon_new)
    return YAXArray(Tuple(new_dims), data_new, metadata(var))
end

function arrow_legend(fig, ax1, scale, xlen, ylen, xlabel, ylabel; l_aspect=0.2)
    m_aspect = ax1.aspect[] #不定の場合はどうする？
    ax2 = Axis(fig[1, 2], aspect=l_aspect, xticklabelsvisible=false, yticklabelsvisible=false,
        xlabelvisible=true, ylabelvisible=false, xticksvisible=false, yticksvisible=false,
        xgridvisible=false, ygridvisible=false, tellwidth=false, tellheight=false)
    l_colsize = (m_aspect + l_aspect) / l_aspect
    colsize!(fig.layout, 2, Relative(1 / l_colsize))
    colgap!(fig.layout, 2)
    #linkyaxes!(ax1, ax2)
    hidedecorations!(ax2)
    hidespines!(ax2)
    width = ax1.xaxis.attributes[:limits][][2] - ax1.xaxis.attributes[:limits][][1]
    l_width = width / (m_aspect / l_aspect)
    height = ax1.yaxis.attributes[:limits][][2] - ax1.yaxis.attributes[:limits][][1]
    xlims!(ax2, 0, l_width)
    ylims!(ax2, 0, height)
    arrows2d!(ax2, [Point2f(l_width / 4, height / 10)], [Vec2f(xlen, 0)], lengthscale=scale, shaftwidth=1.2, tipwidth=7, tiplength=5)
    text!(ax2, l_width / 4, height / 11, text=xlabel, align=(:left, :top), fontsize=9)
    arrows2d!(ax2, [Point2f(l_width / 4, height / 10)], [Vec2f(0, ylen)], lengthscale=scale, shaftwidth=1.2, tipwidth=7, tiplength=5)
    text!(ax2, l_width / 5, height / 10, text=ylabel, align=(:left, :bottom), fontsize=9, rotation=pi / 2)
    #Label(fig[1, 2], label, fontsize=12, tellwidth=false, tellheight=false, halign=:center, justification=:center, valign=:bottom, padding=15)
    if m_aspect <= 1
        resize!(fig.scene, 500 * m_aspect, 500)
    end

end
