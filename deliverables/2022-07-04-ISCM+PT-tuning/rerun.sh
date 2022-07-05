#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")



timings <- read.csv("aggregated/roundTimings.csv.gz") %>%
  group_by(model, method, seed, nParticles) %>%
  mutate(value = cumsum(value))



read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value, colour = factor(paste0(method, "_", nParticles)), linetype = factor(seed))) +
    geom_line()  + 
    scale_x_log10() +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress-by-round.pdf", width = 10, height = 10, limitsize = FALSE)

read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
  inner_join(timings, by = c("model", "method", "round", "seed", "nParticles")) %>% 
  rename(time = value.y) %>%
  rename(value = value.x) %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  ggplot(aes(x = time, y = value, colour = factor(paste0(method, "_", nParticles)), linetype = factor(seed))) +
    geom_line()  + 
    scale_x_log10() +
    xlab("time (ms)") +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress.pdf", width = 10, height = 10, limitsize = FALSE)
