
# Fit the parameters of an ODE system using integral-matching
#
# Implementation of the integral-matching method
# for ordinary differential equations (ode).
# Given a fully observed ode system which is linear in all of its parameters,
# it calculates the integral-matching estimates for the parameters
# (and the initial conditions as well if required).
# @param equations The equations describing the ode system.
# Each equation must be named according to the variable it describes.
# An equation can contain parameters appearing in pars or
# variables appearing in the equations names (character vector).
# @param pars The names of the linear parameters (character vector).
# @param time Time points of the observations. Either a vector,
# if the same time points were used for observing all variables,
# or a list of vectors the length of obs, if different time points
# were used for observing different variables (numeric list/vector).
# @param obs The observations. A list of vectors the length of equations,
# where each list member is the length of the relevant time vector (numeric list)
# @param x0 The initial conditions, if are known. Should have
# the same length and names of equations (numeric vector)
# @param pars_min Lower bounds for the parameter estimates (numeric vector)
# @param pars_max Upper bounds for the parameter estimates (numeric vector)
# @param im_smoothing Whether or not to use smoothing (logical)
# @param im_grid_size Number of points in fitted smoothed curves (numeric)
# @param vars2update Selected variables that need to be updated from the
# last call (numeric vector)
# @param im_fit_prev Returned value from the last call to simode_fit,
# for efficient refitting when given a selected subset of variables
# that need to be updated since the last call (list)
# @return A list which includes the following fields:
#  - theta: the parameter estimates
#  - x0: the initial conditions estimates (or given values if x0 were given)
#  - other internal structures that can be used for reducing
#  the computation time when using the function repetitively during
#  optimization
# @importFrom pracma trapz cumtrapz lsqlincon
# @importFrom stats D smooth.spline predict
# @importFrom glmnet glmnet
# @export
#

