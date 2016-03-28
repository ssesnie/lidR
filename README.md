# lidR

R package for airborne LiDAR data manipulation and visualisation for forestry application

lidR package provides functions to read `.las` files, plot a cloud of points, compute metrics in an area-based approach, compute digital model of canopy, thin lidar data, automatically extract ground inventories, process a set of tiles on multicore, classify data from shapefiles and provides others tools to manipulate liDAR data. LidR is designed mainly for research purposes in an area-based approach.

lidR provides an open-source and R based implementation of the main function from sofware like FUSION or lastools.

# Install lidR from Github with devtools

    install.package("devtools")
    devtools::install_github("Jean-Romain/lidR")
    library(lidR)
    
# Features 

- Read `.las`files and metadata.
- Retrieved indiviual pulses
- Retrieve individual flightlines
- Compute any set of metrics on a cloud of point
- Rasterize and apply any function to compute a set of metrics in an area based approach
- Classify and filter data from geographic shapefiles
- Filter cloud of points based on any condition test
- Thin a cloud of point to reach an homogeneous point density
- Clip data base on disc, rectangle or polygon.
- Compute point and pulse densities
- Manage a catalog of `.las` tiles
- Extract automatically a set of ground plot inventories (even plot falling between two or more tiles)
- Analyse a full set a tiles in parallel computing
- Plot 3D LiDAR data
- plot in 2D and 3D the metrics
- Compute simple triangular irregular network (TIN)
    
# Some examples

## Read a las file

    lidar = LoadLidar("file.las")
    
## Plot data

    plot(lidar)

## Compute a simple metric

    metric = gridMetrics(lidar, 20, mean(Z))
    plot(metric)
    
## Compute a set a personnal metrics

    myMetrics = function(z, i, angle, pulseID)
    {
      ret = list(
            npulse  = length(unique(pulseID)),
            hmean   = mean(z),
            hmax    = max(z),
            imean   = mean(i),
            angle   = mean(abs(angle))
            )

       return(ret)
    }
    
    metrics = gridMetrics(lidar, 20, myMetrics(Z, Intensity, ScanAngle, pulseID))

    plot(metrics, "hmean")
    plot(metrics, "hmax")
    plot(metrics, "imean")
    #etc.