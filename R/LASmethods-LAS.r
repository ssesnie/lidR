# ===============================================================================
#
# PROGRAMMERS:
#
# jean-romain.roussel.1@ulaval.ca  -  https://github.com/Jean-Romain/lidR
#
# COPYRIGHT:
#
# Copyright 2016-2018 Jean-Romain Roussel
#
# This file is part of lidR R package.
#
# lidR is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# ===============================================================================

#' Create objects of class \link[lidR:LAS-class]{LAS}
#'
#' @param data a \link[data.table:data.table]{data.table} containing the data of a las or laz file.
#' @param header a \code{list} or a \link[lidR:LASheader-class]{LASheader} containing the header of
#' a las or laz file.
#' @param proj4string projection string of class \link[sp:CRS-class]{CRS-class}.
#' @param check logical. conformity tests while building the object.
#' @return An object of class \code{LAS}
#' @export
LAS <- function(data, header = list(), proj4string = sp::CRS(), check = TRUE)
{
  if(is.data.frame(data))
    data.table::setDT(data)

  if(!data.table::is.data.table(data))
    stop("Invalid parameter data in constructor.", call. = FALSE)

  if (nrow(data) > 0)
  {
    if (check) rlas::check_data(data)
    if (is(header, "LASheader")) header = as.list(header)

    if(is.list(header))
    {
      if (length(header) == 0)
      {
        header = rlas::header_create(data)
        check = FALSE
      }
    }
    else
      stop("Wrong header object provided.", call. = FALSE)

    header = rlas::header_update(header, data)
  }
  else
  {
    if (check) suppressWarnings(rlas::check_data(data))
    if (is(header, "LASheader")) header = as.list(header)

    if(is.list(header))
    {
      if (length(header) == 0)
      {
        header = suppressWarnings(rlas::header_create(data))
        check = FALSE
      }
    }
    else
      stop("Wrong header object provided.", call. = FALSE)

    header = suppressWarnings(rlas::header_update(header, data))
    header$`Min X` <- 0
    header$`Max X` <- 0
    header$`Min Y` <- 0
    header$`Max Y` <- 0
    header$`Min Z` <- 0
    header$`Max Z` <- 0
    header$`X offset` <- 0
    header$`Y offset` <- 0
    header$`Z offset` <- 0
  }

  if(check & nrow(data) > 0)
  {
    rlas::check_header(header)
    rlas::check_data_vs_header(header, data, hard = F)
  }

  header <- LASheader(header)

  if(is.na(proj4string@projargs))
    proj4string <- epsg2proj(get_epsg(header))

  las <- new("LAS")
  las@proj4string <- proj4string
  las@bbox        <- with(header@PHB, matrix(c(`Min X`, `Min Y`, `Max X`, `Max Y`), ncol = 2, dimnames = list(c("x", "y"), c("min", "max"))))
  las@header      <- header
  las@data        <- data

  return(las)
}

if (!isGeneric("summary"))
  setGeneric("summary", function(object, ...)
    standardGeneric("summary"))

if (!isGeneric("print"))
  setGeneric("print", function(x, ...)
    standardGeneric("print"))

if (!isGeneric("plot"))
  setGeneric("plot", function(x, y, ...)
    standardGeneric("plot"))

if (!isGeneric("is.empty"))
  setGeneric("is.empty", function(object, ...)
    standardGeneric("is.empty"))


setMethod("show", "LAS", function(object)
{
  size <- format(utils::object.size(object), units = "auto")
  surf <- area(object)
  npts <- nrow(object@data)
  dpts <- if(surf > 0) npts/surf else 0
  attr <- names(object@data)
  ext  <- raster::extent(object)
  phb  <- object@header@PHB

  cat("class        : LAS (", phb$`File Signature`, " v", phb$`Version Major`, ".", phb$`Version Minor`, ")\n", sep = "")
  cat("point format : ", phb$`Point Data Format ID`, "\n", sep = "")
  cat("memory       :", size, "\n")
  cat("extent       :", ext@xmin, ",", ext@xmax, ",", ext@ymin, ",", ext@ymax, "(xmin, xmax, ymin, ymax)\n")
  cat("coord. ref.  :", object@proj4string@projargs, "\n")
  cat("area         :", surf, "unit\u00B2 (convex hull)\n")
  cat("points       :", npts, "points\n")
  cat("density      :", round(dpts, 2), "points/unit\u00B2\n")
  cat("names        :", attr, "\n")
})

#' @export
is.empty.LAS <- function(object, ...)
{
  empty = if (nrow(object@data) == 0) TRUE else FALSE
  return(empty)
}

#' @export
setMethod("is.empty", "LAS", is.empty.LAS)

summary.LAS <- function(object, ...)
{
  print(object)
  print(object@header)
}

setMethod("summary", "LAS", summary.LAS)

print.LAS <- function(x, ...)
{
  show(x)
}

setMethod("print", "LAS", print.LAS)

