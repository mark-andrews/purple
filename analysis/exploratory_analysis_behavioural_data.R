#library(tidyverse)
#library(purputils)

behav_df <- read_behavioural_results("raw-data/aug_sept_2023/")

# Dots task accuracy ------------------------------------------------------

# avg accuracy for each subject for each dots delta (difference in number of
# dots in the two arrays)
dots_accuracy_summary_df <-
  behav_df %>%
  filter(type == "dots") %>%
  mutate(delta = abs(left_size - right_size)) %>%
  drop_na() %>%
  group_by(subject, delta) %>%
  summarize(accuracy = mean(accuracy), .groups = "drop")


# plot as facet
dots_accuracy_summary_df %>%
  ggplot(aes(x = delta, y = accuracy, colour = subject)) +
  geom_point(size = 0.5) +
  stat_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.25) +
  facet_wrap(~subject) +
  theme_minimal() +
  theme(legend.position = "none")

# plot as noodle plot
dots_accuracy_summary_df %>%
  ggplot(aes(x = delta, y = accuracy)) +
  geom_line(aes(group = subject),
    stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.33, linetype = "dashed"
  ) +
  geom_line(stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), colour = "red", size = 1.5) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.25), limits = c(0, 1.1)) +
  theme_minimal() +
  theme(legend.position = "none")



# Dots task reaction time -------------------------------------------------

# avg rt for each subject for each dots delta (difference in number of
# dots in the two arrays) when accurate or not
dots_rt_summary_df <-
  behav_df %>%
  filter(type == "dots") %>%
  mutate(delta = abs(left_size - right_size)) %>%
  drop_na() %>%
  group_by(subject, delta, accuracy) %>%
  summarize(rt = mean(rt), .groups = "drop")


# avg rt for *accurate* trials for each subject by each delta
dots_rt_summary_df %>%
  filter(accuracy) %>%
  ggplot(aes(x = delta, y = rt, colour = subject)) +
  geom_point(size = 0.5) +
  stat_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.25) +
  facet_wrap(~subject, scales = "free_y") +
  theme_minimal() +
  theme(legend.position = "none")

# avg rt for *accurate* trials plot as noodle plot
dots_rt_summary_df %>%
  ggplot(aes(x = delta, y = rt)) +
  geom_line(aes(group = subject),
    stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.33, linetype = "dashed"
  ) +
  geom_line(stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), colour = "red", size = 1.5) +
  scale_y_continuous(breaks = seq(0, 3, by = 0.25)) +
  theme_minimal() +
  theme(legend.position = "none")


# avg rt for *accurate* trials plot as noodle plot; removing s41 from plot
dots_rt_summary_df %>%
  # remove s41 with the high reaction time
  filter(subject != "s41") %>%
  ggplot(aes(x = delta, y = rt)) +
  geom_line(aes(group = subject),
    stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.33, linetype = "dashed"
  ) +
  geom_line(stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), colour = "red", size = 1.5) +
  scale_y_continuous(breaks = seq(0, 2, by = 0.25), limits = c(0, 2.1)) +
  theme_minimal() +
  theme(legend.position = "none")



# Blobs task accuracy ------------------------------------------------------

# blobs accuracy for each subject for each blobs size delta decile
blobs_accuracy_summary_df <-
  behav_df %>%
  filter(type == "blobs") %>%
  mutate(delta = abs(left_size - right_size)) %>%
  drop_na() %>%
  mutate(delta = ntile(delta, 10)) %>%
  group_by(subject, delta) %>%
  summarize(accuracy = mean(accuracy), .groups = "drop")


# blobs accuracy plot as facet
blobs_accuracy_summary_df %>%
  ggplot(aes(x = delta, y = accuracy, colour = subject)) +
  geom_point(size = 0.5) +
  stat_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.25) +
  facet_wrap(~subject) +
  theme_minimal() +
  theme(legend.position = "none")

# blobs accuracy plot as noodle plot
blobs_accuracy_summary_df %>%
  ggplot(aes(x = delta, y = accuracy)) +
  geom_line(aes(group = subject),
    stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.33, linetype = "dashed"
  ) +
  geom_line(stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), colour = "red", size = 1.5) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.25), limits = c(0, 1.1)) +
  theme_minimal() +
  theme(legend.position = "none")


# blobs task rt -----------------------------------------------------------

# avg rt for each subject for each blobs size delta decile
blobs_rt_summary_df <-
  behav_df %>%
  filter(type == "blobs") %>%
  mutate(delta = abs(left_size - right_size)) %>%
  drop_na() %>%
  mutate(delta = ntile(delta, 10)) %>%
  group_by(subject, delta, accuracy) %>%
  summarize(rt = mean(rt), .groups = "drop")

# avg rt for *accurate* trials for each subject by each delta
blobs_rt_summary_df %>%
  filter(accuracy) %>%
  ggplot(aes(x = delta, y = rt, colour = subject)) +
  geom_point(size = 0.5) +
  stat_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.25) +
  facet_wrap(~subject, scales = "free_y") +
  theme_minimal() +
  theme(legend.position = "none")

# avg rt for *accurate* trials plot as noodle plot
blobs_rt_summary_df %>%
  ggplot(aes(x = delta, y = rt)) +
  geom_line(aes(group = subject),
    stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), alpha = 0.33, linetype = "dashed"
  ) +
  geom_line(stat = "smooth", method = "gam", formula = y ~ s(x, bs = "cs"), colour = "red", size = 1.5) +
  scale_y_continuous(breaks = seq(0, 2.5, by = 0.25)) +
  theme_minimal() +
  theme(legend.position = "none")
