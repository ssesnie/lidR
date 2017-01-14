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



#' Digital Terrain Model
#'
#' Interpolate ground points and create a rasterized digital terrain model. The interpolation
#' can be done using 3 methods: \code{"knnidw"}, \code{"delaunay"} or \code{"kriging"} (see
#' details). The algorithm uses the points classified as "ground" to compute the interpolation.
#' The function forces the original lowest ground point of each pixel (if it exists) to be
#' chosen instead of the interpolated values.
#'
#' \describe{
#' \item{\code{knnidw}}{Interpolation is done using a k-nearest neighbour (KNN) approach with
#' an inverse distance weighting (IDW). This is fast but also basic method for spatial
#' data interpolation.}
#' \item{\code{delaunay}}{Interpolation based on Delaunay triangulation using \link[akima:interp]{interp}
#' function from package \code{akima}. This method is very fast. It makes a linear interpolation
#' within each triangle. Notice that with this method no extrapolation is done outside of the
#' convex hull determined by the ground points.}
#' \item{\code{kriging}}{Interpolation is done by universal kriging using \link[gstat:krige]{krige}
#' function. This method mix the KNN approach and the kriging approach. For each point of interest
#' it kriges the terrain using the k-nearest neighbours ground points. This method is more difficult
#' to manipulate but it is also the most advanced method to interpolate spatial data. }
#' }
#' @param .las LAS objet
#' @param res numeric resolution.
#' @param method character can be \code{"knnidw"}, \code{"delaunay"} or \code{"kriging"} (see details)
#' @param k numeric. number of k nearest neibourgh when selected method is \code{"knnidw"} or \code{"kriging"}
#' @param model a variogram model computed with \link[gstat:vgm]{vgm} when selected method is
#' \code{"kriging"}. If null it performed an ordinary or weighted least squares prediction.
#' @return A \code{RasterLayer} from package raster
#' @export
#' @examples
#' LASfile <- system.file("extdata", "Topography.laz", package="lidR")
#' lidar = readLAS(LASfile)
#' plot(lidar)
#'
#' dtm1 = grid_terrain(lidar, method = "knnidw", k = 6)
#' dtm2 = grid_terrain(lidar, method = "delaunay")
#' dtm3 = grid_terrain(lidar, method = "kriging", k = 10)
#'
#' \dontrun{
#' raster::plot(dtm1, col = height.colors(50))
#' raster::plot(dtm2, col = height.colors(50))
#' raster::plot(dtm3, col = height.colors(50))
#' plot3d(dtm1)
#' plot3d(dtm2)
#' plot3d(dtm3)
#' }
#' @seealso
#' \link[lidR:grid_terrain]{grid_terrain}
#' \link[lidR:lasnormalize]{lasnormalize}
#' \link[gstat:vgm]{vgm}
#' \link[gstat:krige]{krige}
#' \link[akima:interp]{interp}
#' \link[lidR:lasnormalize]{lasnormalize}
#' \link[raster:raster]{RasterLayer}
grid_terrain = function(.las, res = 1, method, k = 10L, model = gstat::vgm(.59, "Sph", 874))
{
  . <- X <- Y <- Z <- NULL

  stopifnotlas(.las)

  ex = extent(.las)

  grid = make_grid(ex@xmin, ex@xmax, ex@ymin, ex@ymax, res)

  ground = suppressWarnings(lasfilterground(.las))

  if(is.null(ground))
    stop("No ground points found. Impossible to compute a DTM.", call. = F)

  ground = ground@data[, .(X,Y,Z)]

  Zg = interpolate(ground, grid, method, k, model)

  grid[, Z := round(Zg, 3)]

  # force grounds point to be dominant
  grid = rbind(grid, grid_metrics(lasfilterground(.las), list(Z = min(Z)), res, start=c(0.5*res,0.5*res)))
  grid = grid[, list(Z = min(Z)), by = .(X,Y)]

  as.lasmetrics(grid, res)

  return(as.raster(grid))
}