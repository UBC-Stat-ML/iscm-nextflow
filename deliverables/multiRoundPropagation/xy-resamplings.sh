#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")

read.csv("aggregated/multiRoundPropagation.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  filter(model == "XY") %>%
  filter(round > 4 & round < 11) %>%
  ggplot(aes(x = iteration, y = ess)) +
    geom_line()  + 
    facet_grid(.~round, scales = "free", labeller = labeller(round = label_both)) +
    theme_bw()
ggsave("xy-multiRoundPropagation-by-iteration.pdf", width = 10, height = 2, limitsize = FALSE)
