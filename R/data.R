#' Lidar abstracts published before ChatGPT
#'
#' Every lidar article published in the IEEE Journal of Selected Topics in
#' Applied Earth Observations and Remote Sensing up to the end of 2022, the
#' month after ChatGPT was released. Intended as the human-authored reference
#' corpus: the writing predates widely available large language model
#' assistance.
#'
#' @format A data frame with 245 rows and 6 columns:
#' \describe{
#'   \item{id}{OpenAlex work identifier.}
#'   \item{doi}{Digital object identifier.}
#'   \item{title}{Article title.}
#'   \item{abstract}{Abstract, reconstructed from the OpenAlex inverted index.}
#'   \item{publication_date}{Publication date as a `"YYYY-MM-DD"` string.}
#'   \item{publication_year}{Publication year as an integer.}
#' }
#'
#' @details
#' Scope is deliberately narrow. Holding the journal fixed removes venue as a
#' source of stylistic variation, and abstracts within one journal run to a
#' similar length: the median here is 223 words with an interquartile range of
#' 185 to 247, against 231 and 200 to 250 in [lidar_contrast]. Comparable
#' lengths matter because `mean_sentence_length` and `conj_rate` are noisier on
#' shorter documents.
#'
#' This is the complete result of the query, not a sample, so the dataset is
#' exactly reproducible from the filter recorded below. Regenerate or change
#' the topic, journal or windows by editing and re-running
#' `data-raw/fetch_lidar_corpus.R`.
#'
#' Abstracts, not full texts, are the unit of analysis: publisher full text is
#' generally not redistributable, whereas OpenAlex abstract data is CC0.
#'
#' @source
#' OpenAlex <https://openalex.org>, retrieved 2026-09-20 with the filter
#' `title_and_abstract.search:lidar,primary_location.source.id:S117727964,type:article,has_abstract:true,from_publication_date:2008-01-01,to_publication_date:2022-12-31`.
#' OpenAlex data is released under CC0.
#'
#' @seealso [lidar_contrast], [fetch_corpus()]
"lidar_reference"

#' Lidar abstracts published after ChatGPT
#'
#' Every lidar article published in the IEEE Journal of Selected Topics in
#' Applied Earth Observations and Remote Sensing from 2023 onward. Intended as
#' the contrast corpus for the reference profile built from [lidar_reference].
#'
#' @format A data frame with 211 rows and 6 columns, identical in structure to
#'   [lidar_reference].
#'
#' @details
#' These abstracts are **not labelled**. The corpus is defined by its date
#' window, not by authorship: some, none or many may have involved a language
#' model, and there is no ground truth here saying which. A distance measured
#' against the reference profile therefore supports a claim about a shift in
#' the distribution between two time periods, and does not support a claim
#' about detection accuracy, which would need labels.
#'
#' Two further limitations are worth stating. The reference window spans
#' fifteen years (2008 to 2022) against four here, so the reference corpus
#' averages over far more stylistic drift than the contrast corpus does. And
#' style changes for reasons unrelated to language models: the field, the
#' author pool and editorial practice all moved over the same period.
#'
#' Like [lidar_reference], this is the complete query result rather than a
#' sample.
#'
#' @source
#' OpenAlex <https://openalex.org>, retrieved 2026-09-20 with the filter
#' `title_and_abstract.search:lidar,primary_location.source.id:S117727964,type:article,has_abstract:true,from_publication_date:2023-01-01,to_publication_date:2026-12-31`.
#' OpenAlex data is released under CC0.
#'
#' @seealso [lidar_reference], [fetch_corpus()]
"lidar_contrast"
