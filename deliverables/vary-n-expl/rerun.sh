#!/usr/bin/env Rscript
  require("ggplot2")
  require("dplyr")
  require("stringr")
  require("scales")
  
  cc <- scales::seq_gradient_pal("grey", "black", "Lab")(seq(0,1,length.out=6))
  
  read.csv("aggregated/lambdaInstantaneous.csv.gz") %>%
    filter(isAdapt == "false") %>%
    mutate(model = str_replace(model, "[$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = beta, y = value, colour = factor(nPassesPerScan), group = factor(nPassesPerScan))) +
      labs(color='Expected updates
per exploration phase')  + 
      scale_colour_manual(values=cc) +
      geom_line()  + 
      scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("lambdaInstantaneous.pdf", width = 10, height = 4, limitsize = FALSE)
