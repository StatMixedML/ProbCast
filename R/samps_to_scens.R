#' Generate multivariate forecasts
#'
#' This function produces a list of multivariate scenario forecasts in the marginal domain from the spatial/tempral/spatiotemporal gaussian covariance matrices and marginal distributions
#' 
#' @author Ciaran Gilbert, \email{ciaran.gilbert@@strath.ac.uk}
#' @param copulatype As \code{string}, either \code{"spatial"} or \code{"temporal"},
#' note that spatio-temporal can be generated via \code{"temporal"} setting.
#' @param no_samps Number of scenarios to sample
#' @param marginals a named list of marginal distibutions,
#'  e.g. if class is \code{MultiQR}, \code{list(<<name>> = <<MultiQR object>>)}.
#'  Multiple margins are possible for multiple locations (see examples) although
#'  they must be the same class (\code{MultiQR} or \code{PPD}).
#'  If parametric class supply a list of the distribution parameters here
#'  and the corresponding quantile function in \code{control} (see below).
#'  The ordering of this list is important for multiple locations ---
#'  it should be ordered according to the row/columns in each member of \code{sigma_kf}.
#' @param sigma_kf a named list of the covariance matrices with elements corresponding
#' to cross-validation folds.
#' @param mean_kf a named list of the mean vectors with elements corresponding to
#' cross-validation folds.
#' @param control a named list of with nested control parameters
#' (named according to \code{marginals}). Each named list should contain
#' \code{kfold}, \code{issue_ind}, and \code{horiz_ind} which are the cross-validation folds,
#' issue time, and lead time vectors corresponding to the margins of the copula, respectively.
#' If margins are MultiQR class also define \code{PIT_method} and list \code{CDFtails},
#' which are passed to the \code{PIT} function. If the margins are distribution parameter
#' predictions then define \code{q_fun}, which transforms the columns of \code{marginals}
#' through the quantile function --- see example for more details. 
#' @param mcmapply_cores Defaults to 1. Warning, only change if not using
#' Windows OS --- see the \code{parallel::mcmapply} help page for more info.
#' Speed improvements possible when generating sptio-temporal scenarios, set to
#' the number of locations if possible.
#' @param ... other parameters to be passed to \code{mvtnorm::rmvnorm}.
#' @note For spatio-temporal scenarios, each site must have the same number
#' of inputs to the governing covariance matrix.
#' @note For multiple locations the ordering of the lists
#' of the margins & control, and the structure of the covariance
#' matrices is very important: if the columns/rows in each covariance
#' matrix are ordered \code{loc1_h1, loc1_h2,..., loc2_h1, loc2_h_2,...,
#' loc_3_h1, loc_3_h2,...} i.e. location_leadtime --- then the list of
#' the marginals should be in the same order loc1, loc2, loc3,....
#' @note Ensure cross-validation fold names in the control list do not change
#' within any issue time --- i.e. make sure the issue times are unique to each fold. 
#' @details This is a sampling function for Gaussian couplas with marginals
#' specificed by \code{MultiQR} or \code{PPD} objects and user-specified covariance
#' matrix.
#' @return A \code{list} or \code{data.frame} of multivariate/scenario/trajectroy forecasts.
#' @examples
#' \dontrun{
#' # for parametric type marginals with a Generalized Beta type 2 family
#' scens <- samps_to_scens(copulatype = "temporal",no_samps = 100,marginals = list(loc_1 = param_margins),sigma_kf = cvm,mean_kf = mean_vec,
#'                         control=list(loc_1 = list(kfold = loc_1data$kfold, issue_ind = loc_1data$issue_time, horiz_ind = loc_1data$lead_time,
#'                                                   q_fun = gamlss.dist::qGB2)))
#' }
#' \dontrun{
#' # for MQR type marginals
#' scens <- samps_to_scens(copulatype = "temporal",no_samps = 100,marginals = list(loc_1 = mqr_gbm_1),sigma_kf = cvm,mean_kf = mean_vec,
#'                         control=list(loc_1 = list(kfold = loc_1data$kfold, issue_ind = loc_1data$issue_time, horiz_ind = loc_1data$lead_time,
#'                                                   PIT_method = "linear",CDFtails= list(method = "interpolate", L=0,U=1))))
#' }
#' \dontrun{
#' # for spatio-temporal scenarios with MQR type marginals
#' scens <- samps_to_scens(copulatype = "temporal", no_samps = 100,marginals = list(loc_1 = mqr_gbm,loc_2 = mqr_gbm_2),sigma_kf = cvm_2,mean_kf = mean_vec_2,
#'                         control=list(loc_1 = list(kfold = loc_1data$kfold, issue_ind = loc_1data$issue_time, horiz_ind = loc_1data$lead_time,
#'                                                   PIT_method = "linear",CDFtails= list(method = "interpolate", L=0,U=1)),
#'                                      loc_2 = list(kfold = loc_2data$kfold, issue_ind = loc_2data$issue_time, horiz_ind = loc_2data$lead_time,
#'                                                   PIT_method = "linear", CDFtails = list(method = "interpolate", L=0, U=1))))
#' }
#' @importFrom mvtnorm rmvnorm
#' @importFrom parallel mcmapply
#' @export
samps_to_scens <- function(copulatype,no_samps,marginals,sigma_kf,mean_kf,control,mcmapply_cores = 1L,...){
  
  # no kfold capability?
  # improve ordering of lists cvm matrix...
  
  if(class(marginals)[1]!="list"){
    marginals <- list(loc_1 = marginals)
    warning("1 location detected --- margin coerced to list")
    if(length(control)>1){
      control <- list(loc_1 = control)
    }
    
  }
  
  if(length(marginals)!=length(control)){
    stop("control dimensions must equal marginals")
  }
  
  if(!identical(names(marginals),names(control))){
    stop("control must be named and in the same order as marginals")
  }
  
  if(!identical(names(sigma_kf),names(mean_kf))){
    stop("mean_kf order must equal sigma_kf")
  }
  
  if(mcmapply_cores!=1){
    warning("Only change mcmapply_cores if not using Windows OS")
  }
  
  
  if(copulatype=="spatial"){
    
    # This function is for extracting spatial scenario samples
    extr_kf_spatsamp <- function(kf_samp_df,uni_kfold,...){
      
      arg_list <- list(n=no_samps,sigma=sigma_kf[[uni_kfold]],mean=mean_kf[[uni_kfold]],...)
      
      # sample from multivariate gaussian, gives results in a list of matrices
      kf_samps <- replicate(n=nrow(kf_samp_df),expr=do.call(eval(parse(text="rmvnorm")),args=arg_list),simplify = F)
      
      # transform sample rows ---> samples in cols and time_ind in rows
      kf_samps <- lapply(kf_samps,t)
      
      # convert to uniform domain
      kf_samps <- lapply(kf_samps,pnorm)
      
      # add ID row column for split list later (will help margins length>1) --- poss imp, impose naming convention on cvms?
      kf_samps <- lapply(kf_samps,function(x){cbind(x,sort(rep(1:length(marginals),nrow(x)/length(marginals))))})
      
      #bind the rows
      kf_samps <- data.frame(docall("rbind",kf_samps))
      
      # split the matrix up into a list of data.frames by the rowID column for different locations
      kf_samps <- split(data.frame(kf_samps[,1:c(ncol(kf_samps)-1)]),f=kf_samps[,ncol(kf_samps)])
      
      # bind with kf_samp_df time indices
      kf_samps <- lapply(kf_samps,function(x){cbind(kf_samp_df,x)})
      
      # name list
      names(kf_samps) <- names(marginals)
      
      return(kf_samps)
      
    }
    
    # find the unique combinations of issue_time and horizon at per fold across all the locations
    find_nsamp <- list()
    for(i in names(sigma_kf)){
      find_nsamp[[i]] <- unique(do.call(rbind,unname(lapply(control,function(x){data.frame(issue_ind=x$issue_ind[x$kfold==i],horiz_ind=x$horiz_ind[x$kfold==i])}))))
      find_nsamp[[i]] <- find_nsamp[[i]][order(find_nsamp[[i]]$issue_ind, find_nsamp[[i]]$horiz_ind),]
    }
    
    # extract samples calling etr_kf_spatsamp
    clean_samps <- mcmapply(extr_kf_spatsamp,kf_samp_df=find_nsamp,uni_kfold = as.list(names(find_nsamp)),MoreArgs = list(...),SIMPLIFY = F,mc.cores = mcmapply_cores)
    
    
    
  } else{ if (copulatype=="temporal"){
    
    # This function is for extracting temporal/spatio-temporal scenario samples
    extr_kf_temposamp <- function(issuetimes,uni_kfold,...){
      
      arg_list <- list(n=no_samps,sigma=sigma_kf[[uni_kfold]],mean=mean_kf[[uni_kfold]],...)
      
      # sample from multivariate gaussian, gives results in a list of matrices
      kf_samps <- replicate(n=length(issuetimes),expr=do.call(eval(parse(text="rmvnorm")),args=arg_list),simplify = F)
      
      # transform sample rows ---> samples in cols and horizon in rows
      kf_samps <- lapply(kf_samps,t)
      
      # convert to uniform domain
      kf_samps <- lapply(kf_samps,pnorm)
      
      # add ID row column for split list later (will help margins length>1) --- poss imp, impose naming convention on cvms?
      kf_samps <- lapply(kf_samps,function(x){cbind(x,sort(rep(1:length(marginals),nrow(x)/length(marginals))))})
      
      # bind the rows
      kf_samps <- data.frame(docall("rbind",kf_samps))
      
      # add issueTime ID to each data.frame
      issue_ind <- sort(rep(issuetimes,nrow(kf_samps)/length(issuetimes)))
      
      # add horiz_ind to vector
      horiz_ind <- rep(sort(unique(control[[1]]$horiz_ind)),nrow(kf_samps)/length(sort(unique(control[[1]]$horiz_ind))))
      kf_samps <- cbind(issue_ind,horiz_ind,kf_samps)
      
      # split the matrix up into a list of data.frames by the rowID column for different locations
      kf_samps <- split(data.frame(kf_samps[,1:c(ncol(kf_samps)-1)]),f=kf_samps[,ncol(kf_samps)])
      
      # name list
      names(kf_samps) <- names(marginals)
      
      return(kf_samps)
      
    }
    
    
    
    # find number of unique issue_times per fold across all the locations (use data.frame to avoid losing posixct class if present)
    find_issue <- list()
    for(i in names(sigma_kf)){
      find_issue[[i]] <- unique(do.call(rbind,unname(lapply(control,function(x){data.frame(issue_ind=unique(x$issue_ind[x$kfold==i]))}))))
      find_issue[[i]] <- find_issue[[i]][order(find_issue[[i]]$issue_ind),]
    }
    
    
    # extract samples calling etr_kf_temposamp --- check mc.set.seed if users want to set the seed for each kfold --- https://stackoverflow.com/questions/30456481/controlling-seeds-with-mclapply
    clean_samps <- mcmapply(extr_kf_temposamp,issuetimes=find_issue,uni_kfold = as.list(names(find_issue)),MoreArgs = list(...),SIMPLIFY = F,mc.cores = mcmapply_cores)
    
    
  }else{stop("copula type mis-specified")}}
  
  
  
  # merge samples with control data.frames to filter to the required samples for passing to the PIT
  # return clean_samps in time order
  clean_fulldf <- list()
  for(i in names(marginals)){
    clean_fulldf[[i]] <- docall(rbind,lapply(clean_samps,function(x){x[[i]]}))
  }
  # set order of df
  clean_fulldf <- lapply(clean_fulldf,function(x){x[order(x$issue_ind, x$horiz_ind),]})
  
  # merge control cols and the samples to give the final data.frames
  cont_ids <- lapply(control,function(x){data.frame(issue_ind=x$issue_ind,horiz_ind=x$horiz_ind,sort_ind=1:length(x$issue_ind))})
  filtered_samps <- mapply(merge.data.frame,x=cont_ids,y=clean_fulldf,MoreArgs = list(all.x=T),SIMPLIFY = F)
  ## preserve order of merged scenario table with input control table
  filtered_samps <- lapply(filtered_samps,function(x){x[order(x$sort_ind),]})
  # remove issuetime, horizon, and sorting column for passing through PIT-
  filtered_samps <- lapply(filtered_samps,function(x){x[,-c(1:3)]})
  
  
  
  
  
  ### transform Unifrom Variable into original domain
  ### add S3 support for PPD...
  if (class(marginals[[1]])[1]%in%c("MultiQR")){
    
    method_list <- lapply(control,function(x){x$PIT_method})
    CDFtail_list <- lapply(control,function(x){x$CDFtails})
    
    print(paste0("Transforming samples into original domain"))
    sampsfinal <- mcmapply(function(...){data.frame(PIT.MultiQR(...))},qrdata=marginals,obs=filtered_samps,method=method_list,tails = CDFtail_list, SIMPLIFY = F,MoreArgs = list(inverse=TRUE),mc.cores = mcmapply_cores)
    
    
  } else {
    
    ### make sure before as.list in do.call the object is a data.frame
    return_ppdsamps <- function(samps,margin,quant_f){
      ppd_samps <- as.data.frame(lapply(samps,function(x){do.call(quant_f,as.list(data.frame(cbind(p=x,margin))))}))
      return(ppd_samps)
    }
    
    q_list <- lapply(control,function(x){x$q_fun})
    
    print(paste0("Transforming samples into original domain"))
    sampsfinal <- mcmapply(return_ppdsamps,samps = filtered_samps, margin = marginals,quant_f = q_list,SIMPLIFY = F,mc.cores = mcmapply_cores)
    
    
  }
  
  
  return(sampsfinal)
  
  
}