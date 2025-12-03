FROM rocker/tidyverse:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# Install plumber first (it's simpler and helps diagnose issues)
RUN R -e "options(repos = c(CRAN = 'https://cloud.r-project.org/')); \
    install.packages('plumber', dependencies = TRUE); \
    if (!require('plumber')) stop('plumber failed to install')"

# Install tidymodels
RUN R -e "options(repos = c(CRAN = 'https://cloud.r-project.org/')); \
    install.packages('tidymodels', dependencies = TRUE); \
    if (!require('tidymodels')) stop('tidymodels failed to install')"

# Install ranger
RUN R -e "options(repos = c(CRAN = 'https://cloud.r-project.org/')); \
    install.packages('ranger', dependencies = TRUE); \
    if (!require('ranger')) stop('ranger failed to install')"

# Copy necessary files into the container
COPY API.R /API.R
COPY diabetes_binary_health_indicators_BRFSS2015.csv /diabetes_binary_health_indicators_BRFSS2015.csv

# Expose port 8000 for the API
EXPOSE 8000

# Run the API when container starts
ENTRYPOINT ["R", "-e", "pr <- plumber::plumb('/API.R'); pr$run(host='0.0.0.0', port=8000)"]