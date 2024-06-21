#' @title MS Lesion Center Identification + Lesion Labelling
#' @description This function takes in a lesion probability map, a lesion segmentation mask, and a T2*-phase image for a single subject and identifies + classifies lesions as PRL or not.
#' @param probmap Lesion probability map. We recommend using lesion segmentation algorithm MIMoSA.
#' @param lesmask Lesion segmentation mask. Given a probability threshold, automatically binarizes lesion probability map into a segmentation mask.
#' @export
#' @import lesiontools
#' @import Rfast
#' @return A list with two NIfTI files: one with the identified lesion centers, and one with labels for each identified lesion.

lesion_identification = function(probmap, lesmask){
  
  ## get lesion centers ##
  lescents_obj = lesioncenters(probmap = probmap, 
                           binmap = lesmask,
                           c3d = F,
                           radius = 2, 
                           parallel = F) #get centers of dilated mask
  lescents_img = lescents_obj$lesioncenters #get centers of dilated mask as a nifti
  
  ## get lesion labels ##
  leslabels = getleslabels(lesmask = lesmask, centers = lescents_img)
  
  #subset out small lesions
  leslabels_big = leslabels
  for(i in 1:max(leslabels)){
    if(sum(leslabels == i) < 100){
      leslabels_big[leslabels_big == i] = 0
    }
  }
  
  #relabel lesions
  leslabels.names = names(table(leslabels_big))
  numles = length(leslabels.names) - 1
  if(leslabels.names[length(leslabels.names)] != numles){
    for(i in 2:(numles+1)){
      leslabels_big[leslabels_big == leslabels.names[i]] = (i-1)
    }
  }
  
  return(list(lescents = lescents_img, leslabels = leslabels_big))
}