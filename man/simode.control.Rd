% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/simode.R
\name{simode.control}
\alias{simode.control}
\title{Class containing control parameters for a call to \code{simode}}
\usage{
simode.control(
  optim_type = c("both", "im", "nls"),
  im_optim_method = c("BFGS", "Nelder-Mead", "CG", "L-BFGS-B", "SANN", "Brent"),
  nls_optim_method = c("BFGS", "Nelder-Mead", "CG", "L-BFGS-B", "SANN", "Brent"),
  im_optim_control = list(),
  nls_optim_control = list(),
  ode_control = list(method = "lsoda"),
  im_smoothing = c("splines", "kernel", "none"),
  im_grid_size = 0,
  bw_factor = 1.5,
  use_pars2vars_mapping = F,
  trace = 0,
  save_im_trace = F,
  save_nls_trace = F,
  obs_sets_fit = c("separate", "separate_x0", "together"),
  parallel = F,
  save_to_log = F,
  reg_alpha = -1,
  reg_pkg = c("glmnet", "ncvreg")
)
}
\arguments{
\item{optim_type}{Controls what optimization will be performed: either only
integral-matching ('im'), only nonlinear least squares ('nls') or both
 (the default, i.e., first integral-matching then nonlinear least squares starting
  from the integral-matching estimates).}

\item{im_optim_method}{Method for optimization during the integral-matching stage.
Accepted values are any method supported by the \code{method} argument in \code{\link{optim}}.}

\item{nls_optim_method}{Method for optimization during the nonlinear least squares stage.
Accepted values are the same as in \code{im_optim_method}.}

\item{im_optim_control}{A list with control parameters for optimization during the
integral-matching stage. Can include anything that would appear in the \code{control} argument
in \code{optim} (depending on the choice of \code{im_optim_method}).
See \code{\link{optim}}.}

\item{nls_optim_control}{Control parameters for optimization during the
nonlinear least squares stage (as in \code{im_optim_control})}

\item{ode_control}{A list with control parameters for the ODE solver. Can include the argument
\code{method} appearing in the arguments to \code{\link[deSolve]{ode}}, as well as any other control parameters
accepted as additional parameters in the call to \code{\link[deSolve]{ode}}.}

\item{im_smoothing}{Choice of type of smoothing during the integral-matching stage (see Details).}

\item{im_grid_size}{Number of points used in integral-matching grid
(not relevant when \code{im_smoothing='kernel'}). Value <=0 means the grid size
will be set according to maximum number of observations for any of the
equations in the call to \code{simode}.}

\item{bw_factor}{Controls the bandwidth when \code{im_smoothing='kernel'}.
The bandwidth for each equation will be bw_factor*the maximum time interval
between two observations (should be >= 1).}

\item{use_pars2vars_mapping}{Whether to use pars2vars mapping (see Details).}

\item{trace}{Report level (0-4), with higher values producing more tracing information (see Details).}

\item{save_im_trace}{Whether to save trace information of integral-matching optimization,
which can then be plotted using \code{\link{plot_trace}}.}

\item{save_nls_trace}{Whether to save trace information of nonlinear least squares optimization,
which can then be plotted using \code{\link{plot_trace}}.}

\item{obs_sets_fit}{Controls the way multiple observation sets are fitted:
either "separate" (each set can be fitted with its own parameter values and initial
conditions), "separate_x0" (same parameter values fitted for all sets while initial conditions
may be different for each set) or "together" (fitting the mean of all observations sets).}

\item{parallel}{Controls whether to fit  sequentially or in parallel multiple observation
sets (\code{obs_sets>1} in the call to \code{\link{simode}}) that are fitted separately
(\code{obs_sets_fit="separate"}).
Fitting in parallel requires that the parallel package will be installed.
When running in parallel, output will not be displayed regardless of the trace level.
Instead, one can set \code{save_to_log} to true to save the output to a log file.}

\item{save_to_log}{Controls whether to redirect output to a log file.
If true, output will be saved to the file 'simode.log' in tempdir.}

\item{reg_alpha}{Value of tuning parameter alpha for regularization during the
integral-matching stage. Negative value means no regularization. A value between
0 and 1 controls the type of regularization (see \code{\link[glmnet]{glmnet}} and
\code{\link[ncvreg]{ncvreg}}).}

\item{reg_pkg}{What package to use for regularization (in case reg_alpha>=0).}
}
\description{
Class containing control parameters for a call to \code{simode}
}
\details{
Possible values for \code{im_smoothing} are “splines” (the default),
in which case smoothing will be performed using \code{\link[stats]{smooth.spline}}
with generalized cross-validation, “kernel”, using own kernel smoother function,
or “none” (using the observations as is, with interpolation if necessary).
\code{use_pars2vars_mapping} controls whether to use a mapping of which equations
are affected by each of the parameters. When set to true, previous matrices computed as part of
the integral-matching estimation are stored during the integral-matching optimization,
and are updated only for the equations that were affected by the change in the
parameter estimates from the previous iteration.
When the number of equations is large and some of the parameters affect only a few equations,
setting this option to true can significantly reduce the optimization time during
the integral-matching stage (while increasing the storage usage).
This is especially true with derivative based optimization methods (such as “BFGS” of optim)
which updates only one of the optimized parameters in each iteration.
\code{trace} has 5 possible levels:\cr
With trace=0, there would be no output displayed if there are no errors.\cr
With trace=1, a message will be displayed at the beginning and end of each optimization stage.\cr
With trace=2, non-critical errors occurring during the optimization iterations will be displayed.\cr
With trace=3, non-critical warnings occurring during the optimization iterations will be displayed.\cr
With trace=4, the calculated loss value for each iteration of the integral-matching and
nonlinear least squares optimizations will be displayed.
}
