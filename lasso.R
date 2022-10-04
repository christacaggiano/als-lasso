library(data.table)
library(bigstatsr)
library(caret)
library(dplyr)

################################# select best alpha ######################################## 

### read in data 
meths = fread("lasso_als_binary/als_lasso_input_covariates.txt", data.table=F)
status = fread("lasso_als_binary/als_lasso_status.txt", data.table=F)

covs = meths[, 1:9]
meth_only = meths[, -c(1:9)]

### store the data as ultra-efficient file-backed matrix (from bigstatr package)
system("rm ~/temp_matrix.bk")
fitdat=as_FBM(meth_only, backingfile = "~/temp_matrix")


### split the data into test/train 
set.seed(9)
trainIndex <- createDataPartition(status$V1, p=0.75, list=FALSE)

train_meths = meth_only[trainIndex,] #training data (75% of data)
train_status = status[trainIndex, ]

train_meths$id = NULL

test_meths = meth_only[-trainIndex,] #training data (75% of data)
test_status = status[-trainIndex, ]

### format data as FBM 
system("rm ~/temp_matrix.bk")
fitdat=as_FBM(train_meths, backingfile = "~/temp_matrix")

### perform regression using the 75% training data 
### gives a range of alphas to pick from, bigstatsR will pick the best one and use only that 
res.all=big_spLogReg(X=fitdat, y01.train=train_status, 
                     covar.train=data.matrix(covs[trainIndex, c("V1", "V7", "V8", "V9")]), 
                     alphas=c(1e-4, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1))

### filebacked matrix bigstatsr
system("rm ~/temp_matrix.bk")
fitdat_test=as_FBM(test_covs, backingfile = "~/temp_matrix")


### find predictions 
test.predictions = predict(res.all, fitdat_test)
pROC::auc(test_status, test.predictions)

### output best alpha value 
print(summary(res.all, best.only = TRUE))


