FROM rocker/tidyverse:latest

# Install plumber and other packages
RUN install2.r --error --deps TRUE \
    plumber \
    tidymodels \
    ranger

# Copy files
COPY API.R /API.R
COPY diabetes_binary_health_indicators_BRFSS2015.csv /diabetes_binary_health_indicators_BRFSS2015.csv

# Expose port
EXPOSE 8000

# Run API
CMD ["Rscript", "-e", "library(plumber); pr <- plumb('/API.R'); pr$run(host='0.0.0.0', port=8000)"]