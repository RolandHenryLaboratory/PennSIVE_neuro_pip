## Relabel splitted lesions
relabel=function(split_lesion, s){
  for (i in 1:length(s)){
    split_lesion[split_lesion == s[i]] = i
  }
  return(split_lesion)
}

## Split confluent lesions
split_confluent_new = function(label,i, conf_split){
  lesion = label == i
  voxel_table = table(conf_split * lesion)
  uniqueness = length(voxel_table) -1
  if(uniqueness > 1){
    split_lesion = getleslabels(lesion, conf_split * lesion)
    v_t = table(split_lesion)
    s = as.integer(names(v_t))[2:length(v_t)]
    split_lesion = relabel(split_lesion, s)
  }else{split_lesion = lesion}
  return(split_lesion)
}

## Label Lesions
label_lesion = function(mimosa_mask, prob_map, mincluster = 100){
  labeled_img = label_mask(mimosa_mask == 1)
  size_control = table(labeled_img)
  size_control = size_control[size_control > mincluster]
  lesion_count = seq(1,(length(size_control)-1))
  les_split=lesioncenters(probmap = prob_map, binmap = mimosa_mask, c3d=F, minCenterSize=10, radius=1, parallel=F, cores=2)$lesioncenters
  subimg = lapply(lesion_count, split_confluent_new, label = labeled_img, conf_split = les_split)
  
  for (i in 1: length(subimg)){
    mask = subimg[[i]]
    if(i == 1){
      ct = max(subimg[[1]])
      sum_mask = mask
      next}else{
        add = (mask > 0) * ct
        mask = mask + add
        ct = max(mask)
        sum_mask = sum_mask + mask
      }
  }
  return(sum_mask)
}







