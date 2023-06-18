#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("stringr")



read.csv("aggregated/lambdaInstantaneous.csv.gz") %>%
  filter(isAdapt == "false") %>%
  mutate(model = str_replace(model, "[$]Builder", "")) %>% 
  mutate(model = str_replace(model, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, ".*[.]", "")) %>% 
  mutate(method = str_replace(method, "IAIS", "SAIS")) %>% 
  mutate(method = str_replace(method, "ISCM", "SSMC")) %>% 
  mutate(model = str_replace(model, "HierarchicalRockets", "glm")) %>% 
  mutate(model = str_replace(model, "MRNATransfection", "ode")) %>% 
  mutate(model = str_replace(model, "SimpleMixture", "mixture")) %>% 
  mutate(model = str_replace(model, "SpikeSlabClassification", "spike-slab")) %>% 
  mutate(model = str_replace(model, "XY", "rotor")) %>% 
  ggplot(aes(x = beta, y = value, colour = method, linetype = method)) +
    geom_line()  + 
    scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
    ylab("local barrier") + 
    facet_wrap(~model, scales = "free_y") +
    theme_minimal()
ggsave("barriers.pdf", width = 10, height = 5, limitsize = FALSE)

