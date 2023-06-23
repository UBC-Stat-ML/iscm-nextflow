#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")

read.csv("aggregated/cumulativeLambda.csv") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value, colour = beta, group = beta)) +
    geom_line()  + 
    facet_grid(model~method, scales = "free_y") +
    theme_minimal()
ggsave("cumulativeLambdaEstimates.pdf", width = 10, height = 30, limitsize = FALSE)

read.csv("aggregated/globalLambda.csv") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value)) +
    geom_line()  + 
    facet_grid(model~method, scales = "free_y") +
    theme_minimal()
ggsave("globalLambdaEstimates.pdf", width = 10, height = 30, limitsize = FALSE)

timings <- read.csv("aggregated/roundTimings.csv") %>%
  group_by(model, method) %>%
  mutate(value = cumsum(value)) %>%
  mutate(nExplorationSteps = cumsum(nExplorationSteps))

read.csv("aggregated/lambdaInstantaneous.csv") %>%
  filter(isAdapt == "false") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = beta, y = value, colour = method, linetype = method)) +
    geom_line()  + 
    scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("lambdaInstantaneous.pdf", width = 10, height = 5, limitsize = FALSE)

read.csv("aggregated/energyExplCorrelation.csv") %>%
  filter(isAdapt == "false") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = beta, y = value)) +
    geom_line()  + 
    facet_wrap(~model) +
    theme_minimal()
ggsave("energyExplCorrelation.pdf", width = 10, height = 5, limitsize = FALSE)

read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value, colour = method)) +
    geom_line()  + 
    scale_x_log10() +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress-by-round.pdf", width = 10, height = 10, limitsize = FALSE)

read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
  inner_join(timings, by = c("model", "method", "round")) %>% 
  rename(value = value.x) %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = nExplorationSteps, y = value, colour = method, linetype = method)) +
    geom_line()  + 
    scale_x_log10() +
    xlab("number of exploration steps") +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress-by-nExpl.pdf", width = 10, height = 10, limitsize = FALSE)

read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
  inner_join(timings, by = c("model", "method", "round")) %>% 
  rename(time = value.y) %>%
  rename(value = value.x) %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = time, y = value, colour = method, linetype = method)) +
    geom_line()  + 
    scale_x_log10() +
    xlab("time (ms)") +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress.pdf", width = 10, height = 10, limitsize = FALSE)

read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
  inner_join(timings, by = c("model", "method", "round")) %>% 
  rename(time = value.y) %>%
  rename(value = value.x) %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  filter(round > 2) %>%
  ggplot(aes(x = time, y = value, colour = method, linetype = method)) +
    geom_line()  + 
    scale_x_log10() +
    xlab("time (ms)") +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress-suffix.pdf", width = 10, height = 10, limitsize = FALSE)

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
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress-by-nExpl-suffix.pdf", width = 10, height = 10, limitsize = FALSE)

read.csv("aggregated/annealingParameters.csv") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value, colour = chain, group = chain)) +
    geom_line()  + 
    facet_grid(model~method, scales = "free_y") +
    scale_y_log10() +
    theme_minimal()
ggsave("annealingParameters.pdf", width = 10, height = 30, limitsize = FALSE)
