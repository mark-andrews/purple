library(tidyverse)
library(arrow)

x <- read_feather('pyutils/X.feather')
xx <- pivot_longer(x, cols = -time, names_to = 'channel', values_to = 'value')

ggplot(samxx,
       aes(x = time, y = value)
) + geom_point(size = 0.5, alpha = 0.5) + facet_wrap(~channel)
