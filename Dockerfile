FROM rocker/tidyverse:latest

# Install system dependencies that might be needed
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev

# Install R packages with error checking
RUN R -e "install.packages('plumber', repos='https://cloud.r-project.org/', dependencies=TRUE)"
RUN R -e "install.packages('tidymodels', repos='https://cloud.r-project.org/', dependencies=TRUE)"
RUN R -e "install.packages('ranger', repos='https://cloud.r-project.org/', dependencies=TRUE)"

# Verify packages installed correctly
RUN R -e "library(plumber); library(tidymodels); library(ranger)"

# Copy necessary files into the container
COPY API.R /API.R
COPY diabetes_binary_health_indicators_BRFSS2015.csv /diabetes_binary_health_indicators_BRFSS2015.csv

# Expose port 8000 for the API
EXPOSE 8000

# Run the API when container starts
ENTRYPOINT ["R", "-e", "pr <- plumber::plumb('/API.R'); pr$run(host='0.0.0.0', port=8000)"]
