library(tidyverse)

get_pvalue_random_effects_model <- function(delta = 0.3, sigma = 1.0, tau = 2.0, J = 50, N = 200){
  
  psi <- rnorm(n = J, mean = 0, sd = tau)
  
  lmerTest::lmer(y ~ (1|Subject), 
                 data = set_names(psi, nm = str_c('s',seq_along(psi))) %>% 
                   map_dfc(~rnorm(n = N, mean = delta + ., sd = sigma)) %>% 
                   pivot_longer(cols = everything(), names_to = 'Subject', values_to = 'y')) %>% 
    summary() %>% 
    magrittr::use_series('coefficients') %>% 
    as_tibble() %>%
    unlist() %>% 
    magrittr::extract('Pr(>|t|)') %>% 
    unname()
  
  
}

get_power <- function(niter = 1000, delta = 0.3, sigma = 1.0, tau = 2.0, J = 50, N = 200){
  mean(replicate(niter, get_pvalue_random_effects_model(delta, sigma, tau, J, N)) < 0.05)
}

get_power(niter = 100, tau = 0.5)
