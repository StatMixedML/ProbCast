#' Multiple Quantile Regression Using mboost
#'
#' This function fits multiple quantile regreesion GBMs with facilities for cross-validation.
#' @param data A \code{data.frame} containing target and explanatory variables. May optionally contain a collumn called "kfold" with numbered/labeled folds and "Test" for test data.
#' @param formaul A \code{formula} object with the response on the left of an ~ operator, and the terms, separated by + operators, on the right
#' @param quantiles The quantiles to fit models for.
#' @param model_params List of parameters to be passed to \code{fit.gbm()}.
#' @param CVfolds Control for cross-validation if not supplied in \code{data}.
# #' @param parallel \code{boolean} parallelize cross-validation process?
# #' @param pckgs if parallel is TRUE then  specify packages required for each worker (e.g. c("data.table) if data stored as such)
# #' @param cores if parallel is TRUE then number of available cores
#' @param Sort \code{boolean} Sort quantiles using \code{SortQuantiles()}?
#' @param SortLimits \code{Limits} argument to be passed to \code{SortQuantiles()}. Constrains quantiles to upper and lower limits given by \code{list(U=upperlim,L=lowerlim)}.
#' @details Details go here...
#' @return Quantile forecasts in a \code{MultiQR} object.
#' @keywords Quantile Regression
#' @export
MQR_qreg_mboost <- function(data,
                            formula,
                            quantiles=c(0.25,0.5,0.75),
                            CVfolds=NULL,
                            ...,
                            bc_mstop=100,
                            bc_nu=0.1,
                            w=rep(1,nrow(data)),
                            # parallel = F,
                            # cores = NULL,
                            # pckgs = NULL,
                            Sort=T,SortLimits=NULL){

  ### Set-up Cross-validation
  TEST<-F # Flag for Training (with CV) AND Test output
  if("kfold" %in% colnames(data)){
    if(!is.null(CVfolds)){warning("Using column \"kfold\" from data. Argument \"CVfolds\" is not used.")}

    if("Test" %in% data$kfold){
      TEST<-T
      nkfold <- length(unique(data$kfold))-1
    }else{
      nkfold <- length(unique(data$kfold))
    }
  }else if(is.null(CVfolds)){
    data$kfold <- rep(1,nrow(data))
    nkfold <- 1
  }else{
    data$kfold <- sort(rep(1:CVfolds,length.out=nrow(data)))
    nkfold <- CVfolds
  }

  ### Creae Container for output
  predqs <- data.frame(matrix(NA,ncol = length(quantiles), nrow = nrow(data)))
  colnames(predqs) <- paste0("q",100*quantiles)

  ### Training Data: k-fold cross-validation/out-of-sample predictions
  for(q in quantiles){ # Loop over quantiles
    for(fold in unique(data$kfold)){# Loop over CV folds and test data


      ### Fit model
      temp_model <- do.call(mboost,c(list(formula=formula,
                                          data=data[data$kfold!=fold & data$kfold!="Test" & !is.na(data[[formula[[2]]]]),],
                                          family = QuantReg(tau=q),
                                          control=boost_control(mstop = bc_mstop),
                                          weights=w[data$kfold!=fold & data$kfold!="Test" & !is.na(data[[formula[[2]]]])]),
                                     ...))

      ### Save out-of-sample predictions
      predqs[[paste0("q",100*q)]][data$kfold==fold] <- predict.mboost(temp_model,
                                                                      newdata = data[data$kfold==fold,])


      ### Plot/Store some performance data?
      # plot(temp_model)
      # cvm <- cvrisk(temp_model) #<<< High computational demand!
      # plot(cvm)

    }
  }


  class(predqs) <- c("MultiQR","data.frame")


  if(Sort){
    predqs <- SortQuantiles(data = predqs,Limits = SortLimits)
  }

  return(predqs)

}