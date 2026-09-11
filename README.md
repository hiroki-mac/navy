# NAVY
Julia library for N-dimensional data Analysis and Visualization using YAXarrays and Makie

## Dependence
- YAXArrays.jl
- DimensionalData.jl
- NetCDF.jl
- Makie.jl
- GeoMakie.jl
- etc.

## To use
```
 include("PATH to src/navy_main.jl")
```
## Load NetCDF data
```
 var = open_nc("PATH to NetCDF file")
```
## Visualization
### 2D plot
```
 fig, ax, pl = draw2D(var, :plot_type; options)
```
*input*
- `var` is a 2D YAXArray object (or 3D if animation) loaded by `open_nc()`
- `:plot_type` should be `:heatmap`, `:contourf`, `:contour`, or `:surface`
- options [default]:
  - `aspect`: aspect ration of the plot [2]
  - `crange`: range of color tone or contours [nothing]
  - `cmap`: colormap [:jet]
    - colormap list: https://docs.makie.org/stable/explanations/colors#Colormaps
  - `anim`: axis for animation [false]
  - `aint`: time-interval for animation [0.2]
  - `asave`: file name for saving animation [false]
  - `map`: flag for map projection [false]
    - list: https://proj.org/en/stable/operations/projections/all_images.html
  - `mdest`: key strings for map projection [*proj=ortho]
  - `xrange`: range for x axis [nothing]
  - `yrange`: range for y axis [nothing]

*output*
- `fig`: Figure object
- `ax`: Axis object
- `plot`: Plot object

### 1D plot
```
 fig, ax, pl = draw1D(var, :plot_type; options)
```
*input*
- `var` is a 1D YAXArray object (or 2D if animation) loaded by `open_nc()`
- `:plot_type` should be `:lines`
- options:
  - `aspect`: aspect ration of the plot [2]
  - `exch`: exchange x and y axes [false]
  - `xrange`: range for x axis [nothing]
  - `yrange`: range for y axis [nothing]
  - `xscale`: scale for x axis [identity]
  - `yscale`: scale for y axis [identity]
  - `anim`: axis for animation [false]
  - `aint`: time-interval for animation [0.2]
  - `asave`: file name for saving animation [false]
  - `labels`: label for each plot [false]
  - `legend`: position of the legend [:rb]
     
*output*
- `fig`: Figure object
- `ax`: Axis object
- `plot`: Plot object

## Vector plot
```
 fig, ax, pl = drawVect(var1, var2, :plot_type; options)
```
*input*
- `var1` is a 2D YAXArray object (or 3D if animation) for x-component of vectors loaded by `open_nc()`
- `var2` is a 2D YAXArray object (or 3D if animation) for y-component of vectors loaded by `open_nc()`
- `:plot_type` should be `:arrows2d` or `streamplot`
- options:
  - `aspect`: aspect ration of the plot [2]
  - `exch`: exchange x and y axes [false]
  - `anim`: axis for animation [false]
  - `aint`: time-interval for animation [0.2]
  - `asave`: file name for saving animation [false]
  - `map`: map projection [false]
  - `skip`: interval for picking data to use [4]
  - `scale`: scale for arrows
  - `xrange`: range for x axis [nothing]
  - `yrange`: range for y axis [nothing]
  - `cmap`: colormap [:viridis]

*output*
- `fig`: Figure object
- `ax`: Axis object
- `plot`: Plot object

### Saving figures
```
save_fig("FILE_NAME")
```
- External tools (`mogrifyP` and `exiftool`) are used to write metadata into the figure file.

## Analysis
### operation with dimension drops
```
 new_var = ope(func, var; dims=false, drop=false)
```
*input* 
- `func`: function to operate. `mean`, `median`, `middle`, `std`, `var`, `maximum`, `minimum`, or `sum`
- `var`: YAXArray object
- `dims`: axis for applying the function
- `drop`: drop applied axis or not

### integration
```
 new_var = integral(var; dims=false, drop=false)
```
*input* 
- `var`: YAXArray object
- `dims`: axis for integration
- `drop`: drop applied axis or not
