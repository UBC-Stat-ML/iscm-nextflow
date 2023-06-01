#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")

read.csv("aggregated/multiRoundPropagation.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = iteration, y = ess, colour = method, linetype = method)) +
    geom_line()  + 
    facet_grid(model~round, scales = "free") +
    theme_minimal()
ggsave("multiRoundPropagation-by-iteration.pdf", width = 35, height = 20, limitsize = FALSE)

preds <- read.csv("aggregated/predictedResamplingInterval.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  filter(method == "ISCM")
preds$type <- 'predicted'
actuals <- read.csv("aggregated/multiRoundResampling.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  filter(method == "ISCM") %>%
  rename(value = deltaIterations)
actuals$type <- 'actual'

actuals %>%
  full_join(preds, by = c("model", "method", "round", "type", "value")) %>%
  ggplot(aes(x = round, y = value, colour = type)) +
    geom_point() + 
    facet_wrap(~model) +
    theme_minimal()
ggsave("preds.pdf", width = 10, height = 5, limitsize = FALSE)

timings <- read.csv("aggregated/roundTimings.csv.gz") %>%
  group_by(model, method) %>%
  mutate(value = cumsum(value)) %>%
  mutate(nExplorationSteps = cumsum(nExplorationSteps))

read.csv("aggregated/lambdaInstantaneous.csv.gz") %>%
  filter(isAdapt == "false") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = beta, y = value, colour = method, linetype = method)) +
    geom_line()  + 
    scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("lambdaInstantaneous.pdf", width = 10, height = 5, limitsize = FALSE)

read.csv("aggregated/energyExplCorrelation.csv.gz") %>%
  filter(isAdapt == "false") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = beta, y = value)) +
    geom_line()  + 
    facet_wrap(~model) +
    theme_minimal()
ggsave("energyExplCorrelation.pdf", width = 10, height = 5, limitsize = FALSE)

read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value, colour = method)) +
    geom_line()  + 
    scale_x_log10() +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress-by-round.pdf", width = 10, height = 10, limitsize = FALSE)

read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
  inner_join(timings, by = c("model", "method", "round")) %>% 
  rename(value = value.x) %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = nExplorationSteps, y = value, colour = method, linetype = method)) +
    geom_line()  + 
    scale_x_log10() +
    xlab("time (ms)") +
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("logNormalizationConstantProgress-by-nExpl.pdf", width = 10, height = 10, limitsize = FALSE)

read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
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

read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
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

read.csv("aggregated/annealingParameters.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  ggplot(aes(x = round, y = value, colour = chain, group = chain)) +
    geom_line()  + 
    facet_grid(model~method, scales = "free_y") +
    scale_y_log10() +
    theme_minimal()
ggsave("annealingParameters.pdf", width = 10, height = 30, limitsize = FALSE)

read.csv("aggregated/annealingParameters.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = method) %>%
  filter(isAdapt == "false") %>% 
  filter(method == "ISCM") %>%
  ggplot(aes(x = chain, y = value)) +
    geom_line()  + 
    facet_grid(method~model, scales = "free_x") +
    theme_minimal()
ggsave("annealingParameters-final.pdf", width = 30, height = 5, limitsize = FALSE)

read.csv("aggregated/annealingParameters.csv.gz") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = method) %>%
  filter(isAdapt == "false") %>% 
  filter(method == "ISCM") %>%
  ggplot(aes(x = chain, y = value)) +
    geom_line()  + 
    scale_y_log10() +
    facet_grid(method~model, scales = "free_x") +
    theme_minimal()
ggsave("annealingParameters-log-final.pdf", width = 30, height = 5, limitsize = FALSE)
