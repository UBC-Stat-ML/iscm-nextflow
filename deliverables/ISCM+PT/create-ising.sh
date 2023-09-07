#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")

read.csv("aggregated/annealingParameters.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  filter(model == "Ising") %>% 
  filter(method != "ISCM-original") %>%
  mutate(method = str_replace(method, "IAIS", "SAIS")) %>% 
  mutate(method = str_replace(method, "ISCM", "SSMC")) %>% 
  ggplot(aes(x = round, y = value, colour = chain, group = chain)) +
    geom_line()  + 
    facet_grid(.~method, scales = "free_y") +
    ylab("beta_i") +
    labs(color='index i')  +
    scale_y_log10() +
    theme_minimal()
ggsave("annealingParameters-ising.pdf", width = 10, height = 3, limitsize = FALSE)