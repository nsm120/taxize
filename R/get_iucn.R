#' Get a IUCN Redlist taxon
#'
#' @export
#' @param x (character) A vector of common or scientific names
#' @param verbose logical; should progress be printed?
#' @param key (character) required. you IUCN Redlist API key. See
#' \code{\link[rredlist]{rredlist-package}} for help on authenticating with
#' IUCN Redlist
#' @param check (logical) Check if ID matches any existing on the DB, only
#' used in \code{\link{as.iucn}}
#' @param ... Ignored
#'
#' @return A vector of taxonomic identifiers as an S3 class.
#'
#' Comes with the following attributes:
#' \itemize{
#'  \item \emph{match} (character) - the reason for NA, either 'not found',
#'  'found' or if \code{ask = FALSE} then 'NA due to ask=FALSE')
#'  \item \emph{name} (character) - the taxonomic name, which is needed in
#'  \code{\link{synonyms}} and \code{\link{sci2comm}} methods since they
#'  internally use \pkg{rredlist} functions which require the taxonomic name,
#'  and not the taxonomic identifier
#'  \item \emph{uri} (character) - The URI where more information can be
#'  read on the taxon - includes the taxonomic identifier in the URL somewhere
#' }
#'
#' \emph{multiple_matches} and \emph{pattern_match} do not apply here as in
#' other \code{get_*} methods since there is no IUCN Redlist search,
#' so you either get a match or you do not get a match.
#'
#' @details There is no underscore method, because there's no real
#' search for IUCN, that is, where you search for a string, and get back
#' a bunch of results due to fuzzy matching. If that exists in the future
#' we'll add an underscore method here.
#'
#' IUCN ids only work with \code{\link{synonyms}} and \code{\link{sci2comm}}
#' methods.
#'
#' @family taxonomic-ids
#'
#' @examples \dontrun{
#' get_iucn(x = "Branta canadensis")
#' get_iucn(x = "Branta bernicla")
#' get_iucn(x = "Panthera uncia")
#'
#' # as coercion
#' as.iucn(22732)
#' as.iucn("22732")
#' (res <- as.iucn(c(22679946, 22732, 22679935)))
#' data.frame(res)
#' as.iucn(data.frame(res))
#' }
get_iucn <- function(x, verbose = TRUE, key = NULL, ...) {

  assert(x, "character")
  assert(verbose, "logical")

  fun <- function(x, verbose, key, ...) {
    direct <- FALSE
    mssg(verbose, "\nRetrieving data for taxon '", x, "'\n")
    df <- rredlist::rl_search(x, key = key, ...)

    if (!inherits(df$result, "data.frame") || NROW(df$result) == 0) {
      id <- NA_character_
      att <- "not found"
    } else {
      df <- df$result[, c("taxonid", "scientific_name", "kingdom",
                   "phylum", "order", "family", "genus", "authority")]

      # should return NA if species not found
      if (NROW(df) == 0) {
        mssg(verbose, tx_msg_not_found)
        id <- NA_character_
        att <- 'not found'
      }

      # check for direct match
      direct <- match(tolower(df$scientific_name), tolower(x))

      if (!all(is.na(direct))) {
        id <- df$taxonid[!is.na(direct)]
        direct <- TRUE
        att <- 'found'
      } else {
        direct <- FALSE
        id <- df$taxonid
        att <- 'found'
      }
      # multiple matches not possible because no real search
    }

    data.frame(
      id = id,
      name = x,
      att = att,
      stringsAsFactors = FALSE)
  }
  outd <- ldply(x, fun, verbose = verbose, key = key, ...)
  out <- outd$id
  attr(out, 'match') <- outd$att
  attr(out, 'name') <- outd$name
  if ( !all(is.na(out)) ) {
    attr(out, 'uri') <- sprintf("http://www.iucnredlist.org/details/%s/0", out)
  }
  class(out) <- "iucn"
  return(out)
}

#' @export
#' @rdname get_iucn
as.iucn <- function(x, check = TRUE, key = NULL) {
  UseMethod("as.iucn")
}

#' @export
#' @rdname get_iucn
as.iucn.iucn <- function(x, check = TRUE, key = NULL) x

#' @export
#' @rdname get_iucn
as.iucn.character <- function(x, check = TRUE, key = NULL) {
  if (length(x) == 1) {
    make_iucn(x, check, key = key)
  } else {
    collapse(x, make_iucn, "iucn", check = check, key = key)
  }
}

#' @export
#' @rdname get_iucn
as.iucn.list <- function(x, check = TRUE, key = NULL) {
  if (length(x) == 1) {
    make_iucn(x, check)
  } else {
    collapse(x, make_iucn, "iucn", check = check)
  }
}

#' @export
#' @rdname get_iucn
as.iucn.numeric <- function(x, check=TRUE, key = NULL) {
  as.iucn(as.character(x), check, key = key)
}

#' @export
#' @rdname get_iucn
as.iucn.data.frame <- function(x, check=TRUE, key = NULL) {
  structure(x$ids, class = "iucn", match = x$match,
            name = x$name, uri = x$uri)
}

#' @export
#' @rdname get_iucn
as.data.frame.iucn <- function(x, ...){
  data.frame(ids = unclass(x),
             class = "iucn",
             name = attr(x, "name"),
             match = attr(x, "match"),
             uri = attr(x, "uri"),
             stringsAsFactors = FALSE)
}

make_iucn <- function(x, check = TRUE, key = NULL) {
  url <- 'http://www.iucnredlist.org/details/%s/0'
  make_iucn_generic(x, uu = url, clz = "iucn", check, key)
}

check_iucn <- function(x) {
  tt <- httr::GET(sprintf("http://www.iucnredlist.org/details/%s/0", x))
  tt$status_code == 200
}

check_iucn_getname <- function(x, key = NULL) {
  rredlist::rl_search(id = as.numeric(x), key = key)
}
