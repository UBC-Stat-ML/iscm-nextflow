#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")

mrp <- read.csv("aggregated/multiRoundPropagation.csv.gz")
max_round <- max(mrp$round)
mrp <- mrp %>%
  filter(round == max_round) 

p <- read.csv("aggregated/propagation.csv.gz")
df <- bind_rows(mrp, p)

maxIter <- df %>%
  group_by(method, model) %>%
  summarize(max_iter = max(iteration))

df <- df %>% 
  inner_join(maxIter) %>%
  mutate(relative_iter = iteration/max_iter)

df %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  ggplot(aes(x = relative_iter, y = annealingParameter, linetype = method, color = method)) +
    geom_line(alpha = 0.8) + 
    facet_wrap(~model) +
    theme_minimal()
ggsave("annealingSchedules.pdf", width = 10, height = 10, limitsize = FALSE)
