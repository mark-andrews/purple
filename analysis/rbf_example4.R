data_df <- tibble(x = seq(1, 100, length.out = 1000) ,
       yf = sin(x),
       ys = sin(x * 0.1),
       f = yf + ys,
       y = f + rnorm(n = 1000, sd = 0.2))#%>% 
  #ggplot(aes(x,yf)) + geom_line() + geom_point()

rho = c(3, 12)
  
mu <- seq(0, 100, by = 25)
nu <- seq(0, 100, by = 2)

get_data <- function(data_df, centers, rho, psi){
  x <- data_df$x
  y <- data_df$y
  N <- length(x)
  K <- length(centers)
  Psi <- matrix(rep(0, N * K), nrow = N, ncol = K)
  for (i in 1:N) {
    for (j in 1:K) {
      Psi[i, j] = exp(-0.5 * (x[i] - centers[j])^2 / rho^2);
    }
  }
  colnames(Psi) <- str_c(psi, seq_along(centers))
  as_tibble(Psi) 
}

get_data(data_df, mu, rho[2]) %>% lm(y~., data=.) %>% predict() %>% plot()
get_data(data_df, nu, rho[1]) %>% lm(y~., data=.) %>%  predict() %>% plot()

get_data(data_df, mu, rho[2], psi='Psi') %>%
  bind_cols(select(data_df, y)) %>%
  lm(y ~ ., data = .) %>% predict() -> p0

get_data(data_df, nu, rho[1], psi='Psi') %>%
  bind_cols(select(data_df, y)) %>%
  lm(y ~ ., data = .) %>% predict() -> p1

bind_cols(get_data(data_df, mu, rho[2], psi='Psi'), get_data(data_df, nu, rho[1], psi='Phi')) %>%
  bind_cols(select(data_df, y)) %>% lm(y ~ ., data = .) %>% predict() -> p2

data_df %>% mutate(p0,p1,p2) %>%
  ggplot(aes(x=x,y=y)) + 
  geom_line(aes(y=p0), colour='red') +
  geom_line(aes(y=p1), colour='blue') +
  geom_line(aes(y=p2), colour='brown') +
  geom_point(size=0.5, alpha=0.5)

