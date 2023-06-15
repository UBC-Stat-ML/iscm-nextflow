#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")



read.csv("aggregated/lambdaInstantaneous.csv.gz") %>%
  filter(isAdapt == "false") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = beta, y = value, colour = factor(nPassesPerScan), linetype = factor(nPassesPerScan))) +
    geom_line()  + 
    scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("lambdaInstantaneous.pdf", width = 10, height = 5, limitsize = FALSE)
