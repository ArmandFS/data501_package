# Builds the two bundled corpora. Run by hand, not during R CMD check --
# data-raw/ is listed in .Rbuildignore.
#
# Scope is deliberately narrow: lidar articles in a single journal, the IEEE
# Journal of Selected Topics in Applied Earth Observations and Remote Sensing
# (OpenAlex source S117727964). Holding the journal fixed removes venue as a
# source of stylistic variation, and abstracts within one journal run to a
# similar length, so the features are comparable across documents.
#
# The split is the calendar year: the reference corpus closes at the end of
# 2022, weeks after ChatGPT was released, and the contrast corpus opens in
# 2023. Both groups are small enough to ship whole, so there is no sampling
# step and the datasets are exactly what the query returns.

library(styloprofile)

topic <- "lidar"
journal <- "S117727964"
mail <- "actuallyarmand@gmail.com"

lidar_reference <- fetch_corpus(topic, from = "2008-01-01", to = "2022-12-31",
                                source = journal, max_n = 1000L, mailto = mail)
lidar_contrast  <- fetch_corpus(topic, from = "2023-01-01", to = "2026-12-31",
                                source = journal, max_n = 1000L, mailto = mail)

message(sprintf("reference: %d of %d available", nrow(lidar_reference),
                attr(lidar_reference, "n_available")))
message(sprintf("contrast:  %d of %d available", nrow(lidar_contrast),
                attr(lidar_contrast, "n_available")))

rownames(lidar_reference) <- NULL
rownames(lidar_contrast) <- NULL

usethis::use_data(lidar_reference, lidar_contrast,
                  compress = "xz", overwrite = TRUE)
