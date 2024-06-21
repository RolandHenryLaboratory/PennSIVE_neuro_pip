#' @title Lesion Labelling
#' @description This function is a helper function for lesion_identification(). It takes in a lesion segmentation mask and a NIfTI image with identified lesion centers and returns a lesion label map.
#' @param lesmask Lesion segmentation mask. Given a probability threshold, automatically binarizes lesion probability map into a segmentation mask.
#' @param centers Lesion center map. Provided by lesiontools::lesioncenters().
#' @export
#' @import lesiontools
#' @import Rfast
#' @return A NIfTI with labels for each identified lesion.

getleslabels = function(lesmask, centers){
  
  #### knn on mimosa segmentations ####
  inds.lab = which (lesmask == 1 & centers > 0, arr.ind=TRUE) #labeled indices
  inds.cand = which(lesmask == 1 & centers ==0, arr.ind = T) #candidate indices
  num.candvox = nrow(inds.cand)
  
  pairwisedists = Rfast::dista(inds.cand, inds.lab, k = 1, index = T)
  
  lesmask[inds.lab] = centers[inds.lab]
  lesmask[inds.cand] = centers[inds.lab[pairwisedists,]]
  return(lesmask)
  
}
