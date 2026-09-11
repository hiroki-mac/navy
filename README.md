# navy
Julia library for N-dimensional data Analysis and Visualization using YAXarrays and Makie

## Dependence
- YAXArrays.jl
- DimensionalData.jl
- NetCDF.jl
- Makie.jl
- GeoMakie.jl
- etc.

## Usage
```
 include("PATH to src/navy_main.jl")
```
### Load NetCDF data
```
 var = open_nc("PATH to NetCDF file")
```
### 2D plot
```
 fig, ax, pl = draw2D(var, :plot_type; options)
```
*input*
- `var` is a 2D YAXArray object (or 3D if animation) loaded by `open_nc()`
- `:plot_type` should be `:heatmap`, `:contourf`, `:contour`, or `:surface`
- options:
  - `aspect`
  - `crange`
  - `cmap`
  - `anim`
  - `aint`
  - `asave`
  - `map`
  - `mdest`
  - `xrange`
  - `yrange`

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
  - `aspect`
  - `exch`
  - `xrange`
  - `yrange`
  - `xscale`
  - `yscale`
  - `anim`
  - `aint`
  - `asave`
  - `labels`
  - `legend`
    
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
  - `aspect`
  - `exch`
  - `anim`
  - `aint`
  - `asave`
  - `map`
  - `skip`
  - `scale`
  - `xrange`
  - `yrange`
  - `cmap`

*output*
- `fig`: Figure object
- `ax`: Axis object
- `plot`: Plot object

## Saving figures
```
save_fig("FILE_NAME")
```
- External tools (`mogrifyP` and `exiftool`) are used to write metadata into the figure file.
