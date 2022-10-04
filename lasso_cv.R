library(data.table)
library(bigstatsr)
library(caret)
library(dplyr)

### read in data 
meths = fread("lasso_als_binary/als_lasso_input_covariates.txt", data.table=F)
status = fread("lasso_als_binary/als_lasso_status.txt", data.table=F)

covs = meths[, 1:9]
meth_only = meths[, -c(1:9)]

### store the data as ultra-efficient file-backed matrix (from bigstatr package)
system("rm ~/temp_matrix.bk")
fitdat=as_FBM(meth_only, backingfile = "~/temp_matrix")

################################# cross-validated ######################################## 

### set up cross-validation procedure 
nfolds=nrow(meth_only) # leave one out CV, but can also be changed to 10-fold CV 

### create sets of test/train for the number of folds we set 
testinds=caret::createFolds(y=status$V1, k=nfolds, list = T)
cvpredicted=rep(NA, nrow(meth_only))

### run for each fold
for(fold in 1:nfolds){
    traininds=setdiff(1:nrow(meths), testinds[[fold]])
    
    ### run binary logistic regression, specifying the train individuals and the covariates separately 
    ### here, alpha = 1 for lasso 
    res=big_spLogReg(X=fitdat, y01.train=status$V1[traininds], alphas=1,
                    ind.train=traininds, covar.train=data.matrix(covs[traininds, c("V1", "V7", "V8", "V9")]), 
                    warn=FALSE, max.iter = 1000000, eps=1e-6)

    ### test & save the prediction for further processing 
    cvpredicted[testinds[[fold]]]=predict(res, fitdat, ind.row=testinds[[fold]], covar.row=data.matrix(covs[testinds[[fold]], c("V1", "V7", "V8", "V9")]))
}

### auROC 
print(pROC::auc(status$V1, cvpredicted)
)

### save output if desired 
write.table(cvpredicted,"output.txt", sep='\t', quote=F, col.names = F, row.names = F)



