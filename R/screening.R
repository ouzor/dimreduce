
#' Univariate feature scores and significance tests
#'
#' \code{featscore} computes the univariate scores for each feature, and 
#' \code{featscore.test} can be used to compute the corresponding p-values to measure 
#' statistical significance of these values.
#' 
#' @name featscores
#' 
#' @param x The original feature matrix, columns denoting the features and rows the instances.
#' @param y A vector with the observed target values we try to predict using \code{x}.
#' Can be factor for classification problems.
#' @param type Score type. One of 'pearson', 'kendall', 'spearman', or 'runs'. The first three
#' denote the type of correlation computed (will be passed to \link[stats]{cor}), whereas runs
#' denote the runs test, that can potentially detect any nonlinear relationship. 
#' @param exclude Columns (variables) in x to ignore. The score will be zero for these.
#' @param test.max If TRUE, compute the p-value for the maximum of the univariate scores.
#' If FALSE (default), compute p-values separately for each feature.
#' @param perms Number of random permutations to estimate the p-values for univariate scores.
#' @param ... Currently ignored.
#'
#'
#' @return A vector giving the univariate scores for each feature.
#' 
#' @section Details:
#' 
#' Univariate scores are a useful technique to assess variable relevances, and 
#' can be used for screening. The paper below has nice discussion and practical
#' tips for how to use univariate scores and when they are appropriate.
#' 
#' @section References:
#' 
#' Neal, R. and Zhang, J. (2006). High dimensional classification with Bayesian 
#' neural networks and Dirichlet diffusion trees. 
#' In Guyon, I., Gunn, S., Nikravesh, M., and Zadeh, L. A., editors, 
#' \emph{Feature Extraction, Foundations and Applications}, pages 265-296. Springer.
#' 
#'
#' @examples
#' \donttest{
#' ### 
#' s <- featscore(x,y) # correlation
#' s <- featscore(x,y, type='runs') # runs test, can detect nonlinear effects
#' s <- featscore.test(x,y,type='spearman') # p-values for the rank-correlations
#' }
#'
NULL

#' @rdname featscores
#' @export
featscore <- function(x, y, type='pearson', exclude=NULL) {
  
  if (is.vector(x))
    x <- matrix(x, ncol=1)
  
  if (is.factor(y)) {
    # handle factors in a special way
    classes <- levels(y)
    if (length(classes)==2)
      # transform to numeric vector and continue normally
      y <- as.numeric(y==classes[[1]])
    else {
      # more than two class, so score is the maximum from 'class k or other class' scores
      score <- matrix(0, nrow=ncol(x), ncol=1)
      for (c in classes) {
        score <- pmax(score, 
                      featscore(x, y==c, type=type, exclude=exclude))
      }
      return(score)
    }
  }
  
  if (is.vector(y))
    y <- matrix(y, ncol=1)
  
  ok <- rep(TRUE, ncol(x))
  ok[exclude] <- FALSE
  
  # zero score for those x that have variance zero
  ok[apply(x,2,var)==0] <- FALSE
  
  score <- matrix(0, nrow=ncol(x), ncol=ncol(y))
  
  if (type %in% c('pearson','kendall','spearman')) {
    # score[ok,] <- abs( t(x[,ok,drop=F]) %*% y )  / (nrow(y)-1)
    score[ok,] <- abs(cor(x[,ok,drop=F], y, method=type))
  } else if (type == 'runs') {
    score[ok,] <- runs.score(x[,ok,drop=F], y)
  } else
    stop('Unknown score function.')
  
  # if nans produced, treat them as zero score
  score[is.na(score)] <- 0
  
  return(score)
}



#' @rdname featscores
#' @export
featscore.test <- function(x,y, type='pearson', exclude=NULL, test.max=FALSE, perms=1000) {
  
  # permutations for y
  yperm <- matrix(0, nrow=length(y), ncol=perms)
  for (i in 1:perms)
    yperm[,i] <- sample(y)
  
  # the actual score
  s_actual <- featscore(x, y, exclude=exclude, type=type)
  
  # compute the scores with permuted y
  if (is.factor(y)) {
    # factors need to be handled separately to make the computation efficient
    classes <- unique(yperm[,1])
    s_perm <- 0
    for (c in classes) {
      s_perm <- pmax(featscore(x, yperm==c, exclude=exclude, type=type),
                     s_perm)
    }
  } else {
    s_perm <- featscore(x,yperm,exclude=exclude, type=type)
  }
  
  if (test.max) {
    pval <- mean( apply(s_perm,2,'max') >= max(s_actual)  )
    return(pval)
  }
  
  eps <- 1e-12 # for numerical stability when there are ties
  pval <- rowMeans(s_perm >= as.vector(s_actual)-eps)
  return(pval)
}





runs.score <- function(x, y) {
  
  if (is.factor(y))
    y <- as.numeric(y)
  if (is.vector(y))
    y <- matrix(y)
  if (is.vector(x))
    x <- matrix(x)
  n <- nrow(y)
  
  if (!is.integer(y)) {
    # bin the values of y into two; to those above median and to those below
    large <- apply(y, 2, function(yj) yj>median(yj))
    y[large] <- 1
    y[!large] <- 0
  }
  
  count <- matrix(0, nrow=ncol(x), ncol=ncol(y)) 
  for (j in 1:ncol(x)) {
    ord <- order(x[,j], runif(n))
    ytemp <- y[ord,,drop=F]
    count[j,] <- colSums(ytemp[1:(n-1),,drop=F] == ytemp[2:n,,drop=F])
  }
  count <- count/(n-1)
  
  if (ncol(count) == 1 || nrow(count) == 1)
    count <- as.vector(count)
  return(count)
}

