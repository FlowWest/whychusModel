library(shiny)
library(tidyverse)
library(lubridate)
library(zoo)
library(here)
library(whychusModel)
library(randomForest)
library(plotly)

# ── Data ────────────────────────────────────────────────────────────────────────
load(here("data", "rm_8_5_historical.rda"))
load(here("data", "camp_polk_flow_historical.rda"))
load(here("data", "all_historical_forecasts.rda"))
load(here("data", "camp_polk_temperature_historical.rda"))

target_C <- 20.0

rm85_daily <- rm_8_5_historical |>
  mutate(date = as.Date(date)) |>
  filter(statistic %in% c("max", "7DADM")) |>
  select(date, statistic, temperature) |>
  pivot_wider(names_from = statistic, values_from = temperature) |>
  rename(tmax = max, dadm_7 = `7DADM`) |>
  arrange(date)

exceed_all <- rm85_daily |>
  filter(dadm_7 > target_C, !is.na(dadm_7)) |>
  arrange(date)

air_temp_daily <- all_historical_forecasts |>
  filter(variable %in% c("temperature_2m_max", "temperature_2m_min")) |>
  group_by(date = valid_date, variable) |>
  summarise(value = mean(value, na.rm = TRUE), .groups = "drop") |>
  pivot_wider(names_from = variable, values_from = value)

flow_daily <- camp_polk_flow_historical |>
  filter(statistic == "mean") |>
  select(date, flow_cfs)

cp_temp_daily <- camp_polk_temperature_historical |>
  mutate(date = as.Date(date)) |>
  filter(statistic == "7DADM") |>
  select(date, cp_7dadm = temperature)

avail_years <- sort(unique(year(exceed_all$date)), decreasing = TRUE)

# ── Flow sweep setup ────────────────────────────────────────────────────────────
lead_days_vec <- c(1L, 3L, 7L)

rf_models <- setNames(
  lapply(lead_days_vec, function(k)
    readRDS(here("output", sprintf("rm85_rf_7dadm_lead%d.rds", k)))),
  as.character(lead_days_vec)
)

flow_range <- quantile(flow_daily$flow_cfs, c(0.05, 0.95), na.rm = TRUE)
flow_grid  <- seq(flow_range[1], flow_range[2], length.out = 200)

cp_flow_temp_hist <- flow_daily |>
  inner_join(cp_temp_daily, by = "date") |>
  filter(month(date) %in% 6:9, !is.na(flow_cfs), !is.na(cp_7dadm))

cp_temp_lm <- lm(cp_7dadm ~ log(flow_cfs), data = cp_flow_temp_hist)

cp_temp_at_flow <- function(q) {
  as.numeric(predict(cp_temp_lm, newdata = data.frame(flow_cfs = pmax(q, 1))))
}

cp_temp_delta <- function(t_obs, q, q_obs) {
  t_obs + (cp_temp_at_flow(q) - cp_temp_at_flow(q_obs))
}

get_wx <- function(d, var, k) {
  v <- all_historical_forecasts |>
    filter(valid_date == d, variable == var, lead_days == k) |>
    pull(value)
  if (length(v) == 0 || all(is.nan(v))) NA_real_ else v[1]
}

safe1 <- function(df_filter_expr) {
  v <- df_filter_expr
  if (length(v) == 0 || all(is.na(v))) NA_real_ else v[1]
}

# ── Helpers ──────────────────────────────────────────────────────────────────────
clr_rm85   <- "#e67e22"
clr_flow   <- "#2c7bb6"
clr_air    <- "#8e44ad"
clr_exceed <- "#c0392b"
clr_grey   <- "#7f8c8d"

lead_colors <- c("1" = "#D4A853", "3" = "#C07038", "7" = "#185FA5")
lead_labels <- c("1" = "1-day lead", "3" = "3-day lead", "7" = "7-day lead")

