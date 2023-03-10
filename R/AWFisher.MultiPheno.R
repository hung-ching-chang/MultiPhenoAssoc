#' AWFisher.MultiPheno is a function for identifying genes associated with multiple disease phenotypes in transcriptomics studies
#'
#' @param expr a matrix of gene expression data. Rows represent samples, columns represent genes.
#' @param pheno a matrix of multiple phenotypes. Rows represent samples, columns represent phenotypes.
#' @param confounder a matrix of confounder. Do not use vector.
#' @param Pheno.type a vector of phenotypes' type. Current version supports "continuous", "binary", "count", and "survival".
#' @param method the method to be applied to the algorithm. Either "AFp" (default) or "AFz".
#' @param num.perm number of permutation to get the null distribution
#' @param num.bootstrap number of bootstrap samples for generating variability index and distance matrix
#' @param ncores number of cores
#'
#' @return
#' \itemize{
#'     \item{pvalue: }{a vector of p-value (length is number of genes), which aggregates heterogeneous effects of all phenotypes for each gene.
#'     The p-value vector can be used to determine which genes are associated with phenotypes.}
#'     \item{weight: }{A weight matrix, which can be used to determine which specific phenotypes a gene is associate with.}
#'     \item{others: }{Variability index for the weight estimation and Distance matrix among genes will be saved as RData in the current directory.}
#' }
#'
#'
#'
#' @export
AWFisher.MultiPheno <- function(expr,
                                pheno,
                                confounder,
                                Pheno.type,
                                method = c("AFp", "AFz"),
                                num.perm = 100,
                                num.bootstrap = 50,
                                ncores = 1){
  method <- match.arg(method)
  message("Multivariate phenotype-gene association analysis ...")
  message("####################################################")
  # Check input data such as dim and print summary of input data
  X <- expr
  Y <- pheno
  Z <- confounder
  num.gene <- ncol(X)

  #####step 1#####
  message(paste0(" Step 1: generate the input p-values for ", method, " method"))
  # currently, only allow conti, binary, count, survival outcomes
  res.origin<-Getpvalue(X = as.matrix(X),
                        Y = Y,
                        Z = as.matrix(Z),
                        data.type = Pheno.type)  #don't use as.matrix(Y) since survival variable might change to conti
  # if no input confounder -> Z = NULL
  # and skip residual step (permutation procedure)
  #res.origin<-Getpvalue(X = as.matrix(X),Y = Y,Z = NULL,
  #                      data.type = Pheno.type)
  message("\n - permutation procedure start ...")
  Y.residual<-Y
  for(i in 1:ncol(Y)){
    data.temp<-data.frame(Y=Y[,i],Z)
    if(Pheno.type[i] == "continuous"){
      model<-lm(Y~.,data=data.temp)
      Y.residual[,i]<-model$residuals
    }
    if(Pheno.type[i] == "count"){
      model<-glm(Y~.,data=data.temp, family = "poisson")
      Y.residual[,i]<-model$residuals
    }
    if(Pheno.type[i] == "binary"){
      model<-glm(Y~.,data=data.temp, family = "binomial")
      Y.residual[,i]<-model$residuals
    }
    if(Pheno.type[i] == "survival"){
      model <- survival::coxph(Y ~ ., data=data.temp)
      Y.residual[,i]<-residuals(model, type = "martingale")
    }
  }
  r1<-X
  for(i in 1:ncol(X)){
    data.temp<-cbind(data.frame(X=X[,i]),Z)
    model<-lm(X~.,data=data.temp)
    r1[,i]<-model$residuals
  }
  res.perm <- GetPermutationPvalue(as.matrix(r1),
                                   Y.residual,
                                   num.perm = num.perm,
                                   ncores = ncores)
  Pvalue.permutation <- NULL
  for(i in 1:num.perm){
    Pvalue.permutation <- rbind(Pvalue.permutation,
                                res.perm$Pvalue[[i]])
  }

  #####step 2#####
  message("\n Step 2: Perform AFp/AFz method ...")
  #AFp
  if(method == "AFp"){
    AFp.result <- AFp(pvalue = res.origin$pvalue,pvalue.perm = Pvalue.permutation)
    final.res <- c(AFp.result,
                   input.stat = res.origin)
    #mod.AFp <- AFp(pvalue = res.origin$pvalue,pvalue.perm = Pvalue.permutation)
    #final.res <- list(AFp = mod.AFp, input.stat = res.origin)
    #save(AFp.result, file = "AFp_result.Rdata")
  }
  #AFz
  if(method == "AFz"){
    AFz.result <- AFz(pvalue = res.origin$pvalue,pvalue.perm = Pvalue.permutation)
    final.res <- c(AFz.result,
                   input.stat = res.origin)
    #mod.AFz <- AFz(pvalue = res.origin$pvalue,pvalue.perm = Pvalue.permutation)
    #final.res <- list(AFz = mod.AFz, input.stat = res.origin)
    #save(AFz.result, file = "AFz_result.Rdata")
  }

  #####step 3#####
  message("\n Step 3: Variability index and Distance matrix ...")
  message(paste0(" - obtain ", num.bootstrap, " bootstrap samples with corresponding ", method, " result"))
  bootstrap.pvalue<-pbmclapply(1:num.bootstrap,function(ii){
    set.seed(ii)
    index.bootstrap<-sample(1:nrow(X),replace = T)
    X1<-X[index.bootstrap,]
    Y1<-Y[index.bootstrap,]
    Z1<-as.matrix(Z[index.bootstrap,])

    Y.residual<-Y1
    for(i in 1:ncol(Y1)){
      data.temp<-cbind(data.frame(Y=Y1[,i]),Z1)
      if(Pheno.type[i] == "continuous"){
        model<-lm(Y~.,data=data.temp)
        Y.residual[,i]<-model$residuals
      }
      if(Pheno.type[i] == "count"){
        model<-glm(Y~.,data=data.temp, family = "poisson")
        Y.residual[,i]<-model$residuals
      }
      if(Pheno.type[i] == "binary"){
        model<-glm(Y~.,data=data.temp, family = "binomial")
        Y.residual[,i]<-model$residuals
      }
      if(Pheno.type[i] == "survival"){
        model <- survival::coxph(Y ~ ., data=data.temp)
        Y.residual[,i]<-residuals(model, type = "martingale")
      }
    }
    r1 <- X1
    for(i in 1:ncol(X1)){
      data.temp<-cbind(data.frame(X=X1[,i]),Z1)
      model<-lm(X~.,data=data.temp)
      r1[,i]<-model$residuals
    }
    pvalue.bootstrap <- Getpvalue(X = as.matrix(X1),
                                  Y = Y1,
                                  Z = as.matrix(Z1),
                                  data.type = Pheno.type)
    Permutation.list <- GetPermutationPvalue(as.matrix(r1),
                                             Y.residual,
                                             num.perm,
                                             ncores=1)
    Pvalue.permutation<-NULL
    for(i in 1:num.perm){
      Pvalue.permutation <- rbind(Pvalue.permutation,Permutation.list$Pvalue[[i]])
    }
    #AFp
    if(method == "AFp"){
      final.res <- c(AFp(pvalue = pvalue.bootstrap$pvalue,pvalue.perm = Pvalue.permutation),
                     input.stat = pvalue.bootstrap)
    }
    #AFz
    if(method == "AFz"){
      final.res <- c(AFz(pvalue = pvalue.bootstrap$pvalue,pvalue.perm = Pvalue.permutation),
                     input.stat = pvalue.bootstrap)
    }
    return(final.res)
  },mc.cores = ncores)
  #save(bootstrap.pvalue,file="bootstrap_pvalue.Rdata")

  message("\n - Calculating variability index")
  if(method == "AFp"){
    # show ProgressBar
    pb <- txtProgressBar(min=0, max=nrow(bootstrap.pvalue[[1]]$weight), style=3)
    pbcount <- 0
    setTxtProgressBar(pb, pbcount)

    variability.index.AFp <- matrix(NA,nrow(bootstrap.pvalue[[1]]$weight), ncol(Y))
    temp<-c()
    for(i in 1:nrow(variability.index.AFp)){
      for(j in 1:ncol(variability.index.AFp)){
        for(k in (1:num.bootstrap)){
          temp[k]<-bootstrap.pvalue[[k]]$weight[i,j]
        }
        variability.index.AFp[i,j] <- 4*(var(temp)*(num.bootstrap-1)/num.bootstrap)
      }
      pbcount <- pbcount + 1
      setTxtProgressBar(pb, pbcount)
    }
    variability.index <- list(AFp = variability.index.AFp)
  }

  if(method == "AFz"){
    # show ProgressBar
    pb <- txtProgressBar(min=0, max=nrow(bootstrap.pvalue[[1]]$weight), style=3)
    pbcount <- 0
    setTxtProgressBar(pb, pbcount)

    variability.index.AFz<-matrix(NA,nrow(bootstrap.pvalue[[1]]$weight), ncol(Y))
    temp<-c()
    for(i in 1:nrow(variability.index.AFz)){
      for(j in 1:ncol(variability.index.AFz)){
        for(k in (1:num.bootstrap)){
          temp[k] <- bootstrap.pvalue[[k]]$weight[i,j]
        }
        variability.index.AFz[i,j] <- 4*(var(temp)*(num.bootstrap-1)/num.bootstrap)
      }
      pbcount <- pbcount + 1
      setTxtProgressBar(pb, pbcount)
    }
    variability.index <- list(AFz = variability.index.AFz)
  }
  save(variability.index, file = "Varibility_index.Rdata")

  message("\n - generating co-membership matrix")
  if(method == "AFp"){
    # show ProgressBar
    pb <- txtProgressBar(min=0, max=num.bootstrap, style=3)
    pbcount <- 0
    setTxtProgressBar(pb, pbcount)
    Distance.matrix.AFp <- matrix(0,nrow(bootstrap.pvalue[[1]]$weight),nrow(bootstrap.pvalue[[1]]$weight))
    for(i in 1:num.bootstrap){
      temp <- bootstrap.pvalue[[i]]
      matrix1 <- temp$weight*sign(temp$input.stat.coef)
      res.string <- apply(matrix1, 1, function(x){str_c(x,collapse = "")})
      res.comember <- sapply(res.string, function(x){as.numeric(x==res.string)})
      Distance.matrix.AFp<-Distance.matrix.AFp+res.comember
      pbcount <- pbcount + 1
      setTxtProgressBar(pb, pbcount)
    }
    Distance.matrix.AFp <- Distance.matrix.AFp/num.bootstrap
    save(Distance.matrix.AFp,file="Distance.matrix.AFp.Rdata")
  }

  if(method == "AFz"){
    # show ProgressBar
    pb <- txtProgressBar(min=0, max=num.bootstrap, style=3)
    pbcount <- 0
    setTxtProgressBar(pb, pbcount)
    Distance.matrix.AFz <- matrix(0,nrow(bootstrap.pvalue[[1]]$weight),nrow(bootstrap.pvalue[[1]]$weight))
    for(i in 1:num.bootstrap){
      temp<-bootstrap.pvalue[[i]]
      matrix1 <- temp$weight*sign(temp$input.stat.coef)
      res.string <- apply(matrix1,1,function(x){str_c(x,collapse = "")})
      res.comember <- sapply(res.string,function(x){as.numeric(x==res.string)})
      Distance.matrix.AFz <- Distance.matrix.AFz+res.comember
      pbcount <- pbcount + 1
      setTxtProgressBar(pb, pbcount)
    }
    Distance.matrix.AFz <- Distance.matrix.AFz/num.bootstrap
    save(Distance.matrix.AFz,file="Distance_matrix_AFz.Rdata")
  }

  # return AFp/AFz p-value
  if(method == "AFp"){return(AFp.result)}
  if(method == "AFz"){return(AFz.result)}
}

