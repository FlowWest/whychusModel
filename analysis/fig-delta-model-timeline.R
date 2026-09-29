suppressMessages({ library(ggplot2); library(here); library(grid) })

obs_col <- "#2F6B4F"   # observed / sensors
fc_col  <- "#2E6F9E"   # forecast / GFS
det_col <- "#7A6A55"   # deterministic (day of year)
tgt_col <- "#C1502E"   # target / delta
ink     <- "#20262B"

# A labelled band: rectangle spanning [x0, x1] with up to two rows of
# predictor names (monospace) and one caption line underneath.
band <- function(x0, x1, y, names, caption, col, alpha = 0.15) {
  xm <- (x0 + x1) / 2
  n  <- length(names)
  # vertical offsets: 1 name row -> centred; 2 name rows -> stacked above caption
  ys <- if (n == 1) y + 0.14 else c(y + 0.28, y + 0.03)
  c(
    list(annotate("rect", xmin = x0, xmax = x1, ymin = y - H/2, ymax = y + H/2,
                  fill = col, alpha = alpha, colour = NA)),
    lapply(seq_len(n), function(i)
      annotate("text", x = xm, y = ys[i], label = names[i],
               size = 3.2, colour = col, family = "mono")),
    list(annotate("text", x = xm, y = y - 0.24, label = caption,
                  size = 2.9, colour = col))
  )
}

H   <- 0.88
y1  <- 5.95; y2 <- 4.98; y3 <- 4.01
yax <- 2.60
ytg <- 1.50

p <- ggplot() +

  # ---- region backgrounds ------------------------------------------------
  annotate("rect", xmin = -5.45, xmax = 0, ymin = 3.45, ymax = 6.62,
           fill = obs_col, alpha = 0.055) +
  annotate("rect", xmin = 0, xmax = 7.45, ymin = 3.45, ymax = 6.62,
           fill = fc_col, alpha = 0.055) +

  annotate("text", x = -5.30, y = 6.82, hjust = 0, size = 4.1, fontface = "bold",
           colour = obs_col, label = "OBSERVED  —  in-stream & gauge sensors") +
  annotate("text", x = 7.30, y = 6.82, hjust = 1, size = 4.1, fontface = "bold",
           colour = fc_col, label = "FORECAST  —  dynamical.org GFS") +

  # ---- observed bands ----------------------------------------------------
  band(-5, -1, y1,
       "cp_flow_trend   cp_7dadm_trend",
       "5-day slope, d−1 → d−5", obs_col) +
  band(-5, 0, y2,
       "dadm_trend   tmax_trend",
       "5-day slope, d0 → d−5", obs_col) +
  band(-5, 0, y3,
       c("cp_flow_mean   cp_7dadm   cp_tmax", "dadm_m0   tmax_m0"),
       "point values read on the run date", obs_col) +

  # ---- forecast bands ----------------------------------------------------
  band(1, 7, y1,
       "air_max_d1…dk   air_min_d1…dk   cloud_d1…dk",
       "one value per forecast day", fc_col) +
  band(1, 7, y2,
       c("traj_air_max_max   traj_air_max_mean",
         "traj_air_min_mean   traj_warming"),
       "summaries of the whole d1…dk window", fc_col) +
  band(1, 7, y3,
       "julian_d1…dk",
       "day of year — known with certainty, not forecast", det_col) +

  # ---- timeline axis -----------------------------------------------------
  annotate("segment", x = -5.45, xend = 7.75, y = yax, yend = yax,
           colour = ink, linewidth = 0.7,
           arrow = arrow(length = unit(0.16, "cm"), type = "closed")) +
  annotate("segment", x = -5:7, xend = -5:7, y = yax - 0.09, yend = yax + 0.09,
           colour = ink, linewidth = 0.5) +
  annotate("text", x = -5:7, y = yax - 0.31, size = 3.1, colour = ink,
           label = c(paste0("d−", 5:1), "d0", paste0("d+", 1:7))) +

  # ---- run-date marker ---------------------------------------------------
  annotate("segment", x = 0, xend = 0, y = ytg, yend = 6.62,
           colour = tgt_col, linewidth = 0.8, linetype = "22") +
  annotate("point", x = 0, y = yax, colour = tgt_col, size = 3) +
  annotate("text", x = 0, y = 7.22, size = 3.7, fontface = "bold",
           colour = tgt_col, label = "RUN DATE  ·  7 pm PST daily") +

  # ---- target row --------------------------------------------------------
  annotate("segment", x = 7, xend = 7, y = ytg, yend = yax - 0.16,
           colour = tgt_col, linewidth = 0.4, linetype = "22") +
  annotate("segment", x = 0, xend = 6.92, y = ytg, yend = ytg,
           colour = tgt_col, linewidth = 1.0,
           arrow = arrow(length = unit(0.20, "cm"), type = "closed")) +
  annotate("point", x = 0, y = ytg, colour = tgt_col, size = 2.8) +
  annotate("text", x = 3.5, y = ytg + 0.27, size = 3.7, fontface = "bold",
           colour = tgt_col, label = "the model predicts this CHANGE") +
  annotate("text", x = 0, y = ytg - 0.32, size = 3.2, colour = tgt_col,
           family = "mono", label = "dadm_m0") +
  annotate("text", x = 0, y = ytg - 0.60, size = 2.9, colour = tgt_col,
           label = "observed 7DADM today") +
  annotate("text", x = 7, y = ytg - 0.32, size = 3.2, colour = tgt_col,
           fontface = "bold", label = "forecast 7DADM") +
  annotate("text", x = 7, y = ytg - 0.60, size = 2.9, colour = tgt_col,
           label = "= dadm_m0 + predicted change") +

  # ---- frame -------------------------------------------------------------
  labs(title = "RM 8.5 delta model — what the model knows, and when",
       subtitle = paste0("Every predictor is fixed as of the run date: observed history behind it, ",
                         "forecast weather ahead of it.   k = lead, 1–7 days.")) +
  scale_x_continuous(limits = c(-6.0, 8.95)) +
  scale_y_continuous(limits = c(0.60, 7.45)) +
  theme_void(base_size = 12) +
  theme(plot.title    = element_text(face = "bold", size = 15, colour = ink,
                                     margin = margin(b = 3)),
        plot.subtitle = element_text(size = 10.5, colour = "grey35",
                                     margin = margin(b = 2)),
        plot.margin   = margin(12, 10, 10, 10),
        plot.background = element_rect(fill = "white", colour = NA))

ggsave(here("output", "delta_model_timeline.png"), p,
       width = 13, height = 6.6, dpi = 300, bg = "white")
cat("wrote output/delta_model_timeline.png\n")
