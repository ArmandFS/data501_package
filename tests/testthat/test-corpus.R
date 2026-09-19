#no test in this file touches the network. the fetching and the parsing are
#separate functions precisely so the parsing can be tested from a saved
#response, which keeps R CMD check offline and repeatable.

# --- rebuilding abstracts from an inverted index ---

test_that("rebuilds an abstract worked out by hand", {
  expect_equal(.oa_abstract(list(The = 0L, cat = 1L, sat = 2L)), "The cat sat")
})

test_that("puts a repeated word in every position it occurs in", {
  expect_equal(.oa_abstract(list(the = c(0L, 2L), big = 1L, dog = 3L)),
               "the big the dog")
})

test_that("gives NA rather than an empty string when there is no abstract", {
  expect_equal(.oa_abstract(NULL), NA_character_)
  expect_equal(.oa_abstract(list()), NA_character_)
})

# --- building the query ---

test_that("builds the filter for the requested topic and date window", {
  #S117727964 is the journal the corpus is drawn from
  expect_equal(
    build_oa_filter("lidar", "2008-01-01", "2022-12-31"),
    paste0("title_and_abstract.search:lidar,",
           "primary_location.source.id:S117727964,",
           "type:article,has_abstract:true,",
           "from_publication_date:2008-01-01,",
           "to_publication_date:2022-12-31")
  )
})

test_that("the topic, journal and dates really are arguments, not fixed", {
  #the corpus has to be swappable, so check a different query end to end
  f <- build_oa_filter("radar", "2018-03-01", "2020-06-30", source = NULL)
  expect_equal(
    f,
    paste0("title_and_abstract.search:radar,type:article,has_abstract:true,",
           "from_publication_date:2018-03-01,to_publication_date:2020-06-30")
  )
})

test_that("can widen from one journal to a whole publisher", {
  f <- build_oa_filter("lidar", "2008-01-01", "2022-12-31",
                       source = NULL, publisher = "P4310319808")
  expect_equal(
    f,
    paste0("title_and_abstract.search:lidar,",
           "primary_location.source.publisher_lineage:P4310319808,",
           "type:article,has_abstract:true,",
           "from_publication_date:2008-01-01,",
           "to_publication_date:2022-12-31")
  )
})

test_that("rejects a date window that runs backwards", {
  expect_error(build_oa_filter("lidar", "2022-11-30", "2016-01-01"),
               "must be before")
})

test_that("rejects a date that is not in YYYY-MM-DD form", {
  expect_error(build_oa_filter("lidar", "30-11-2022", "2025-01-01"),
               "YYYY-MM-DD")
})

test_that("rejects an empty topic", {
  expect_error(build_oa_filter("", "2016-01-01", "2022-11-30"),
               "non-empty string")
})

# --- parsing a saved response ---

sample_json <- function() {
  system.file("extdata", "openalex_sample.json", package = "styloprofile")
}

test_that("reports how many records were parsed and how many dropped", {
  #the fixture holds one usable record, one with no abstract indexed, and one
  #abstract too short to compute sentence statistics from
  expect_message(read_corpus_json(sample_json()),
                 "Parsed 3 records; dropped 2")
})

test_that("keeps only the records with a usable abstract", {
  df <- read_corpus_json(sample_json(), verbose = FALSE)

  expect_equal(nrow(df), 1L)
  expect_equal(df$publication_date, "2022-01-31")
  expect_equal(df$publication_year, 2022L)
  expect_false(anyNA(df$abstract))
})

test_that("returns the documented columns", {
  df <- read_corpus_json(sample_json(), verbose = FALSE)
  expect_named(df, c("id", "doi", "title", "abstract",
                     "publication_date", "publication_year"))
})

test_that("the word floor is an argument", {
  #lowering it past the short abstract's 7 words keeps that record too
  df <- read_corpus_json(sample_json(), min_words = 5L, verbose = FALSE)
  expect_equal(nrow(df), 2L)
})

test_that("rejects a file that does not exist", {
  expect_error(read_corpus_json("no-such-file.json"), "no such file")
})

# --- the corpus is usable end to end ---

test_that("a parsed abstract produces the five features", {
  df <- read_corpus_json(sample_json(), verbose = FALSE)
  f <- stylo_features(df$abstract)

  expect_equal(nrow(f), 1L)
  expect_equal(ncol(f), 5L)
  expect_false(anyNA(f))
})

# --- the bundled corpora ---

test_that("the bundled corpora fall inside their intended date windows", {
  #the reference window has to close before ChatGPT was widely used, or the
  #corpus is not the human baseline it claims to be
  expect_true(all(lidar_reference$publication_date <= "2022-12-31"))
  expect_true(all(lidar_contrast$publication_date  >= "2023-01-01"))
})

test_that("the bundled corpora are complete and usable", {
  expect_equal(nrow(lidar_reference), 245L)
  expect_equal(nrow(lidar_contrast), 211L)
  expect_false(anyNA(lidar_reference$abstract))
  expect_false(anyNA(lidar_contrast$abstract))
})

test_that("both corpora come from the one journal the study is scoped to", {
  #holding the journal fixed is what removes venue as a source of variation
  expect_match(attr(lidar_reference, "filter"), "source.id:S117727964", fixed = FALSE)
  expect_match(attr(lidar_contrast, "filter"), "source.id:S117727964", fixed = FALSE)
})

test_that("the two corpora are close to balanced in size", {
  #the point of narrowing to one journal was a balanced comparison
  n1 <- nrow(lidar_reference); n2 <- nrow(lidar_contrast)
  expect_true(min(n1, n2) / max(n1, n2) > 0.8)
})

test_that("a profile built from the reference corpus scores the contrast corpus", {
  p <- build_profile(lidar_reference$abstract, verbose = FALSE)

  expect_s3_class(p, "stylo_profile")
  expect_equal(p$p, 5L)

  d_maha <- score(lidar_contrast$abstract, p, "mahalanobis")
  d_ang  <- score(lidar_contrast$abstract, p, "angular")

  expect_length(d_maha, nrow(lidar_contrast))
  expect_true(all(d_maha >= 0))
  expect_true(all(d_ang >= 0 & d_ang <= 1))
})
