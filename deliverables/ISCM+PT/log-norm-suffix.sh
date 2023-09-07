#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")


timings <- read.csv("aggregated/roundTimings.csv") %>%
  group_by(model, method) %>%
  mutate(value = cumsum(value)) %>%
  mutate(nExplorationSteps = cumsum(nExplorationSteps))


read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
  inner_join(timings, by = c("model", "method", "round")) %>% 
  rename(value = value.x) %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  filter(round > 2) %>%
  ggplot(aes(x = nExplorationSteps, y = value, colour = method, linetype = method)) +
    geom_line()  + 
    scale_x_log10() +
    xlab("number of exploration steps") +
    ylab("log normalization estimate") +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("log-norm-suffix.pdf", width = 10, height = 5, limitsize = FALSE)