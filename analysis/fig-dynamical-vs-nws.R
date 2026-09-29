suppressMessages({
  library(dplyr); library(readr); library(ggplot2); library(here); library(tidyr)
})

pal <- c("dynamical.org GFS" = "#2E6F9E", "NWS (output/nws-forecasts-log.csv)" = "#C1502E")

dyn <- whychusModel::dynamical_gfs_forecasts |>
  filter(variable == "temperature_2m_max", lead_days %in% 1:7) |>
  transmute(run_date = issue_date, forecast_date = valid_date, lead_days,
            tmax = value, src = "dynamical.org GFS")

nws <- read_csv(here("output", "nws-forecasts-log.csv"), show_col_types = FALSE) |>
  filter(variable == "maxTemperature", lead_days %in% 1:7) |>
  transmute(run_date, forecast_date, lead_days, tmax = value,
            src = "NWS (output/nws-forecasts-log.csv)")

# keep only run dates present in both archives so the lines are comparable
shared_runs <- intersect(unique(dyn$run_date), unique(nws$run_date))

d <- bind_rows(dyn, nws) |>
  filter(run_date %in% shared_runs) |>
  mutate(src = factor(src, levels = names(pal)),
         lead_lab = factor(paste0("Lead ", lead_days, ifelse(lead_days == 1, " day", " days")),
                           levels = paste0("Lead ", 1:7, c(" day", rep(" days", 6)))))

# per-lead agreement between the two sources, annotated on each facet
agree <- d |>
  pivot_wider(id_cols = c(run_date, forecast_date, lead_days, lead_lab),
              names_from = src, values_from = tmax) |>
  rename(dyn = `dynamical.org GFS`, nws = `NWS (output/nws-forecasts-log.csv)`) |>
  filter(!is.na(dyn), !is.na(nws)) |>
  group_by(lead_lab) |>
  summarise(n = n(),
            md = mean(dyn - nws),
            mae = mean(abs(dyn - nws)),
            r = cor(dyn, nws), .groups = "drop") |>
  mutate(lab = sprintf("n = %d   mean diff = %+.2f °C   MAE = %.2f °C   r = %.2f",
                       n, md, mae, r))

rng <- range(d$forecast_date)

p <- ggplot(d, aes(forecast_date, tmax, colour = src)) +
  geom_line(linewidth = 0.55, alpha = 0.9) +
  geom_text(data = agree, inherit.aes = FALSE,
            aes(x = rng[1], y = Inf, label = lab),
            hjust = 0, vjust = 1.5, size = 3, colour = "grey30") +
  facet_wrap(~lead_lab, ncol = 1, strip.position = "right") +
  scale_colour_manual(values = pal, name = NULL) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%b %d",
               expand = expansion(mult = c(0.01, 0.01))) +
  coord_cartesian(clip = "off") +
  labs(title = "Forecast daily maximum air temperature: dynamical.org GFS vs. the served NWS forecasts",
       subtitle = sprintf("Whychus Creek grid cell — %s to %s, %d run dates common to both archives, plotted by forecast (valid) date",
                          format(rng[1], "%b %d %Y"), format(rng[2], "%b %d %Y"),
                          length(shared_runs)),
       x = "Forecast date", y = expression("Daily "*T[max]*" ("*degree*"C)")) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "top",
        legend.justification = "left",
        strip.text.y.right = element_text(face = "bold", angle = 0, hjust = 0),
        plot.title = element_text(face = "bold"))

ggsave(here("output", "dynamical_vs_nws_tmax.png"), p,
       width = 11, height = 13, dpi = 300, bg = "white")

cat("\n--- agreement by lead ---\n"); print(as.data.frame(agree[, c("lead_lab","n","md","mae","r")]))
cat("\nshared run dates:", length(shared_runs),
    "range:", format(range(shared_runs)), "\n")
cat("wrote output/dynamical_vs_nws_tmax.png\n")
