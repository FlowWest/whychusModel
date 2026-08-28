library(tidyverse)
library(lubridate)
library(neuralnet)
library(caret)

# =============================================================
# INPUTS — edit these
# =============================================================

file_data <- "scripts_from_spencer/2022_Data/FlowandTemp.csv"
met_data  <- "scripts_from_spencer/2022_Data/Met.csv"

output_dir  <- "output"
output_name <- "ANN_selected.csv"

plot_results <- TRUE

m_start <- 6   # June
m_stop  <- 9   # September

h          <- 5     # number of hidden layers
p          <- 0.2   # test proportion
iterations <- 1000  # max iterations
lag        <- "yes" # "no", "yes", or "yes_tar"
solv       <- "lbfgs"  # for reference — caret uses its own methods

# =============================================================
# DATA PREP
# =============================================================

df     <- read_csv(file_data)
df_met <- read_csv(met_data)

# Rename columns to match Python logic — adjust if column names differ
df_red <- df |>
  transmute(
    date  = as.Date(`20d`, format = "%m/%d/%Y"),
    Q     = as.numeric(`14n...4`),
    Tmax  = as.numeric(`14n...6`),
    Tmean = as.numeric(`14n...8`),
    Tmin  = as.numeric(`14n...10`)
  ) |>
  mutate(Date2 = format(date, "%Y-%m-%d"))

# Join met data by date
df_met_clean <- df_met |>
  mutate(date = as.Date(Date, format = "%m/%d/%Y")) |>
  select(date, Air_Max = Tmax, Air_Min = Tmin, Air_Mean = Tmean)

df_red <- df_red |>
  left_join(df_met_clean |> 
              mutate(date = ymd(date)), by = "date")

# Remove NAs
df_filt <- df_red |>
  filter(!is.na(Tmax), !is.na(Q), !is.na(Air_Max), !is.na(Air_Min)) |>
  mutate(
    month  = month(date),
    day    = day(date),
    year   = year(date),
    Julian = yday(date)
  )

# Filter to season
df_final <- df_filt |>
  filter(month >= m_start, month <= m_stop) |>
  arrange(date)

# =============================================================
# BUILD FEATURE MATRICES
# =============================================================

n <- nrow(df_final)

# No lag version
X_0  <- df_final |> select(Q, Julian, Air_Max, Air_Min)
tar_0 <- df_final$Tmax

# Lag version — drop first row of current, last row of lagged
current <- df_final |> slice(2:n)
lagged  <- df_final |> slice(1:(n - 1))

X_M1 <- tibble(
  Q         = as.numeric(current$Q),
  Julian    = current$Julian,
  Air_Max   = as.numeric(current$Air_Max),
  Air_Min   = as.numeric(current$Air_Min),
  Q_m1      = as.numeric(lagged$Q),
  Air_Max_m1 = as.numeric(lagged$Air_Max),
  Air_Min_m1 = as.numeric(lagged$Air_Min)
)
tar_M1 <- as.numeric(current$Tmax)

# Lag + previous water temp version
X_M1_tar <- X_M1 |>
  mutate(tar_m1 = as.numeric(lagged$Tmax))
tar_M1_tar <- tar_M1

# Select X and tar based on lag setting
if (lag == "no") {
  X   <- X_0
  tar <- tar_0
} else if (lag == "yes") {
  X   <- X_M1
  tar <- tar_M1
} else if (lag == "yes_tar") {
  X   <- X_M1_tar
  tar <- tar_M1_tar
}

# =============================================================
# SCALE (Standard scaler — mean 0, sd 1)
# =============================================================

set.seed(42)
train_idx <- caret::createDataPartition(tar, p = 1 - p, list = FALSE)

X_train <- X[train_idx, ]
X_test  <- X[-train_idx, ]
y_train <- tar[train_idx]
y_test  <- tar[-train_idx]

# Fit scaler on training data only
preproc <- preProcess(X_train, method = c("center", "scale"))
X_train_scaled <- predict(preproc, X_train)
X_test_scaled  <- predict(preproc, X_test)

# =============================================================
# ANN MODEL
# =============================================================

# Hidden layer size mirrors Python: (ncol(X) + 1) repeated h times
hidden_size   <- ncol(X) + 1
hidden_layers <- rep(hidden_size, h)

train_df <- X_train_scaled |>
  mutate(target = y_train)

# caret mlp with nnet (single hidden layer) or neuralnet (multi-layer)
# For multi-layer matching Python's MLPRegressor, use neuralnet directly
formula_str <- paste("target ~", paste(names(X), collapse = " + "))
ann_formula <- as.formula(formula_str)

model <- neuralnet(
  formula    = ann_formula,
  data       = train_df,
  hidden     = c(5),  # hidden_layers,
  linear.output = TRUE,        # regression, not classification
  stepmax    = 1e5,  #iterations * 1000,
  threshold  = 0.1 #  0.01
)

# =============================================================
# PREDICT + EVALUATE
# =============================================================

test_df  <- X_test_scaled
y_pred   <- predict(model, test_df)[, 1]

SSres <- sum((y_pred - y_test)^2)
SStot <- sum((y_test - mean(y_test))^2)
R2    <- 1 - (SSres / SStot)
RMSE  <- sqrt(SSres / length(y_pred))

cat("R2:  ", round(R2,   4), "\n")
cat("RMSE:", round(RMSE, 4), "\n")

# =============================================================
# OUTPUT TABLE
# =============================================================

results <- tibble(
  hidden_layers = h,
  solver        = solv,
  lag           = lag,
  R2            = round(R2,   4),
  RMSE          = round(RMSE, 4)
)

dir.create(output_dir, showWarnings = FALSE)
write_csv(results, file.path(output_dir, output_name))

# =============================================================
# PLOT
# =============================================================

if (plot_results) {
  plot_df <- tibble(predicted = y_pred, observed = y_test)
  
  p_max <- 1.25 * max(y_pred)
  
  print(
    ggplot(plot_df, aes(x = predicted, y = observed)) +
      geom_point(alpha = 0.6, color = "#185FA5") +
      geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
      xlim(0, p_max) + ylim(0, p_max) +
      labs(
        title    = paste("ANN —", h, "hidden layers"),
        subtitle = paste("R² =", round(R2, 2)),
        x        = "Model — Max Daily T (°C)",
        y        = "Observed — Max Daily T (°C)"
      ) +
      theme_minimal()
  )
}

# =============================================================
# SAVE MODEL AND SCALER
# =============================================================

saveRDS(model,   file.path(output_dir, "MFJD_ann_model.rds"))
saveRDS(preproc, file.path(output_dir, "MFJD_scaler.rds"))

# Reload example
# model2   <- readRDS(file.path(output_dir, "MFJD_ann_model.rds"))
# preproc2 <- readRDS(file.path(output_dir, "MFJD_scaler.rds"))
# new_data_scaled <- predict(preproc2, new_data)
# predictions     <- predict(model2, new_data_scaled)[, 1]