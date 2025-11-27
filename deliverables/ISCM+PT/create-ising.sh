#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")

df <- read.csv("aggregated/annealingParameters.csv") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>%
  mutate(model = str_replace(model, ".*[.]", "")) %>%
  filter(model == "Ising") %>%
  mutate(method = str_replace(method, "SAIS", "OAIS")) %>%
  mutate(method = str_replace(method, "SSMC", "OASMC"))

# Add beta = 0 and final chain for PT
pt0 <- df %>%
  filter(str_detect(method, "^PT-")) %>%
  group_by(method, round) %>%
  filter(chain == max(chain)) %>%
  mutate(chain = chain + 1, value = 0)

# Compute u (t/T or n/N)
padded <- rbind(df, pt0) %>%
  group_by(method, round) %>%
  mutate(u = chain / max(chain)) %>%
  ungroup()

# PT has inverted chain indexing, so let's invert u
pt <- padded %>%
  filter(str_detect(method, "^PT-")) %>%
  mutate(u = 1-u)

# Split SMC so we can recombine with inverted PT dataset above
smc <- padded %>%
  filter(!str_detect(method, "^PT-"))

# Plot
final <- rbind(smc, pt)
final %>%
  ggplot(aes(x = round, y = value, colour = u, group = chain)) +
    geom_point(size=0.75)  +
    facet_grid(.~method, scales = "free_y") +
    ylab(expression(beta[i])) +
    labs(color='Scaled Index, u')  +
    theme_minimal() +
    theme(axis.title.y = element_text(angle = 0, vjust=0.5))
ggsave("ising.pdf", width = 10, height = 3, limitsize = FALSE)

