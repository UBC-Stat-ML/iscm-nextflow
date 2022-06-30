#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")

timings <- read.csv("aggregated/roundTimings.csv.gz")

read.csv("aggregated/lambdaInstantaneous.csv.gz") %>%
  filter(isAdapt == "false") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  ggplot(aes(x = beta, y = value, colour = method)) +
    geom_line()  + 
    scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("lambdaInstantaneous.pdf", width = 4, height = 4)

read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value, colour = method)) +
    geom_line()  + 
    scale_x_log10() +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress-by-round.pdf", width = 4, height = 4)

read.csv("aggregated/annealingParameters.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value, colour = chain, group = chain)) +
    geom_line()  + 
    facet_grid(model~method, scales = "free_y") +
    scale_y_log10() +
    theme_minimal()
ggsave("annealingParameters.pdf", width = 4, height = 4)
