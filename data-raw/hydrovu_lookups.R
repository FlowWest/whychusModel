# data-raw/hydrovu_lookups.R
# Build lookup tables for resolving the IDs stored in data-live/hv_data.Rds
# (on the `data` branch). Rerun when locations are added to the HydroVu
# account. Requires rhydrovu with hv_units().

library(rhydrovu)
library(dplyr)

con <- hv_connect()

hydrovu_locations <- hv_locations(con) |>
  arrange(name)

hydrovu_parameters <- hv_parameters(con) |>
  arrange(suppressWarnings(as.numeric(parameter_id)), parameter_id)

hydrovu_units <- hv_units(con) |>
  arrange(suppressWarnings(as.numeric(unit_id)), unit_id)

usethis::use_data(hydrovu_locations, hydrovu_parameters, hydrovu_units,
                  overwrite = TRUE)
