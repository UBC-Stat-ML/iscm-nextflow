require("ggplot2")
require("dplyr")
require("stringr")
require("tidyverse")


df = read.csv("aggregated/globalLambda.csv") %>%
    mutate(model = str_replace(model, "[$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    filter(round == 14) %>%
    select(method, value, model) %>%
    filter(method == "SAIS" | method == "PT-10") %>%
    mutate(method = str_replace(method, "PT.*", "PT")) %>% 
    spread(method, value)
df %>% ggplot(aes(x = PT, y = SAIS, color = model, label = model)) +
      guides(color="none") +
      geom_point() + 
      geom_text(label = df$model, nudge_x = 2, alpha = 0.8) +
      theme_minimal()

ggsave("compare-global-lambdas.pdf", width = 5, height = 5, limitsize = FALSE)
