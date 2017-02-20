# ===============================================================================
#
# PROGRAMMERS:
#
# jean-romain.roussel.1@ulaval.ca  -  https://github.com/Jean-Romain/lidR
#
# COPYRIGHT:
#
# Copyright 2016 Jean-Romain Roussel
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



#' Plot an object of class lashexametrics in 2D
#'
#' This functions implements a plot method for \code{lashexametrics} data.table
#'
#' @param x A data.table of class \code{lashexametrics}.
#' @param z character. The field to plot. If NULL, autodetect.
#' @param colorPalette characters. A list of colors such as that generated by heat.colors,
#' topo.colors, terrain.colors or similar functions.  Default is \code{height.colors(50)}
#' provided by the package \code{lidR}
#' @param ... inherited from base
#' @examples
#' LASfile <- system.file("extdata", "Megaplot.laz", package="lidR")
#' lidar = readLAS(LASfile)
#'
#' # Max Z within
#' grid_hexametrics(lidar, max(Z), 5) %>% plot
#' @seealso
#' \link[lidR:grid_metrics]{grid_metrics}
#' \link[grDevices:heat.colors]{heat.colors}
#' @export
#' @method plot lashexametrics
plot.lashexametrics = function(x, z = NULL, colorPalette = height.colors(50), ...)
{
  if(is.null(z))
  {
    if(length(names(x)) > 3)
      lidRError("GDM1")
    else
      z = names(x)[3]
  }

  res = attr(x, "res")
  half_res = res/2

  x_ = x$X
  y_ = x$Y
  z_ = x[,z, with = FALSE] %>% unlist %>% as.numeric

  col = set.colors(z_, colorPalette)

  graphics::plot(
     x = mean(x_),
     y = mean(y_),
     type = "n",
     axes = TRUE,
     xlim=c(min(x_)-half_res, max(x_)+half_res),
     ylim=c(min(y_)-half_res, max(y_)+half_res),
     xlab="X", ylab= "Y",
     asp=1, xaxs="i", yaxs="i")

  for(i in 1:length(x_))
    hexagon(x_[i], y_[i], r = half_res, col = col[i])
}

hexagon <- function (x, y, r = 1, col = col)
{
  cpi6 = cos(pi/6)
  spi6 = sin(pi/6)

  graphics::polygon(
          x = c(x - r*cpi6,
                x - r*cpi6,
                x,
                x + r*cpi6,
                x + r*cpi6,
                x),
          y = c(y - r * spi6,
                y + r * spi6,
                y + r,
                y + r * spi6,
                y - r * spi6,
                y - r),
          col = col, border= col)
}
