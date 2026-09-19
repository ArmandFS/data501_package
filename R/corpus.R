#' Reconstruct an abstract from an OpenAlex inverted index
#'
#' OpenAlex stores abstracts as a map from each word to the positions it occupies
#' rather than as running text. Inverting that map back into a string is a sort
#' by position.
#'
#' @param inv Named list mapping words to integer position vectors.
#' @return A single string, or `NA_character_` when there is nothing to rebuild.
#' @noRd
.oa_abstract <- function(inv) {
  if (is.null(inv) || length(inv) == 0L) return(NA_character_)
  pos <- unlist(inv, use.names = FALSE)
  if (length(pos) == 0L) return(NA_character_)
  words <- rep(names(inv), lengths(inv))
  paste(words[order(pos)], collapse = " ")
}

#' Turn a list of OpenAlex work records into a corpus data frame
#'
#' @param results List of work records, as returned under `$results`.
#' @param min_words Minimum abstract length in whitespace-separated words.
#' @param verbose Report how many records were kept and dropped.
#' @return A data frame with one row per usable record.
#' @noRd
.oa_records_to_df <- function(results, min_words = 40L, verbose = TRUE) {
  n_in <- length(results)

  chr <- function(v) if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)[1L]

  out <- data.frame(
    id = vapply(results, function(r) chr(r$id), character(1L)),
    doi = vapply(results, function(r) chr(r$doi), character(1L)),
    title = vapply(results, function(r) chr(r$title), character(1L)),
    abstract = vapply(results, function(r) .oa_abstract(r$abstract_inverted_index),
                      character(1L)),
    publication_date = vapply(results, function(r) chr(r$publication_date),
                              character(1L)),
    stringsAsFactors = FALSE
  )

  #a 20-word abstract has too few sentences for mean_sentence_length to mean
  #anything, so drop the stubs rather than let them add noise
  n_words <- lengths(strsplit(trimws(out$abstract), "\\s+"))
  keep <- !is.na(out$abstract) & n_words >= min_words
  out <- out[keep, , drop = FALSE]

  out$publication_year <- as.integer(substr(out$publication_date, 1L, 4L))
  rownames(out) <- NULL

  if (verbose) {
    message(sprintf(
      "Parsed %d records; dropped %d (no abstract, or under %d words).",
      n_in, n_in - nrow(out), min_words
    ))
  }
  out
}

#' Build an OpenAlex filter string
#'
#' Assembles the filter that defines a corpus. Kept separate from the fetching
#' so that the topic and date wiring can be tested without a network call.
#'
#' @param topic Search term, matched against title and abstract.
#' @param from,to Date bounds as `"YYYY-MM-DD"` strings, both inclusive.
#' @param source OpenAlex source (journal) ID to restrict to, or `NULL` for
#'   any journal. Defaults to the IEEE Journal of Selected Topics in Applied
#'   Earth Observations and Remote Sensing.
#' @param publisher OpenAlex publisher ID to restrict to, or `NULL` for any
#'   publisher. Redundant when `source` is given, since a journal has one
#'   publisher. `"P4310319808"` is IEEE.
#' @param type OpenAlex work type, or `NULL` for any type. `"article"` excludes
#'   conference papers, preprints and editorials.
#' @param has_abstract Restrict to records that actually carry an abstract.
#'
#' @return A single filter string.
#'
#' @examples
#' build_oa_filter("lidar", "2008-01-01", "2022-12-31")
#'
#' # a different journal, or none at all
#' build_oa_filter("lidar", "2008-01-01", "2022-12-31", source = NULL,
#'                 publisher = "P4310319808")
#'
#' @seealso [fetch_corpus()]
#' @export
build_oa_filter <- function(topic,
                            from,
                            to,
                            source = "S117727964",
                            publisher = NULL,
                            type = "article",
                            has_abstract = TRUE) {
  if (!is.character(topic) || length(topic) != 1L || is.na(topic) ||
      !nzchar(trimws(topic))) {
    stop("`topic` must be a single non-empty string.", call. = FALSE)
  }

  parse_date <- function(d, nm) {
    if (!is.character(d) || length(d) != 1L) {
      stop(sprintf("`%s` must be a single date string in YYYY-MM-DD form.", nm),
           call. = FALSE)
    }
    #strptime is lenient: "30-11-2022" parses as the year 30 rather than
    #failing, so the shape has to be checked before the value
    if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", d)) {
      stop(sprintf("`%s` is not a date in YYYY-MM-DD form: \"%s\".", nm, d),
           call. = FALSE)
    }
    out <- as.Date(d, format = "%Y-%m-%d")
    if (is.na(out)) {
      stop(sprintf("`%s` is not a date in YYYY-MM-DD form: \"%s\".", nm, d),
           call. = FALSE)
    }
    out
  }
  d_from <- parse_date(from, "from")
  d_to <- parse_date(to, "to")
  if (d_from > d_to) {
    stop(sprintf("`from` (%s) must be before `to` (%s).", from, to),
         call. = FALSE)
  }

  parts <- c(
    sprintf("title_and_abstract.search:%s", trimws(topic)),
    if (!is.null(source)) sprintf("primary_location.source.id:%s", source),
    if (!is.null(publisher)) {
      sprintf("primary_location.source.publisher_lineage:%s", publisher)
    },
    if (!is.null(type)) sprintf("type:%s", type),
    if (isTRUE(has_abstract)) "has_abstract:true",
    sprintf("from_publication_date:%s", from),
    sprintf("to_publication_date:%s", to)
  )
  paste(parts, collapse = ",")
}

