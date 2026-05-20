library(shiny)
library(tidyverse)
library(lubridate)
library(randomForest)
library(zoo)
library(here)
library(whychusModel)

# ── Thresholds ────────────────────────────────────────────────────────────────
threshold_tmax  <- 20.0
threshold_7dadm <- 20
owrd_station    <- "14076100"
nws_gridpoint   <- "PDT/35,57"
lead_days_vec   <- c(1, 3, 7)

# ── UI ────────────────────────────────────────────────────────────────────────
ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { font-family: 'Segoe UI', sans-serif; background: #f4f6f9; }
    .well { background: white; border: 1px solid #dde3ec; box-shadow: none; }
    h2 { color: #1a3a5c; font-weight: 700; margin-bottom: 4px; }
    h4 { color: #2c5f8a; font-weight: 600; }
    .section-card {
      background: white; border-radius: 8px;
      border: 1px solid #dde3ec; padding: 16px 20px;
      margin-bottom: 16px;
    }
    .exceed-warn { color: #c0392b; font-weight: bold; }
    .exceed-ok   { color: #27ae60; font-weight: bold; }
    .subtitle { color: #666; font-size: 14px; margin-bottom: 20px; }
    .run-btn { background: #1a3a5c; color: white; border: none;
               font-size: 15px; padding: 10px 28px; border-radius: 6px;
               width: 100%; margin-top: 8px; }
    .run-btn:hover { background: #2c5f8a; }
    label { font-weight: 600; font-size: 13px; color: #444; }
  "))),
  
  fluidRow(
    column(12,
           div(style = "padding: 20px 10px 0;",
               h2("RM 8.5 Water Temperature Forecast"),
               p("Camp Polk gauging station (OWRD 14076100) · Sisters, OR", class = "subtitle")
           )
    )
  ),
  
  fluidRow(
    # ── Sidebar ──────────────────────────────────────────────────────────────
    column(3,
           div(class = "section-card",
               h4("Run Settings"),
               dateInput("run_date", "Forecast Date", value = Sys.Date(),
                         min = "2024-01-01", max = Sys.Date() + 1),
               hr(style = "border-color:#eee;"),
               h4("RM 8.5 Lag Values"),
               p(style = "font-size:12px;color:#888;",
                 "Defaults to 2025 historical for the same calendar day."),
               numericInput("tmax_m1", "Yesterday Tmax (°C)", value = NA, step = 0.1),
               numericInput("dadm_m1", "Yesterday 7DADM (°C)", value = NA, step = 0.1),
               checkboxInput("use_2025_lag", "Auto-fill from 2025 data", value = TRUE),
               hr(style = "border-color:#eee;"),
               actionButton("run_btn", "Run Forecast", class = "run-btn")
           )
    ),
    
    # ── Main panels ──────────────────────────────────────────────────────────
    column(9,
           # Status
           div(class = "section-card",
               uiOutput("status_ui")
           ),
           
           # OWRD data
           div(class = "section-card",
               h4("📊 OWRD Hydrology — Camp Polk (last 10 days)"),
               fluidRow(
                 column(6, plotOutput("plot_flow",  height = "220px")),
                 column(6, plotOutput("plot_wtemp", height = "220px"))
               )
           ),
           
           # NWS forecast — air temp and cloud cover as separate plots
           div(class = "section-card",
               h4("🌤 NWS Air Temperature & Cloud Cover Forecast"),
               fluidRow(
                 column(8, plotOutput("plot_nws_temp",  height = "220px")),
                 column(4, plotOutput("plot_nws_cloud", height = "220px"))
               )
           ),
           
           # Model results
           div(class = "section-card",
               h4("🌡 Temperature Forecast Results"),
               uiOutput("results_ui")
           )
    )
  )
)

# ── Server ────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {
  
  # ── Reactive: run everything on button press ──────────────────────────────
  forecast_data <- eventReactive(input$run_btn, {
    today <- input$run_date
    withProgress(message = "Fetching data & running models…", value = 0, {
      
      # 1. OWRD ---------------------------------------------------------------
      incProgress(0.1, detail = "Pulling OWRD flow…")
      pull_start <- today - 10
      
      cp_flow_raw <- tryCatch(
        get_owrd_hydro(owrd_station, pull_start, today, "Instantaneous_Flow"),
        error = function(e) { message("OWRD flow: ", e$message); NULL }
      )
      cp_tmax_raw <- tryCatch(
        get_owrd_hydro(owrd_station, pull_start, today, "WTEMP15"),
        error = function(e) { message("OWRD temp: ", e$message); NULL }
      )
      
      if (is.null(cp_flow_raw) || is.null(cp_tmax_raw))
        return(list(error = "OWRD data unavailable. Check connection."))
      
      cp_flow <- cp_flow_raw |>
        mutate(date = as.Date(parse_date_time(record_date,
                                              orders = c("mdy", "mdy HM")))) |>
        group_by(date) |>
        summarise(cp_flow_mean = mean(instananteous_flow_cfs, na.rm = TRUE)) |>
        arrange(date)
      
      cp_tmax <- cp_tmax_raw |>
        mutate(date = as.Date(parse_date_time(record_date,
                                              orders = c("mdy", "mdy HM")))) |>
        group_by(date) |>
        summarise(cp_tmax = max(instantaneous_water_temp_c, na.rm = TRUE)) |>
        arrange(date)
      
      cp_7dadm <- cp_tmax |>
        mutate(cp_7dadm = rollmean(cp_tmax, k = 7, fill = NA, align = "right"))
      
      cp_today <- cp_flow |>
        filter(date == today) |>
        left_join(cp_tmax,  by = "date") |>
        left_join(select(cp_7dadm, date, cp_7dadm), by = "date")
      
      cp_yest <- cp_flow |>
        filter(date == today - 1) |>
        left_join(cp_tmax,  by = "date") |>
        left_join(select(cp_7dadm, date, cp_7dadm), by = "date")
      
      # 2. NWS ----------------------------------------------------------------
      incProgress(0.2, detail = "Pulling NWS forecast…")
      nws_tmax  <- tryCatch(get_nws_forecast(nws_gridpoint, "maxTemperature"), error = function(e) NULL)
      nws_tmin  <- tryCatch(get_nws_forecast(nws_gridpoint, "minTemperature"), error = function(e) NULL)
      nws_cloud <- tryCatch(get_nws_forecast(nws_gridpoint, "skyCover"),       error = function(e) NULL)
      
      nws_source <- "live"
      if (is.null(nws_tmax) || is.null(nws_tmin) || is.null(nws_cloud)) {
        nws_source <- "fallback"
        log_file <- here("output", "nws-forecasts-log.csv")
        if (!file.exists(log_file))
          return(list(error = "NWS unavailable and no forecast log found."))
        
        nws_log <- read_csv(log_file, show_col_types = FALSE) |>
          mutate(forecast_date = as.Date(forecast_date),
                 datetime = as.POSIXct(forecast_date, tz = "America/Los_Angeles"))
        
        latest <- nws_log |>
          filter(forecast_date >= today) |>
          group_by(variable, forecast_date) |>
          slice_max(run_date, n = 1) |>
          ungroup()
        
        if (is.null(nws_tmax))  nws_tmax  <- latest |> filter(variable == "maxTemperature") |> select(datetime, value)
        if (is.null(nws_tmin))  nws_tmin  <- latest |> filter(variable == "minTemperature") |> select(datetime, value)
        if (is.null(nws_cloud)) nws_cloud <- latest |> filter(variable == "skyCover")       |> select(datetime, value)
        
        if (nrow(nws_tmax) == 0 || nrow(nws_tmin) == 0 || nrow(nws_cloud) == 0)
          return(list(error = "Fallback NWS log missing required variables."))
      }
      
      daily_nws <- function(df, target_date, agg_fn = mean) {
        res <- df |> mutate(date = as.Date(datetime)) |>
          filter(date == target_date) |>
          summarise(value = agg_fn(value, na.rm = TRUE)) |>
          pull(value)
        if (length(res) == 0 || is.nan(res)) NA_real_ else res
      }
      
      # 3. RM 8.5 lag ---------------------------------------------------------
      incProgress(0.3, detail = "Setting RM 8.5 lag values…")
      
      if (input$use_2025_lag) {
        lag_tmax_row <- rm_8_5_historical |>
          filter(statistic == "max",
                 year(date) == 2025,
                 month(date) == month(today),
                 day(date)   == day(today)) |>
          slice(1)
        lag_dadm_row <- rm_8_5_historical |>
          filter(statistic == "7DADM",
                 year(date) == 2025,
                 month(date) == month(today),
                 day(date)   == day(today)) |>
          slice(1)
        
        Tmax_m1 <- if (nrow(lag_tmax_row) > 0) lag_tmax_row$temperature else NA_real_
        dadm_m1  <- if (nrow(lag_dadm_row) > 0) lag_dadm_row$temperature else NA_real_
        
        updateNumericInput(session, "tmax_m1", value = Tmax_m1)
        updateNumericInput(session, "dadm_m1", value = dadm_m1)
      } else {
        Tmax_m1 <- if (!is.na(input$tmax_m1)) input$tmax_m1 else NA_real_
        dadm_m1  <- if (!is.na(input$dadm_m1)) input$dadm_m1 else NA_real_
      }
      
      # 4. Predict ------------------------------------------------------------
      incProgress(0.5, detail = "Running random forest models…")
      
      results_list <- map(lead_days_vec, function(k) {
        fdate <- today + k
        
        air_max_k    <- daily_nws(nws_tmax,  fdate,     max)
        air_min_k    <- daily_nws(nws_tmin,  fdate,     min)
        cloud_k      <- daily_nws(nws_cloud, fdate,     mean)
        air_max_m1_k <- daily_nws(nws_tmax,  fdate - 1, max)
        air_min_m1_k <- daily_nws(nws_tmin,  fdate - 1, min)
        
        feat_tmax <- data.frame(
          cp_flow_mean = cp_today$cp_flow_mean,
          cp_tmax      = cp_today$cp_tmax,
          Julian       = yday(fdate),
          air_max      = air_max_k,
          air_min      = air_min_k,
          cloud_pct    = cloud_k,
          cp_flow_m1   = cp_yest$cp_flow_mean,
          cp_tmax_m1   = cp_yest$cp_tmax,
          air_max_m1   = air_max_m1_k,
          air_min_m1   = air_min_m1_k,
          Tmax_m1      = Tmax_m1
        )
        
        feat_7dadm <- data.frame(
          cp_flow_mean = cp_today$cp_flow_mean,
          cp_7dadm     = cp_today$cp_7dadm,
          Julian       = yday(fdate),
          air_max      = air_max_k,
          air_min      = air_min_k,
          cloud_pct    = cloud_k,
          cp_flow_m1   = cp_yest$cp_flow_mean,
          cp_7dadm_m1  = cp_yest$cp_7dadm,
          air_max_m1   = air_max_m1_k,
          air_min_m1   = air_min_m1_k,
          dadm_m1      = dadm_m1
        )
        
        rf_tmax  <- readRDS(here("output", paste0("rm85_rf_tmax_lead",  k, ".rds")))
        rf_7dadm <- readRDS(here("output", paste0("rm85_rf_7dadm_lead", k, ".rds")))
        
        actual_tmax <- rm_8_5_historical |>
          filter(statistic == "max",
                 year(date) == 2025,
                 month(date) == month(fdate),
                 day(date)   == day(fdate)) |>
          pull(temperature)
        
        actual_dadm <- rm_8_5_historical |>
          filter(statistic == "7DADM",
                 year(date) == 2025,
                 month(date) == month(fdate),
                 day(date)   == day(fdate)) |>
          pull(temperature)
        
        tibble(
          run_date       = today,
          forecast_date  = fdate,
          lead_days      = k,
          pred_tmax_C    = round(predict(rf_tmax,  feat_tmax),  2),
          pred_7dadm_C   = round(predict(rf_7dadm, feat_7dadm), 2),
          actual_tmax_C  = if (length(actual_tmax) > 0) actual_tmax[[1]] else NA_real_,
          actual_7dadm_C = if (length(actual_dadm) > 0) actual_dadm[[1]] else NA_real_
        )
      })
      
      results <- bind_rows(results_list) |>
        mutate(
          tmax_error   = round(pred_tmax_C  - actual_tmax_C,  2),
          dadm_error   = round(pred_7dadm_C - actual_7dadm_C, 2),
          exceed_tmax  = pred_tmax_C  > threshold_tmax,
          exceed_7dadm = pred_7dadm_C > threshold_7dadm
        )
      
      incProgress(1, detail = "Done.")
      
      list(
        today      = today,
        cp_flow    = cp_flow,
        cp_tmax    = cp_tmax,
        cp_7dadm   = cp_7dadm,
        nws_tmax   = nws_tmax,
        nws_tmin   = nws_tmin,
        nws_cloud  = nws_cloud,
        nws_source = nws_source,
        Tmax_m1    = Tmax_m1,
        dadm_m1    = dadm_m1,
        results    = results,
        error      = NULL
      )
    })
  }, ignoreNULL = FALSE)
  
  # ── Status banner ─────────────────────────────────────────────────────────
  output$status_ui <- renderUI({
    d <- forecast_data()
    if (is.null(d)) {
      return(p(style = "color:#888;", "Press Run Forecast to load data and generate predictions."))
    }
    if (!is.null(d$error)) {
      return(div(style = "color:#c0392b; font-weight:bold;", "⚠ ", d$error))
    }
    src_badge <- if (d$nws_source == "live")
      span(style = "background:#27ae60;color:white;padding:2px 8px;border-radius:4px;font-size:12px;", "NWS Live")
    else
      span(style = "background:#e67e22;color:white;padding:2px 8px;border-radius:4px;font-size:12px;", "NWS Fallback Log")
    
    div(
      span(style = "color:#27ae60; font-weight:bold;", "✓ Forecast complete — "),
      span(format(d$today, "%B %d, %Y"), style = "font-weight:600;"),
      "  ", src_badge,
      span(style = "margin-left:16px;color:#666;font-size:13px;",
           sprintf("RM 8.5 lag: Tmax_m1 = %.1f °C | 7DADM_m1 = %.1f °C",
                   d$Tmax_m1, d$dadm_m1))
    )
  })
  
  # ── OWRD flow plot ────────────────────────────────────────────────────────
  output$plot_flow <- renderPlot({
    d <- forecast_data()
    if (is.null(d) || !is.null(d$error)) return(NULL)
    ggplot(d$cp_flow, aes(date, cp_flow_mean)) +
      geom_line(color = "#2c7bb6", linewidth = 1) +
      geom_point(color = "#2c7bb6", size = 2) +
      labs(title = "Stream Flow (cfs)", x = NULL, y = "Mean Daily Flow (cfs)") +
      theme_minimal(base_size = 12) +
      theme(plot.title = element_text(face = "bold", size = 12, color = "#1a3a5c"))
  })
  
  # ── OWRD water temp plot — HCP threshold only ─────────────────────────────
  output$plot_wtemp <- renderPlot({
    d <- forecast_data()
    if (is.null(d) || !is.null(d$error)) return(NULL)
    df <- d$cp_tmax |>
      left_join(select(d$cp_7dadm, date, cp_7dadm), by = "date")
    ggplot(df, aes(date)) +
      geom_line(aes(y = cp_tmax,  color = "Daily Max"), linewidth = 1) +
      geom_line(aes(y = cp_7dadm, color = "7DADM"),     linewidth = 1, linetype = "dashed") +
      geom_hline(yintercept = threshold_7dadm, linetype = "dotted",
                 color = "#e67e22", linewidth = 0.7) +
      annotate("text", x = min(df$date, na.rm = TRUE), y = threshold_7dadm + 0.4,
               label = "HCP 7DADM (20°C)", color = "#e67e22", size = 3.2, hjust = 0) +
      scale_color_manual(values = c("Daily Max" = "#c0392b", "7DADM" = "#e67e22")) +
      labs(title = "Water Temperature (°C)", x = NULL, y = "Temp (°C)", color = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom",
            plot.title = element_text(face = "bold", size = 12, color = "#1a3a5c"))
  })
  
  # ── NWS air temperature plot ──────────────────────────────────────────────
  output$plot_nws_temp <- renderPlot({
    d <- forecast_data()
    if (is.null(d) || !is.null(d$error)) return(NULL)
    
    tmax_df <- d$nws_tmax |> mutate(date = as.Date(datetime), var = "Air Tmax (°C)") |> select(date, value, var)
    tmin_df <- d$nws_tmin |> mutate(date = as.Date(datetime), var = "Air Tmin (°C)") |> select(date, value, var)
    
    tair <- bind_rows(tmax_df, tmin_df) |>
      group_by(date, var) |>
      summarise(value = mean(value, na.rm = TRUE), .groups = "drop")
    
    ggplot(tair, aes(date, value, color = var)) +
      geom_line(linewidth = 1.1) +
      geom_point(size = 2) +
      scale_color_manual(values = c("Air Tmax (°C)" = "#e74c3c", "Air Tmin (°C)" = "#3498db")) +
      labs(title = "Air Temperature Forecast", x = NULL, y = "Air Temp (°C)", color = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom",
            plot.title = element_text(face = "bold", size = 12, color = "#1a3a5c"))
  })
  
  # ── NWS cloud cover plot ──────────────────────────────────────────────────
  output$plot_nws_cloud <- renderPlot({
    d <- forecast_data()
    if (is.null(d) || !is.null(d$error)) return(NULL)
    
    cloud <- d$nws_cloud |>
      mutate(date = as.Date(datetime)) |>
      group_by(date) |>
      summarise(value = mean(value, na.rm = TRUE), .groups = "drop")
    
    ggplot(cloud, aes(date, value)) +
      geom_col(fill = "#7f8c8d", alpha = 0.7, width = 0.6) +
      geom_text(aes(label = paste0(round(value), "%")), vjust = -0.4,
                size = 3, color = "#444") +
      scale_y_continuous(limits = c(0, 110), labels = function(x) paste0(x, "%")) +
      labs(title = "Cloud Cover Forecast", x = NULL, y = "Cloud Cover (%)") +
      theme_minimal(base_size = 12) +
      theme(plot.title = element_text(face = "bold", size = 12, color = "#1a3a5c"))
  })
  
  # ── Forecast results table — HCP exceedance only ──────────────────────────
  output$results_ui <- renderUI({
    d <- forecast_data()
    if (is.null(d) || !is.null(d$error)) return(NULL)
    
    rows <- map(1:nrow(d$results), function(i) {
      r <- d$results[i, ]
      dadm_class <- if (isTRUE(r$exceed_7dadm)) "exceed-warn" else "exceed-ok"
      dadm_flag  <- if (isTRUE(r$exceed_7dadm)) " ⚠ EXCEEDS HCP (20°C)" else " ✓ Below HCP (20°C)"
      
      div(style = "display:flex; gap:12px; align-items:stretch; margin-bottom:10px;",
          # Lead day header
          div(style = "background:#1a3a5c;color:white;border-radius:6px;
                       padding:12px 16px;min-width:90px;text-align:center;",
              div(style = "font-size:22px;font-weight:700;", paste0("+", r$lead_days)),
              div(style = "font-size:11px;opacity:0.8;", "day lead"),
              div(style = "font-size:12px;margin-top:4px;", format(r$forecast_date, "%b %d"))
          ),
          # Tmax card — display only, no exceedance flag
          div(style = "flex:1;background:#fff8f8;border:1px solid #fadbd8;
                       border-radius:6px;padding:12px;",
              div(style = "font-size:11px;color:#666;font-weight:600;", "PREDICTED TMAX"),
              div(style = "font-size:26px;font-weight:700;color:#c0392b;",
                  sprintf("%.1f °C", r$pred_tmax_C)),
              if (!is.na(r$actual_tmax_C))
                div(style = "font-size:11px;color:#888;margin-top:4px;",
                    sprintf("2025 actual: %.1f °C  (err: %+.2f)", r$actual_tmax_C, r$tmax_error))
              else
                div(style = "font-size:11px;color:#ccc;", "No 2025 actual")
          ),
          # 7DADM card — HCP exceedance check
          div(style = "flex:1;background:#fff8f0;border:1px solid #fad7a0;
                       border-radius:6px;padding:12px;",
              div(style = "font-size:11px;color:#666;font-weight:600;", "PREDICTED 7DADM"),
              div(style = "font-size:26px;font-weight:700;color:#e67e22;",
                  sprintf("%.1f °C", r$pred_7dadm_C)),
              div(class = dadm_class, style = "font-size:12px;", dadm_flag),
              if (!is.na(r$actual_7dadm_C))
                div(style = "font-size:11px;color:#888;margin-top:4px;",
                    sprintf("2025 actual: %.1f °C  (err: %+.2f)", r$actual_7dadm_C, r$dadm_error))
              else
                div(style = "font-size:11px;color:#ccc;", "No 2025 actual")
          )
      )
    })
    
    tagList(rows)
  })
}

shinyApp(ui, server)