#' Plot LiDAR data
#'
#' This functions implements a 3D plot method for LAS objects
#'
#' @aliases plot plot.LAS
#' @param x An object of the class \code{LAS}
#' @param y Unused (inherited from R base)
#' @param color characters. The field used to color the points. Default is Z coordinates.
#' @param colorPalette characters. a list of colors such as that generated by heat.colors,
#' topo.colors, terrain.colors or similar functions.  Default is \code{height.colors(50)}
#' provided by the package \code{lidR}
#' @param bg The color for the background. Default is black.
#' @param trim numeric. Enables trimming of values when outliers break the color palette range.
#' Default is 1, meaning that the whole range of values is used for the color palette.
#' 0.9 means that 10\% of the highest values are not used to define the color palette.
#' In this case values higher than the 90th percentile are set to the highest color.
#' They are not removed.
#' @param backend character. Can be \code{"rgl"} or \code{"pcv"}. If \code{"rgl"} is chosen
#' the display relies on the \code{rgl} package. If \code{"pcv"} is chosen it relies on the
#' \code{PointCloudViewer} package which is much more efficient and can handle million of points
#' using few memory. \code{PointCloudViewer} is not available on CRAN yet and should
#' be install from github (see. \url{https://github.com/Jean-Romain/PointCloudViewer}).
#' @param \dots Supplementary parameters for \link[rgl:points3d]{points3d}
#' @examples
#' LASfile <- system.file("extdata", "Megaplot.laz", package="lidR")
#' lidar = readLAS(LASfile)
#'
#' plot(lidar)
#'
#' # Outliers of intensity breaks the color range. Use the trim parameter.
#' plot(lidar, color = "Intensity", colorPalette = heat.colors(50))
#' plot(lidar, color = "Intensity", colorPalette = heat.colors(50), trim = 0.99)
#' @seealso
#' \link[rgl:points3d]{points3d}
#' \link[lidR:height.colors]{height.colors}
#' \link[lidR:forest.colors]{forest.colors}
#' \link[grDevices:heat.colors]{heat.colors}
#' \link[grDevices:colorRamp]{colorRampPalette}
#' \link[lidR:LAS]{Class LAS}
#' @method plot LAS
#' @export
plot.LAS = function(x, y, color = "Z", colorPalette = height.colors(50), bg = "black", trim = 1, backend = c("rgl", "pcv"), ...)
{
  if (is.empty(x))
    stop("Cannot display an empty point cloud", call. = FALSE)

  if (!is.character(color))
    color = lazyeval::expr_text(color)

  backend = match.arg(backend)
  pcv = "PointCloudViewer" %in% rownames(utils::installed.packages())

  if (backend == "pcv" & !pcv)   stop("'PointCloudViewer' package is needed. Please read documentation.", call. = F)
  if(length(color) > 1)          stop("'color' should contains a single value.", call. = F)
  if(!is.character(color))       stop("'color' should be of type character.", call. = F)
  if(! color %in% names(x@data)) stop("'color' should refer to a colunm of the LAS data.", call. = F)

  if (color == "Z")
    coldata = x@data$Z
  else if (color == "Intensity")
    coldata = x@data$Intensity
  else if (color == "color" & pcv)
    coldata = "rgb"
  else if (color == "color" & !pcv)
    coldata = x@data$color
  else if (color == "rgb" | color == "RGB")
  {
    if(pcv)
      coldata  = "rgb"
    else
      stop("Option 'rgb' not supported for rgl yet. Use 'color' instead.", call. = FALSE)
  }
  else
    coldata = unlist(x@data[,color, with = FALSE])

  inargs = list(...)
  if(is.null(inargs$size))
    inargs$size = 1.5

  if (backend == "rgl")
  {
    if(is.numeric(coldata))
      inargs$col = set.colors(coldata, colorPalette, trim)
    else if(is.character(coldata))
      inargs$col = coldata
    else if(is.logical(coldata))
      inargs$col = set.colors(as.numeric(coldata), colorPalette)

    inargs$col[is.na(inargs$col)] = "lightgray"

    .plot_with_rgl(x, bg, coldata, inargs)
  }
  else
    .plot_with_pcv(x, coldata, colorPalette, inargs)

  return(invisible())
}

setMethod("plot", signature(x = "LAS", y = "missing"), function(x,y,...) plot.LAS(x,...))


setReplaceMethod("$", "LAS", function(x, name, value)
{

  if (! name %in% names(x@data))
    stop("Addition of a new column using $ is forbidden for LAS objects. See ?lasadddata", call. = FALSE)

  x@data[, (name) := value][]
  return(x)
})

.plot_with_rgl = function(x, bg, coldata, inargs)
{
  rgl::open3d()
  rgl::rgl.bg(color = bg)
  do.call(rgl::points3d, c(list(x=x@data$X, y=x@data$Y, z=x@data$Z), inargs))

  return(invisible())
}

.plot_with_pcv = function(x, coldata, colors, inargs)
{
  if (is.character(coldata) && coldata == "rgb")
  {
    # Dirty trick to avoid R CMD check complaining with unexisting package...
    eval(parse(text="PointCloudViewer::plot_xyzrgb(x@data$X, x@data$Y, x@data$Z, x@data$R, x@data$G, x@data$B, inargs$size)"))
  }
  else
  {
    id = cut(coldata, length(colors), labels = FALSE)
    eval(parse(text="PointCloudViewer::plot_xyzcol(x@data$X, x@data$Y, x@data$Z, colors, id, inargs$size)"))
  }
}