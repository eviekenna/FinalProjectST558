# Dockerfile
# Start with rocker/tidyverse image which has R and tidyverse pre-installed
FROM rocker/tidyverse:latest

# Install additional R packages needed for the API
RUN R -e "install.packages('plumber', repos='https://cloud.r-project.org/')"
RUN R -e "install.packages('tidymodels', repos='https://cloud.r-project.org/')"
RUN R -e "install.packages('ranger', repos='https://cloud.r-project.org/')"

# Copy necessary files into the container
COPY API.R /API.R
COPY diabetes_binary_health_indicators_BRFSS2015.csv /diabetes_binary_health_indicators_BRFSS2015.csv

# Expose port 8000 for the API
EXPOSE 8000

# Run the API when container starts
ENTRYPOINT ["R", "-e", "pr <- plumber::plumb('/API.R'); pr$run(host='0.0.0.0', port=8000)"]