base_theme <- function() {
  theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      plot.title       = element_text(size = 12, face = "bold", color = "#1a3a5c"),
      plot.subtitle    = element_text(size = 10, color = "#666"),
      axis.title.y     = element_text(size = 10),
      axis.text.x      = element_text(size = 9)
    )
}

stat_box <- function(val, label, color = "#2c7bb6") {
  div(
    style = sprintf(
      "background:#f8f9fa; border-radius:6px; padding:10px 14px; margin-bottom:8px;
       border-left: 4px solid %s;", color
    ),
    div(style = "font-size:22px; font-weight:700; color:#1a3a5c;", val),
    div(style = "font-size:11px; color:#888; text-transform:uppercase; letter-spacing:0.5px;",
        label)
  )
}

fmt_date <- function(d) format(d, "%b %d")

# ── UI ──────────────────────────────────────────────────────────────────────────
ui <- fluidPage(
  tags$head(tags$style(HTML("
    body        { font-family: 'Segoe UI', sans-serif; background:#f4f6f9; color:#2d3436; }
    .card       { background:white; border-radius:8px; border:1px solid #dde3ec;
                  padding:16px 20px; margin-bottom:12px; }
    h2          { color:#1a3a5c; font-weight:700; margin-bottom:2px; }
    h4          { color:#2c5f8a; font-weight:600; margin-top:0; }
    .subtitle   { color:#666; font-size:14px; margin-bottom:20px; margin-top:0; }
    label       { font-weight:600; font-size:13px; color:#444; }
    .page-title { padding:20px 10px 8px; }
    select[size] { font-size:12px; }
    .offset-row { display:flex; justify-content:space-between; align-items:center;
                  padding:5px 0; border-bottom:1px solid #eee; font-size:12px; }
    .offset-row:last-child { border-bottom:none; }
    .offset-lead { color:#666; font-weight:600; min-width:60px; }
    .offset-val  { color:#1a3a5c; font-weight:700; }
    .offset-gap  { font-size:11px; color:#888; }
    .not-achievable { color:#c0392b; font-style:italic; font-size:11px; }
  "))),

  fluidRow(
    column(12, div(class = "page-title",
      h2("RM 8.5 Exceedance Explorer"),
      p("Select a historical 7DADM exceedance to examine the conditions that drove it and
        what Camp Polk flow would have been needed to prevent it. Shading marks the 7 days
        that average into the 7DADM.",
        class = "subtitle")
    ))
  ),

  fluidRow(
    # ── Sidebar ────────────────────────────────────────────────────────────────
    column(3,
      div(class = "card",
        h4("Select Exceedance"),
        selectInput("sel_year", "Year",
                    choices  = avail_years,
                    selected = avail_years[1]),
        uiOutput("date_ui"),

        hr(style = "border-color:#eee; margin:12px 0;"),
        h4("7-Day Window Conditions", style = "font-size:13px; margin-bottom:10px;"),
        uiOutput("stats_ui"),

        hr(style = "border-color:#eee; margin:12px 0;"),
        h4("Flow Offset to Prevent Exceedance", style = "font-size:13px; margin-bottom:6px;"),
        p("Minimum sustained Camp Polk flow estimated to hold 7DADM ≤ 20°C",
          style = "font-size:11px; color:#888; margin-top:0; margin-bottom:10px;"),
        uiOutput("offset_ui")
      )
    ),

    # ── Plots ─────────────────────────────────────────────────────────────────
    column(9,
      div(class = "card", plotlyOutput("temp_plot",    height = "200px")),
      div(class = "card", plotlyOutput("flow_plot",    height = "175px")),
      div(class = "card", plotlyOutput("airtemp_plot", height = "175px")),
      div(class = "card", plotlyOutput("sweep_plot",   height = "220px"))
    )
  )
)

# ── Server ──────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  year_exceed <- reactive({
    exceed_all |> filter(year(date) == as.integer(input$sel_year))
  })

  output$date_ui <- renderUI({
    df <- year_exceed()
    choices <- setNames(
      as.character(df$date),
      sprintf("%s  (%.1f°C)", format(df$date, "%b %d"), round(df$dadm_7, 1))
    )
    selectInput("sel_date", "Exceedance Date",
                choices   = choices,
                selectize = FALSE,
                size      = min(10L, length(choices)))
  })

  sel_date    <- reactive({ req(input$sel_date); as.Date(input$sel_date) })
  win_start   <- reactive({ sel_date() - 13 })
  win_7_start <- reactive({ sel_date() - 6  })

  temp_win <- reactive(rm85_daily    |> filter(date >= win_start(), date <= sel_date()))
  flow_win <- reactive(flow_daily    |> filter(date >= win_start(), date <= sel_date()))
  air_win  <- reactive(air_temp_daily |> filter(date >= win_start(), date <= sel_date()))

  window_shade <- reactive({
    annotate("rect",
             xmin = win_7_start() - 0.5, xmax = sel_date() + 0.5,
             ymin = -Inf, ymax = Inf,
             fill = clr_exceed, alpha = 0.07)
  })

  # ── Condition stats ──────────────────────────────────────────────────────────
  output$stats_ui <- renderUI({
    d  <- sel_date()
    w7 <- win_7_start()
    dr <- sprintf("%s–%s", fmt_date(w7), fmt_date(d))

    row_d <- rm85_daily    |> filter(date == d)
    f7    <- flow_daily    |> filter(date >= w7, date <= d)
    a7    <- air_temp_daily |> filter(date >= w7, date <= d)

    dadm_val <- if (nrow(row_d) > 0 && !is.na(row_d$dadm_7))
                  sprintf("%.1f°C", row_d$dadm_7) else "—"
    tmax_val <- if (nrow(row_d) > 0 && !is.na(row_d$tmax))
                  sprintf("%.1f°C", row_d$tmax)   else "—"
    flow_val <- if (nrow(f7) > 0)
                  sprintf("%d cfs", round(mean(f7$flow_cfs, na.rm = TRUE))) else "—"
    air_val  <- if (nrow(a7) > 0 && "temperature_2m_max" %in% names(a7))
                  sprintf("%.1f°C", mean(a7$temperature_2m_max, na.rm = TRUE)) else "—"

    tagList(
      stat_box(dadm_val, "7DADM at RM 8.5",                              clr_exceed),
      stat_box(tmax_val, paste0("RM 8.5 water temp max, ", fmt_date(d)), clr_exceed),
      stat_box(flow_val, paste0("Mean Camp Polk flow, ", dr),            clr_flow),
      stat_box(air_val,  paste0("Mean air max (2 m), ", dr),             clr_air)
    )
  })

  # ── Flow sweep (RF) ──────────────────────────────────────────────────────────
  flow_sweep <- reactive({
    d <- sel_date()

    feats_per_lead <- lapply(lead_days_vec, function(k) {
      rd <- d - k
      list(
        k           = k,
        run_date    = rd,
        obs_flow    = safe1(flow_daily    |> filter(date == rd)     |> pull(flow_cfs)),
        cp_7dadm    = safe1(cp_temp_daily |> filter(date == rd)     |> pull(cp_7dadm)),
        cp_7dadm_m1 = safe1(cp_temp_daily |> filter(date == rd - 1) |> pull(cp_7dadm)),
        Julian      = yday(rd),
        air_max     = get_wx(rd,     "temperature_2m_max", k),
        air_min     = get_wx(rd,     "temperature_2m_min", k),
        cloud_pct   = get_wx(rd,     "cloud_cover_mean",   k),
        air_max_m1  = get_wx(rd - 1, "temperature_2m_max", k),
        air_min_m1  = get_wx(rd - 1, "temperature_2m_min", k),
        dadm_m1     = safe1(rm85_daily    |> filter(date == rd - 1) |> pull(dadm_7))
      )
    })

    sweep_rows <- lapply(feats_per_lead, function(bf) {
      if (is.na(bf$obs_flow) || is.na(bf$cp_7dadm) || is.na(bf$dadm_m1)) return(NULL)

      t_m1 <- if (!is.na(bf$cp_7dadm_m1)) bf$cp_7dadm_m1 else bf$cp_7dadm

      feat_mat <- data.frame(
        cp_flow_mean = flow_grid,
        cp_7dadm     = cp_temp_delta(bf$cp_7dadm, flow_grid, bf$obs_flow),
        Julian       = bf$Julian,
        air_max      = bf$air_max,
        air_min      = bf$air_min,
        cloud_pct    = bf$cloud_pct,
        cp_flow_m1   = flow_grid,
        cp_7dadm_m1  = cp_temp_delta(t_m1, flow_grid, bf$obs_flow),
        air_max_m1   = bf$air_max_m1,
        air_min_m1   = bf$air_min_m1,
        dadm_m1      = bf$dadm_m1
      )

      tibble(
        lead_days  = bf$k,
        run_date   = bf$run_date,
        obs_flow   = bf$obs_flow,
        flow_cfs   = flow_grid,
        pred_7dadm = as.numeric(predict(rf_models[[as.character(bf$k)]], newdata = feat_mat))
      )
    })

    sweep_df <- bind_rows(Filter(Negate(is.null), sweep_rows))
    if (nrow(sweep_df) == 0) return(NULL)

    threshold_df <- sweep_df |>
      group_by(lead_days) |>
      mutate(crosses = any(pred_7dadm <= target_C, na.rm = TRUE)) |>
      filter(if_else(crosses, pred_7dadm <= target_C, pred_7dadm == min(pred_7dadm, na.rm = TRUE))) |>
      slice_min(flow_cfs, n = 1) |>
      ungroup() |>
      mutate(flow_gap = round(flow_cfs - obs_flow))

    obs_pred_df <- sweep_df |>
      group_by(lead_days) |>
      slice_min(abs(flow_cfs - obs_flow), n = 1) |>
      ungroup()

    list(sweep = sweep_df, threshold = threshold_df, obs_pred = obs_pred_df)
  })

  # ── Flow offset sidebar section ──────────────────────────────────────────────
  output$offset_ui <- renderUI({
    sw <- flow_sweep()
    if (is.null(sw)) {
      return(p("Model features unavailable for this date.",
               style = "font-size:12px; color:#888;"))
    }

    d <- sel_date()
    rows <- lapply(lead_days_vec, function(k) {
      row <- sw$threshold |> filter(lead_days == k)
      if (nrow(row) == 0) return(NULL)

      run_date_lbl <- format(d - k, "%b %d")

      val_txt <- if (row$crosses) {
        sprintf("%d cfs", round(row$flow_cfs))
      } else {
        NULL
      }
      gap_txt <- if (row$crosses) {
        sprintf("+%d cfs from observed", round(row$flow_gap))
      } else {
        "Atmosphere-dominated — no flow achieves compliance"
      }

      div(class = "offset-row",
        div(
          span(class = "offset-lead", sprintf("%d-day lead:", k)),
          span(style = "font-size:11px; color:#999; margin-left:4px;",
               sprintf("(%s)", run_date_lbl))
        ),
        div(
          if (!is.null(val_txt)) span(class = "offset-val",  val_txt),
          br(),
          if (row$crosses) span(class = "offset-gap", gap_txt)
          else             span(class = "not-achievable", gap_txt)
        )
      )
    })

    div(Filter(Negate(is.null), rows))
  })

  # ── Plots ────────────────────────────────────────────────────────────────────
  output$temp_plot <- renderPlotly({
    req(nrow(temp_win()) > 0)
    d    <- sel_date()
    peak <- filter(temp_win(), date == d)

    tw <- temp_win() |>
      mutate(
        tmax_lbl   = sprintf("%.1f°C", tmax),
        dadm_lbl   = sprintf("%.1f°C", dadm_7),
        date_lbl   = format(date, "%b %d")
      )

    p <- ggplot(tw, aes(x = date)) +
      window_shade() +
      geom_line(aes(y = tmax), color = clr_grey, linewidth = 0.6, alpha = 0.7) +
      geom_point(aes(y = tmax,
                     text = paste0("Date: ", date_lbl, "<br>Daily Max: ", tmax_lbl)),
                 color = clr_grey, size = 1, alpha = 0) +
      geom_line(aes(y = dadm_7), color = clr_rm85, linewidth = 1.2) +
      geom_point(aes(y = dadm_7,
                     text = paste0("Date: ", date_lbl, "<br>7DADM: ", dadm_lbl)),
                 color = clr_rm85, size = 1, alpha = 0) +
      geom_hline(yintercept = target_C, linetype = "dashed",
                 color = clr_exceed, linewidth = 0.7) +
      scale_x_date(date_labels = "%b %d", date_breaks = "2 days") +
      labs(title    = "RM 8.5 Water Temperature",
           subtitle = "Grey = daily max  |  Orange = 7DADM  |  Shading = 7-day averaging window",
           x = NULL, y = "°C") +
      base_theme()

    if (nrow(peak) > 0 && !is.na(peak$dadm_7)) {
      p <- p +
        geom_point(data = peak, aes(y = dadm_7),
                   shape = 21, size = 4, fill = clr_exceed,
                   color = "white", stroke = 1.5)
    }
    ggplotly(p, tooltip = "text") |> layout(showlegend = FALSE)
  })

  output$flow_plot <- renderPlotly({
    req(nrow(flow_win()) > 0)
    fw <- flow_win() |>
      mutate(
        date_lbl = format(date, "%b %d"),
        flow_lbl = scales::comma(round(flow_cfs))
      )
    p <- ggplot(fw, aes(x = date, y = flow_cfs,
                        text = paste0("Date: ", date_lbl, "<br>Flow: ", flow_lbl, " cfs"))) +
      geom_col(fill = clr_flow, alpha = 0.65, width = 0.8) +
      scale_x_date(date_labels = "%b %d", date_breaks = "2 days") +
      scale_y_continuous(labels = scales::comma,
                         expand = expansion(mult = c(0, 0.08))) +
      labs(title    = "Camp Polk Mean Daily Flow",
           x = NULL, y = "Flow (cfs)") +
      base_theme()
    ggplotly(p, tooltip = "text") |> layout(showlegend = FALSE)
  })

  output$airtemp_plot <- renderPlotly({
    req(nrow(air_win()) > 0)
    aw <- air_win()
    req("temperature_2m_max" %in% names(aw), "temperature_2m_min" %in% names(aw))

    aw <- aw |>
      mutate(
        date_lbl    = format(date, "%b %d"),
        tmax_lbl    = sprintf("%.1f°C", temperature_2m_max),
        tmin_lbl    = sprintf("%.1f°C", temperature_2m_min)
      )

    p <- ggplot(aw, aes(x = date)) +
      geom_ribbon(aes(ymin = temperature_2m_min, ymax = temperature_2m_max),
                  fill = clr_air, alpha = 0.2) +
      geom_line(aes(y = temperature_2m_max), color = clr_air, linewidth = 0.9) +
      geom_point(aes(y = temperature_2m_max,
                     text = paste0("Date: ", date_lbl, "<br>Air Max: ", tmax_lbl)),
                 color = clr_air, size = 1, alpha = 0) +
      geom_line(aes(y = temperature_2m_min), color = clr_air, linewidth = 0.5,
                linetype = "dashed") +
      geom_point(aes(y = temperature_2m_min,
                     text = paste0("Date: ", date_lbl, "<br>Air Min: ", tmin_lbl)),
                 color = clr_air, size = 1, alpha = 0) +
      scale_x_date(date_labels = "%b %d", date_breaks = "2 days") +
      labs(title    = "Air Temperature near Camp Polk (2 m)",
           subtitle = "Solid = daily max  |  Dashed = daily min  |  Ribbon = range",
           x = NULL, y = "°C") +
      base_theme()
    ggplotly(p, tooltip = "text") |> layout(showlegend = FALSE)
  })

  output$sweep_plot <- renderPlotly({
    sw <- flow_sweep()
    if (is.null(sw)) {
      p <- ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "Model features unavailable for this date",
                 hjust = 0.5, color = "grey50", size = 4) +
        theme_void()
      return(ggplotly(p))
    }

    threshold_crossings <- filter(sw$threshold, crosses)
    d <- sel_date()

    sweep_labeled <- sw$sweep |>
      mutate(
        lead_lbl = lead_labels[as.character(lead_days)],
        run_date_lbl = format(d - lead_days, "%b %d"),
        tip = paste0(lead_lbl, " (run ", run_date_lbl, ")",
                     "<br>Flow: ", scales::comma(round(flow_cfs)), " cfs",
                     "<br>Pred 7DADM: ", sprintf("%.2f°C", pred_7dadm))
      )

    obs_labeled <- sw$obs_pred |>
      mutate(
        lead_lbl = lead_labels[as.character(lead_days)],
        run_date_lbl = format(d - lead_days, "%b %d"),
        tip = paste0(lead_lbl, " (run ", run_date_lbl, ") — observed flow",
                     "<br>Flow: ", scales::comma(round(flow_cfs)), " cfs",
                     "<br>Pred 7DADM: ", sprintf("%.2f°C", pred_7dadm))
      )

    p <- ggplot(sweep_labeled,
                aes(x = flow_cfs, y = pred_7dadm,
                    color = factor(lead_days), group = factor(lead_days),
                    text = tip)) +
      geom_line(linewidth = 1.1) +
      geom_hline(yintercept = target_C, linetype = "dashed",
                 color = clr_exceed, linewidth = 0.8) +
      geom_point(data = obs_labeled,
                 aes(x = flow_cfs, y = pred_7dadm, color = factor(lead_days),
                     text = tip),
                 size = 3.5, shape = 16) +
      scale_color_manual(values = lead_colors, labels = lead_labels, name = NULL) +
      scale_x_continuous(labels = scales::comma) +
      labs(title    = sprintf("RF flow sweep — %s", format(d, "%b %d, %Y")),
           subtitle = "Filled circles = prediction at observed flow  |  Air temp & cloud fixed at observed values",
           x = "Camp Polk sustained flow (cfs)", y = "Predicted 7DADM at RM 8.5 (°C)") +
      base_theme() +
      theme(legend.position = "bottom")

    if (nrow(threshold_crossings) > 0) {
      tc_labeled <- threshold_crossings |>
        mutate(
          lead_lbl = lead_labels[as.character(lead_days)],
          run_date_lbl = format(d - lead_days, "%b %d"),
          tip = paste0(lead_lbl, " (run ", run_date_lbl, ") — threshold flow",
                       "<br>Flow: ", scales::comma(round(flow_cfs)), " cfs")
        )
      p <- p +
        geom_vline(data = tc_labeled,
                   aes(xintercept = flow_cfs, color = factor(lead_days)),
                   linetype = "dotted", linewidth = 0.8, show.legend = FALSE) +
        geom_text(data = tc_labeled,
                  aes(x = flow_cfs, y = target_C - 0.5,
                      label = sprintf("%.0f cfs", flow_cfs),
                      color = factor(lead_days)),
                  size = 3, show.legend = FALSE, vjust = 1.5, fontface = "bold")
    } else {
      p <- p +
        annotate("text",
                 x = mean(flow_range), y = target_C - 0.6,
                 label = "Threshold not achievable — atmospheric driver dominates",
                 hjust = 0.5, color = "grey40", size = 3.2, fontface = "italic")
    }
    ggplotly(p, tooltip = "text") |>
      layout(legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.15))
  })
}

shinyApp(ui, server)
