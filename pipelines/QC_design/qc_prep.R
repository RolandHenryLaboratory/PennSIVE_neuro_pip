library(stringr)
library(tidyverse)
library(parallel)
library(extrantsr)
library(neurobase)
library(oro.nifti)
library(fslr)
library(ANTsR)

stage1_qc = function(main_path, flair_name, mimosa_name, index_range = 1:50, cores = 1){
  flair_files = list.files(main_path, pattern = flair_name, recursive = TRUE, full.names = TRUE)
  if(length(flair_files) > length(index_range)){
    flair_files = flair_files[index_range]
  }
  mimosa_files = list.files(main_path, pattern = mimosa_name, recursive = TRUE, full.names = TRUE)
  if(length(mimosa_files) > length(index_range)){
    mimosa_files = mimosa_files[index_range]
  }
  subject = sapply(flair_files, function(x) {
    candidates = str_split(x, "/")[[1]][which(grepl("^data", str_split(x, "/")[[1]]))+1]
    candidates = candidates[which(!grepl(".nii.gz", candidates))]
    return(candidates)
    }, USE.NAMES = FALSE)

  session = sapply(flair_files, function(x) str_split(x, "/")[[1]][which(grepl("^data", str_split(x, "/")[[1]]))+2], USE.NAMES = FALSE)
  summary_df = data.frame(cbind(subject, session, flair_files, mimosa_files))
  summary_df$evaluation = NA
  flair_imgs = mclapply(flair_files, function(x) readnii(x), mc.cores = cores)
  mimosa_imgs = mclapply(mimosa_files, function(x) readnii(x), mc.cores = cores)
  summary_df$note = NA
  labeled_lesion = mclapply(1:nrow(summary_df), function(x) get_labeled_mask(mimosa_imgs[[x]]), mc.cores = cores)
  summary_df$lesion_num = sapply(1:nrow(summary_df), function(x) {
    lesion_num = max(labeled_lesion[[x]])
    return(lesion_num)
    }, USE.NAMES = FALSE)
  summary_df$evaluator = NA
  qc_list = list("summary_df" = summary_df, "labeled_lesion " = labeled_lesion , "flair_imgs" = flair_imgs, "mimosa_imgs" = mimosa_imgs)
  return(qc_list)
}

get_labeled_mask = function(mimosa){
  labeled_img = ants2oro(labelClusters(oro2ants(mimosa),minClusterSize=27))
  return(labeled_img)
}

#cluster_center=function(label, x){
#  cluster=data.frame(which(label == x, arr.ind=TRUE))
#  n = nrow(cluster)
#  dim = cluster[round(median(1:n)),]
#  rownames(dim) = NULL
#  return(dim)
#  }


