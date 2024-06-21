library(RIA)
library(Rfast)
library(stats)

# only takes in disc = F
findprls = function(lesmask, phasefile, pretrainedmodel){
  # run ria feature extraction
  ria.obj = extract_ria(phasefile = phasefile, leslabels = lesmask, disc = F)
  ria.df = as.data.frame(ria.obj)
  print("radiomic feature extraction done!")
  
  # rename variable names to match the ones saved in the model 
  names.temp = as.character(names(ria.df))
  #names.temp = sapply(X = names.temp, function(X){gsub(pattern = "orig.", replacement = "", x = X)})
  names.temp = sapply(X = names.temp, function(X){gsub(pattern = "%", replacement = ".", x = X)})
  names(ria.df) = names.temp
  
  return(list(leslabels = lesmask, ria.df = ria.df, preds = stats::predict(pretrainedmodel, newdata = ria.df, type = "prob")))
  
}