% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pinball.R
\name{pinball}
\alias{pinball}
\title{Pinball Score for \code{MultiQR} Objects}
\usage{
pinball(
  qrdata,
  realisations,
  kfolds = NULL,
  plot.it = T,
  subsets = NULL,
  breaks = 4,
  bootstrap = NULL,
  ...
)
}
\arguments{
\item{qrdata}{\code{MultiQR} object.}

\item{realisations}{Vector of realisations corresponding to rows of \code{qrdata}.
\code{NA} accepted where realisations are missing.}

\item{kfolds}{Optional vector of fold/test labels corresponding to rows of \code{qrdata}.
Cannot be used with \code{subsets}.}

\item{plot.it}{\code{boolean}. Make a plot?}

\item{subsets}{Covariate to subset evaluation metric by corresponding to rows of \code{qrdata}.}

\item{breaks}{number of subsets to form.}

\item{bootstrap}{Number of boostrap samples used to generate 95\% confidence intervals.}

\item{...}{Additional arguments passed to \code{plot()}.}
}
\value{
Quantile Score data and, if \code{plot.it=T}, a plot.
}
\description{
This function calculates the pinball score for each quantile in a \code{MultiQR}
object. Optionally, results are produced by cross-validation fold or covariate,
95\% confidence intervals are estimated via bootstrap, and results are plotted.
}
\details{
Missing values in \code{realisations} are handled by \code{na.rm=T} when
calculating average exceedence of a given quantile.
}
\author{
Jethro Browell, \email{jethro.browell@strath.ac.uk}
}
