# Load libraries
library(data.table)
library(foreign)
library(omxr)
library(parallel)

# Read command line argument to get working directory
args <- commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
  stop("Path to the output directory must be specified as an argument.\n", call.=FALSE)
} else if (length(args)>2) {
  stop("Too many arguments passed to the script.\n", call.=FALSE)
} else if (length(args)==1) {
  args[2] <- 5
}

time0 <- Sys.time()
# Output diretory
#wd <- "E:/Projects/Clients/NashvilleMPO/ModelUpdate2023/Model/Development/nashvilleabm_tcad9/2018/outputs" # For testing
wd <- args[1]
argcores <- as.integer(args[2])
cat("Setting output directory to ", wd, ".\n")
setwd(wd)

# Get a list of all the OMX files in the output directory
mtx_files <- list.files(wd, pattern="_temp.omx$", full.names=TRUE)

convertOmxFile <- function(mtx_file){
	# Name of the new file
	new_mtx_file <- gsub("_temp", "", mtx_file)
	# Print information
	cat("Converting file ", basename(mtx_file), " to ", basename(new_mtx_file), "\n")
	
	# Read TransCAD created OMX file
	m <- read_all_omx(mtx_file)
	
	# Read OMX file info
	m_info <- list_omx(mtx_file)
	
	# Create new OMX file
	create_omx(new_mtx_file, m_info$Row, m_info$Columns)
	
	# Re-write the data into the new OMX file
	write_all_omx(m,new_mtx_file)
	
	invisible(NULL)
}

# Use parallelization steps to reduce runtime
ncores <- detectCores()
ncores <- min(min(max(ncores-1,1),length(mtx_files)),argcores)
cat("Choosing ", ncores, " cores.\n")
clust <- makeCluster(ncores)
invisible(clusterEvalQ(clust, library(omxr)))
invisible(parLapply(cl=clust, mtx_files, convertOmxFile))
stopCluster(clust)	
cat("Successfully converted all the old OMX files to new OMX files.\n")

# Uncomment following lines if you want to delte the old files
#cat("Now deleting old OMX files.\n")
#file.remove(mtx_files)

time1 <- Sys.time()
cat("The converstion took: ", capture.output(time1-time0), "\n")