#' Read a saved OpenAlex response into a corpus data frame
#'
#' Parses a `works` response that was saved to disk. This is the same parsing
#' path [fetch_corpus()] uses, so it can be exercised in tests without touching
#' the network.
#'
#' @param path Path to a JSON file holding an OpenAlex `works` response.
#' @param min_words Minimum abstract length in words. Shorter records are
#'   dropped.
#' @param verbose Report how many records were parsed and dropped.
#'
#' @return A data frame with columns `id`, `doi`, `title`, `abstract`,
#'   `publication_date` and `publication_year`.
#'
#' @examples
#' f <- system.file("extdata", "openalex_sample.json", package = "styloprofile")
#' read_corpus_json(f)
#'
#' @seealso [fetch_corpus()]
#' @export
read_corpus_json <- function(path, min_words = 40L, verbose = TRUE) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("`path` must be a single file path.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop(sprintf("no such file: \"%s\".", path), call. = FALSE)
  }
  parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  results <- if (!is.null(parsed$results)) parsed$results else parsed
  .oa_records_to_df(results, min_words = min_words, verbose = verbose)
}

#' Fetch a corpus of abstracts from OpenAlex
#'
#' Downloads the abstracts of works matching a topic and date window. The topic
#' and both dates are arguments, so the same call builds a reference corpus and
#' a contrast corpus, or switches to a different field entirely.
#'
#' @details
#' Abstracts, not full texts, are the unit of analysis: publisher full text is
#' generally not redistributable, while OpenAlex abstracts are available under
#' CC0. A typical abstract runs to roughly 180 words.
#'
#' Results are cached under [tools::R_user_dir()] so that repeating a query does
#' not repeat the download. The returned data frame carries `query`, `filter`,
#' `fetched_at`, `database`, `journal` and `n_available` attributes, so a
#' corpus records how it was obtained.
#'
#' @param topic Search term, matched against title and abstract.
#' @param from,to Date bounds as `"YYYY-MM-DD"` strings, both inclusive.
#' @param source OpenAlex source (journal) ID, or `NULL` for any journal.
#'   Defaults to the IEEE Journal of Selected Topics in Applied Earth
#'   Observations and Remote Sensing.
#' @param publisher OpenAlex publisher ID, or `NULL` for any publisher.
#' @param type OpenAlex work type, or `NULL` for any type.
#' @param max_n Maximum number of records to download.
#' @param mailto Contact email. OpenAlex serves requests that supply one from a
#'   faster pool; see their API documentation.
#' @param min_words Minimum abstract length in words.
#' @param cache_dir Directory for cached responses. `NULL` uses
#'   [tools::R_user_dir()].
#' @param refresh Re-download even when a cached copy exists.
#' @param verbose Report progress.
#'
#' @return A data frame with columns `id`, `doi`, `title`, `abstract`,
#'   `publication_date` and `publication_year`.
#'
#' @examples
#' \dontrun{
#' # the human reference corpus: lidar articles published before ChatGPT
#' ref <- fetch_corpus("lidar", from = "2008-01-01", to = "2022-12-31")
#'
#' # the contrast corpus is the same call with a different window
#' post <- fetch_corpus("lidar", from = "2023-01-01", to = "2026-12-31")
#'
#' # any other topic is the same call again
#' fetch_corpus("hyperspectral", from = "2008-01-01", to = "2022-12-31")
#'
#' # widen to every IEEE journal instead of just this one
#' fetch_corpus("lidar", source = NULL, publisher = "P4310319808")
#' }
#'
#' @references
#' Priem, J., Piwowar, H., & Orr, R. (2022). OpenAlex: A fully-open index of
#' scholarly works, authors, venues, institutions, and concepts.
#' \emph{arXiv:2205.01833}. \doi{10.48550/arXiv.2205.01833}
#'
#' @seealso [build_oa_filter()], [read_corpus_json()], [build_profile()]
#' @export
fetch_corpus <- function(topic,
                         from = "2008-01-01",
                         to = "2022-12-31",
                         source = "S117727964",
                         publisher = NULL,
                         type = "article",
                         max_n = 500L,
                         mailto = getOption("styloprofile.mailto", NULL),
                         min_words = 40L,
                         cache_dir = NULL,
                         refresh = FALSE,
                         verbose = TRUE) {
  filter <- build_oa_filter(topic, from, to, source, publisher, type)

  if (!is.numeric(max_n) || length(max_n) != 1L || is.na(max_n) || max_n < 1) {
    stop("`max_n` must be a single positive number.", call. = FALSE)
  }
  max_n <- as.integer(max_n)

  if (is.null(cache_dir)) {
    cache_dir <- tools::R_user_dir("styloprofile", "cache")
  }
  slug <- gsub("[^a-z0-9]+", "_", tolower(trimws(topic)))
  #the journal is part of the identity of a corpus, so it belongs in the key
  src <- if (is.null(source)) "any" else tolower(source)
  cache_file <- file.path(
    cache_dir, sprintf("%s_%s_%s_%s_%d.rds", slug, src, from, to, max_n)
  )

  if (!refresh && file.exists(cache_file)) {
    if (verbose) message(sprintf("Reading cached corpus from %s", cache_file))
    return(readRDS(cache_file))
  }

  per_page <- min(200L, max_n)
  cursor <- "*"
  results <- list()

  while (length(results) < max_n && !is.null(cursor)) {
    url <- paste0(
      "https://api.openalex.org/works",
      "?filter=", utils::URLencode(filter, reserved = TRUE),
      "&per-page=", per_page,
      "&cursor=", utils::URLencode(cursor, reserved = TRUE),
      "&select=id,doi,title,publication_date,abstract_inverted_index",
      if (!is.null(mailto)) paste0("&mailto=", utils::URLencode(mailto, reserved = TRUE))
    )

    page <- tryCatch(
      jsonlite::fromJSON(url, simplifyVector = FALSE),
      error = function(e) {
        stop("could not reach the OpenAlex API: ", conditionMessage(e),
             call. = FALSE)
      }
    )

    if (length(page$results) == 0L) break
    results <- c(results, page$results)
    cursor <- page$meta$next_cursor

    if (verbose) {
      message(sprintf("Fetched %d of %d available.",
                      min(length(results), max_n), page$meta$count))
    }
    #the API asks for no more than 10 requests a second
    Sys.sleep(0.1)
  }

  n_available <- if (exists("page", inherits = FALSE)) page$meta$count else 0L
  results <- utils::head(results, max_n)

  out <- .oa_records_to_df(results, min_words = min_words, verbose = verbose)

  attr(out, "query") <- topic
  attr(out, "filter") <- filter
  attr(out, "fetched_at") <- Sys.time()
  attr(out, "database") <- "openalex"
  attr(out, "journal") <- if (is.null(source)) NA_character_ else source
  attr(out, "n_available") <- n_available

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(out, cache_file)
  if (verbose) message(sprintf("Cached to %s", cache_file))

  out
}
