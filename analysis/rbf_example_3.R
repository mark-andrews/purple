# Load rstan library
#library(rstan)
#library(tidyverse)

data_df <- read_csv("analysis/s13_b2_t14.csv")

# Specify the data generated in the previous step
N <- nrow(data_df)  # number of data points
x <- data_df$x      # input data (x)
y <- data_df$y  # observed output data (y)


get_model <- function(K, rho){
  # Specify the centers for the RBFs
  centers <- seq(-250, 1000, length.out = K)  # manually specify centers for the RBFs
  
  Psi <- matrix(rep(0, N * K), nrow = N, ncol = K)
  for (i in 1:N) {
    for (j in 1:K) {
      Psi[i, j] = exp(-0.5 * (x[i] - centers[j])^2 / rho^2);
    }
  }
  colnames(Psi) <- str_c('Psi', seq_along(centers))
  data_df <- as_tibble(Psi) %>% mutate(y = y, x = x)
  #data_df
  lm(y ~ ., data = data_df)
}

data_grid_df <- expand_grid(K = seq(5, 250, by = 5), rho = seq(1, 50, by = 5)) 
data_grid_df$AIC <- data_grid_df %>% pmap_dbl(~AIC(get_model(.x,.y)))

ggplot(data_grid_df,
       aes(x = rho, y = AIC)
) + geom_line() + geom_point() +
  facet_wrap(~K)

m <- gam(y~s(x),data=data_df)
data_df %>% mutate(pred = predict(m)) %>% 
  ggplot(aes(x=x,y=y)) + 
  geom_line(aes(y=pred), colour='red') + 
  geom_point(size=0.5,alpha=0.4) 
  