simode_fit <- function(equations, pars, time, obs,
                      x0=NULL, pars_min=NULL, pars_max=NULL,
                      im_smoothing=c('splines','kernel','none'),
                      im_grid_size=0, bw_factor=1.5,
                      vars2update=NULL, im_fit_prev=NULL, trace=0)
{
  if(!is.list(time))
    time <- rep(list(time),length(obs))

  if(!is.null(pars_min))  {
    pars_min[which(is.infinite(pars_min))] <- -1e100
  }
  if(!is.null(pars_max)) {
    pars_max[which(is.infinite(pars_max))] <- 1e100
  }

  vars <- names(equations)
  d <- length(vars)   #Number of independent variables
  p <- length(pars)   #Number of parameters

  min_time <- min(unlist(lapply(1:d,function(i) time[[i]][1])))
  max_time <- max(unlist(lapply(1:d,function(i) time[[i]][length(time[[i]])])))

  if(im_smoothing=='kernel') {
    dt <- min(unlist(lapply(1:d,function(i) diff(time[[i]]))))/2
    t <- seq(min_time, max_time, by = dt)
    N <- length(t)
  }
  else {
    if(im_grid_size > 0) {
      N <- im_grid_size
    }
    else {
      N <- max(unlist(lapply(1:d,function(i) length(time[[i]]))))
    }
    dt <- (max_time-min_time)/(N-1)
    t <- seq(min_time, max_time, by = dt)
  }

  im_smooth <- matrix(0,nrow=N,ncol=d)
  Z <- matrix(0,nrow=N,ncol=d)
  G <- list()
  A <- matrix(0, nrow = d, ncol = p)
  B <- matrix(0, nrow = p, ncol = p)

  colnames(im_smooth) <- vars
  colnames(Z) <- vars
  rownames(A) <- vars
  colnames(A) <- pars

  # -----------------------------------------------------------------------------
  # restore data from previous simode est if exists -----------------------------

  vars_selected <- 1:d
  if(!is.null(vars2update) &&
     !pracma::isempty(setdiff(1:d,vars2update)) &&
     !is.null(im_fit_prev)) {

    stopifnot(all(im_fit_prev$vars==vars),
              all(im_fit_prev$pars==pars),
              im_fit_prev$N==N)

    stopifnot(pracma::isempty(vars2update) || is.numeric(vars2update),
              pracma::isempty(setdiff(vars2update,1:d)))

    vars_selected <- vars2update
    im_smooth <- im_fit_prev$im_smooth
    Z <- im_fit_prev$Z
    G <- im_fit_prev$G
    A <- im_fit_prev$A
    B <- im_fit_prev$B
    Q <- im_smooth - Z
  }

  if(!pracma::isempty(vars_selected)) {

    # -----------------------------------------------------------------------------
    # calculate im_smooth ---------------------------------------------------------

    for(j in vars_selected) {
      if(im_smoothing=='splines') {
        fit <- smooth.spline(time[[j]],obs[[j]],cv=F)
        im_smooth[,j] <- predict(fit,x=t)$y
      }
      else if(im_smoothing=='kernel') {
        n <- length(time[[j]])
        b <- max(1,bw_factor)*max(diff(time[[j]]))
        for (k in 1:N) {
          ker <- fun_kernel(time[[j]], t[k], n, b)
          U <- calc_U(time[[j]], t[k], n, b)
          B <- calc_B(n, b, U, ker)
          W <- calc_W(n, b, U, B, ker)
          im_smooth[k,j] <- sum(obs[[j]]*W)
        }
      }
      else {
        im_smooth[,j] <- interp1(time[[j]],obs[[j]],xi=t,method='spline')
      }
    }
    for(j in 1:d)
      assign(vars[j], im_smooth[,j])

    # -----------------------------------------------------------------------------
    # calculate matrix Z of free-terms --------------------------------------------

    for (i in vars_selected){
      eq <- equations[i]
      for (j in pars) {
        eq <- gsub(paste0('\\<', j, '\\>'), "0", eq)
      }
      z <- eval(parse(text=as.expression(eq)))
      if(length(z)==1)
        z <- rep(z,N)
      Z[,i] <- cumtrapz(z)*dt
    }
    Q <- im_smooth - Z


    if(p==0) {
      G <- lapply(1:d, function(i) { cumtrapz(eval(parse(text=equations[[i]])))*dt } )
      im_fit <- list(x0=x0, vars=vars, pars=pars, N=N,
                     t=t, im_smooth=im_smooth, Z=Z, G=G)

      return (im_fit)
    }

    # -----------------------------------------------------------------------------
    # calculate matrix G ----------------------------------------------------------

    for (i in vars_selected) {
      eq <- parse(text=equations[i])
      eq.derivs <- sapply(1:p, function(j) D(eq, pars[j]))
      G[[i]] <- sapply(1:p, function(j) {
        u <- eval(eq.derivs[[j]])
        if(length(u)==1)
          u <- rep(u,N)
        cumtrapz(u)*dt
      })
    }
    names(G) <- vars

    # -----------------------------------------------------------------------------
    # calculate matrices A and B --------------------------------------------------

    if (is.null(x0) || any(is.na(x0))) {

      for (i in vars_selected) {
        A[i,] <- apply(G[[i]], 2, function(u) {trapz(u)*dt})
      }

      Gtx <- matrix(0, nrow = p, ncol = N)          #p*N matrix
      GtG <- rep(list(matrix(0, nrow=N, ncol=p)),p) #p objects of N*p matrix
      for (k in 1:N){
        g <- matrix(sapply(1:d,function(i) G[[i]][k,]),nrow=p)   #p*d matrix
        gtg <- g%*%t(g)                                          #p*p matrix
        Gtx[,k] <- g%*%(Q[k,])
        for (j in 1:p) {
          GtG[[j]][k,] <- gtg[j,]
        }
      }
      B <- sapply(1:p, function(i)  apply(GtG[[i]], 2, function(u) {trapz(u)*dt}))
    }

  }

  # -----------------------------------------------------------------------------
  # calculate theta -------------------------------------------------------------

  if (is.null(x0) || any(is.na(x0))) {
    int1 <- apply(Q, 2, function(u) {trapz(u)*dt})
    int2 <- apply(Gtx, 1, function(u) {trapz(u)*dt})

    x0_est <- NULL
    tryCatch({
      x0_est <-
        solve(max_time*diag(d) - A%*%solve(B)%*%t(A))%*%(int1 - A%*%solve(B)%*%int2)
      },
      warning = function(w) { return (w) },
      error = function(e) { return (e) }
    )
    if(is.null(x0_est))
      return (NULL)

    names(x0_est) <- vars
    if(!is.null(x0)) {
      not_na <- which(!is.na(x0))
      x0_est[not_na] <- x0_est[not_na]
    }
    x0 <- x0_est
    #if(is.null(pars_min) && is.null(pars_max))
    #  theta <- solve(B)%*%(int2 - t(A)%*%x0)
  }

  #if(is.null(theta)) {

  G_mat <- matrix(0, nrow = (N * d), ncol = p)
  for(i in 1:d) {
    G_mat[(N*(i-1)+1):(N*i),] <- G[[i]]
  }
  x0_mat <- matrix(x0,nrow=N,ncol=d,byrow=T)
  x_vec <- as.vector(matrix(Q-x0_mat,nrow=nrow(Q)*ncol(Q)))

  theta <- NULL
  tryCatch({
      theta <- lsqlincon(G_mat, x_vec, lb=pars_min, ub=pars_max)
  },
  warning = function(w) { if(trace>2) print(w) },
  error = function(e)   { if(trace>1) print(e) }
  )
  #}

  if(is.null(theta))
    return (NULL)

  names(theta) <- pars

  im_fit <- list(theta=theta, x0=x0, vars=vars, pars=pars, N=N,
                 t=t, im_smooth=im_smooth, Z=Z, G=G, A=A, B=B)

  return (im_fit)
}

############ Kernel related functions #########

fun_kernel <- function(time, t, n, b) {
  s <- (time - t)/b
  ker <- 0.75*(1-s^2)*(abs(s)<=1)
  return (ker)
}


calc_U <- function(time, t, n, b){
  U <- matrix(0, nrow=2, ncol = n)
  U[1,] <- 1
  U[2,] <- (time - t)/b
  return(U)
}

calc_B <- function(n, b, U, ker) {
  B <- matrix(0, nrow = 2, ncol = 2)
  for(i in 1:n){
    B <- B + U[,i]%*%t(U[,i])*ker[i]
  }
  B <- B/(n*b)
  return(B)
}

calc_W <- function(n, b, U, B, ker) {
  B_inv <- solve(B)
  W <- apply(matrix(1:n),1, function(i) t(U[,i])%*%B_inv%*%c(1,0)*ker[i])/(n*b)
  return(W)
}