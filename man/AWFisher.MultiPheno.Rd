% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/AWFisher.MultiPheno.R
\name{AWFisher.MultiPheno}
\alias{AWFisher.MultiPheno}
\title{AWFisher.MultiPheno is a function for identifying genes associated with multiple disease phenotypes in transcriptomics studies}
\usage{
AWFisher.MultiPheno(
  expr,
  pheno,
  confounder,
  Pheno.type,
  method = c("AFp", "AFz"),
  num.perm = 100,
  num.bootstrap = 50,
  ncores = 1
)
}
\arguments{
\item{expr}{a matrix of gene expression data. Rows represent samples, columns represent genes.}

\item{pheno}{a matrix of multiple phenotypes. Rows represent samples, columns represent phenotypes.}

\item{confounder}{a matrix of confounder. Do not use vector.}

\item{Pheno.type}{a vector of phenotypes' type. Current version supports "continuous", "binary", "count", and "survival".}

\item{method}{the method to be applied to the algorithm. Either "AFp" (default) or "AFz".}

\item{num.perm}{number of permutation to get the null distribution}

\item{num.bootstrap}{number of bootstrap samples for generating variability index and distance matrix}

\item{ncores}{number of cores}
}
\value{
\itemize{
    \item{pvalue: }{a vector of p-value (length is number of genes), which aggregates heterogeneous effects of all phenotypes for each gene.
    The p-value vector can be used to determine which genes are associated with phenotypes.}
    \item{weight: }{A weight matrix, which can be used to determine which specific phenotypes a gene is associate with.}
    \item{others: }{Variability index for the weight estimation and Distance matrix among genes will be saved as RData in the current directory.}
}
}
\description{
AWFisher.MultiPheno is a function for identifying genes associated with multiple disease phenotypes in transcriptomics studies
}
