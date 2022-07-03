#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")

read.csv("aggregated/multiRoundPropagation.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  ggplot(aes(x = iteration, y = ess)) +
    geom_line()  + 
    facet_grid(model~round, scales = "free_y") +
    theme_bw()
ggsave("multiRoundPropagation-by-iteration.pdf", width = 100, height = 15, limitsize = FALSE)
