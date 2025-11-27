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
    mutate(method = str_replace(method, "SAIS", "OAIS")) %>%
    mutate(method = str_replace(method, "SSMC", "OASMC")) %>%
    mutate(method = str_replace(method, "PT.*", "PT")) %>%
    spread(method, value)
df %>% ggplot(aes(x = PT, y = OAIS, color = model, label = model)) +
      guides(color="none") +
      geom_point() +
      geom_text(label = df$model, nudge_x = 2, alpha = 0.8) +
      labs(x=expression(Lambda[PT]), y=expression(Lambda)) +
      theme_minimal() +
      theme(axis.title.y = element_text(angle = 0, vjust=0.5))

ggsave("compare-global-lambdas.pdf", width = 5, height = 5, limitsize = FALSE)
