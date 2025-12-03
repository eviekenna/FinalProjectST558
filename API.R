# plumber_api.R
library(tidymodels)
library(plumber)
library(readr)
library(dplyr)

# Read in the data
diabetes <- read_csv("diabetes_binary_health_indicators_BRFSS2015.csv")

# Convert variables to factors (EXACT same as your modeling file)
diabetes <- diabetes |>
  mutate(
    Diabetes_binary = factor(Diabetes_binary, 
                             levels = c(0,1),
                             labels = c("NoDiabetes", "Diabetes")),
    
    # Convert numeric variables that should be factors
    Fruits = factor(Fruits, levels = c(0, 1), labels = c("NoFruits", "Fruits")),
    Veggies = factor(Veggies, levels = c(0, 1), labels = c("NoVeggies", "Veggies")),
    HvyAlcoholConsump = factor(HvyAlcoholConsump, levels = c(0, 1), 
                               labels = c("NoHeavyAlc", "HeavyAlc")),
    AnyHealthcare = factor(AnyHealthcare, levels = c(0, 1), 
                           labels = c("NoHealthcare", "Healthcare")),
    NoDocbcCost = factor(NoDocbcCost, levels = c(0, 1), 
                         labels = c("NoDocCost", "DocCost")),
    
    # Convert GenHlth to ordered factor with labels
    GenHlth = factor(GenHlth, levels = 1:5,
                     labels = c("Excellent", "VeryGood", "Good", "Fair", "Poor"),
                     ordered = TRUE),
    
    # Ensure Age, Education, Income are ordered factors
    Age = factor(Age, ordered = TRUE),
    Education = factor(Education, ordered = TRUE),
    Income = factor(Income, ordered = TRUE)
  )

# Calculate default values (mode for factors, mean for numeric)
get_mode <- function(x) {
  ux <- unique(x)
  tab <- tabulate(match(x, ux))
  as.character(ux[which.max(tab)])
}

# Set defaults based on your data
default_HighBP <- as.numeric(get_mode(diabetes$HighBP))
default_HighChol <- as.numeric(get_mode(diabetes$HighChol))
default_BMI <- round(mean(diabetes$BMI, na.rm = TRUE), 1)
default_Age <- get_mode(diabetes$Age)
default_GenHlth <- get_mode(diabetes$GenHlth)
default_PhysActivity <- as.numeric(get_mode(diabetes$PhysActivity))
default_HeartDiseaseorAttack <- as.numeric(get_mode(diabetes$HeartDiseaseorAttack))
default_Stroke <- as.numeric(get_mode(diabetes$Stroke))
default_DiffWalk <- as.numeric(get_mode(diabetes$DiffWalk))
default_Sex <- as.numeric(get_mode(diabetes$Sex))

cat("Default values calculated:\n")
cat("HighBP:", default_HighBP, "\n")
cat("HighChol:", default_HighChol, "\n")
cat("BMI:", default_BMI, "\n")
cat("Age:", default_Age, "\n")
cat("GenHlth:", default_GenHlth, "\n")

# Fit your best model (Random Forest) to the ENTIRE dataset
set.seed(123)

final_model <- rand_forest(
  mtry = 5,      # Your best mtry from tuning
  min_n = 40,    # Your best min_n from tuning
  trees = 500    # 500 trees as you used
) %>%
  set_engine("ranger") %>%
  set_mode("classification")

# Create recipe (EXACT same as your modeling file)
diabetes_recipe <- recipe(Diabetes_binary ~ HighBP + HighChol + BMI + 
                            Age + GenHlth + PhysActivity + 
                            HeartDiseaseorAttack + Stroke + DiffWalk + Sex, 
                          data = diabetes) |>
  step_dummy(all_nominal_predictors()) %>%
  step_zv(all_predictors())

# Create workflow and fit to ALL data
final_workflow <- workflow() %>%
  add_model(final_model) %>%
  add_recipe(diabetes_recipe)

cat("\nFitting Random Forest model to entire dataset...\n")
fitted_model <- fit(final_workflow, data = diabetes)
cat("Model fitted successfully!\n\n")

#* @apiTitle Diabetes Prediction API
#* @apiDescription API for predicting diabetes risk based on health indicators using Random Forest

#* Predict diabetes risk
#* @param HighBP High blood pressure (0=No, 1=Yes)
#* @param HighChol High cholesterol (0=No, 1=Yes)
#* @param BMI Body Mass Index (numeric, typically 12-98)
#* @param Age Age category (1-13, where 1=18-24, 13=80+)
#* @param GenHlth General health (Excellent, VeryGood, Good, Fair, Poor)
#* @param PhysActivity Physical activity in past 30 days (0=No, 1=Yes)
#* @param HeartDiseaseorAttack Coronary heart disease or MI (0=No, 1=Yes)
#* @param Stroke Ever had a stroke (0=No, 1=Yes)
#* @param DiffWalk Difficulty walking or climbing stairs (0=No, 1=Yes)
#* @param Sex Biological sex (0=Female, 1=Male)
#* @get /pred
function(HighBP = 0, HighChol = 0, BMI = 28, Age = "9", 
         GenHlth = "Good", PhysActivity = 1, HeartDiseaseorAttack = 0,
         Stroke = 0, DiffWalk = 0, Sex = 0) {
  
  # Convert inputs to appropriate types
  new_data <- tibble(
    HighBP = as.numeric(HighBP),
    HighChol = as.numeric(HighChol),
    BMI = as.numeric(BMI),
    Age = factor(Age, levels = 1:13, ordered = TRUE),
    GenHlth = factor(GenHlth, 
                     levels = c("Excellent", "VeryGood", "Good", "Fair", "Poor"),
                     ordered = TRUE),
    PhysActivity = as.numeric(PhysActivity),
    HeartDiseaseorAttack = as.numeric(HeartDiseaseorAttack),
    Stroke = as.numeric(Stroke),
    DiffWalk = as.numeric(DiffWalk),
    Sex = as.numeric(Sex)
  )
  
  # Get prediction probabilities and class
  pred_prob <- predict(fitted_model, new_data, type = "prob")
  pred_class <- predict(fitted_model, new_data, type = "class")
  
  return(list(
    inputs = list(
      HighBP = HighBP,
      HighChol = HighChol,
      BMI = BMI,
      Age = Age,
      GenHlth = GenHlth,
      PhysActivity = PhysActivity,
      HeartDiseaseorAttack = HeartDiseaseorAttack,
      Stroke = Stroke,
      DiffWalk = DiffWalk,
      Sex = Sex
    ),
    probability_no_diabetes = round(pred_prob$.pred_NoDiabetes, 4),
    probability_diabetes = round(pred_prob$.pred_Diabetes, 4),
    prediction = as.character(pred_class$.pred_class),
    risk_level = ifelse(pred_prob$.pred_Diabetes < 0.3, "Low Risk",
                        ifelse(pred_prob$.pred_Diabetes < 0.6, "Moderate Risk", "High Risk"))
  ))
}

# Example API calls to test (copy and paste into browser):
# http://localhost:8000/pred
# http://localhost:8000/pred?HighBP=1&HighChol=1&BMI=35&Age=11&GenHlth=Poor&PhysActivity=0&HeartDiseaseorAttack=1&Stroke=0&DiffWalk=1&Sex=1
# http://localhost:8000/pred?HighBP=0&HighChol=0&BMI=22&Age=5&GenHlth=Excellent&PhysActivity=1&HeartDiseaseorAttack=0&Stroke=0&DiffWalk=0&Sex=0

#* Information about the API
#* @get /info
function() {
  return(list(
    name = "YOUR NAME HERE",
    project = "ST 558 Final Project - Diabetes Prediction",
    github_pages_url = "https://yourusername.github.io/your-repo-name/",
    model_info = list(
      model_type = "Random Forest",
      best_hyperparameters = list(
        mtry = 5,
        min_n = 40,
        trees = 500
      ),
      cv_logloss = 0.3173,
      predictors = c("HighBP", "HighChol", "BMI", "Age", "GenHlth", 
                     "PhysActivity", "HeartDiseaseorAttack", "Stroke", 
                     "DiffWalk", "Sex")
    ),
    instructions = "Use /pred endpoint with health indicators to get diabetes risk prediction"
  ))
}

#* Confusion matrix for model performance
#* @get /confusion
#* @serializer png
function() {
  # Get predictions on entire dataset
  predictions <- predict(fitted_model, diabetes) %>%
    bind_cols(diabetes %>% select(Diabetes_binary))
  
  # Create confusion matrix
  conf_mat <- predictions %>%
    conf_mat(truth = Diabetes_binary, estimate = .pred_class)
  
  # Create heatmap plot
  p <- autoplot(conf_mat, type = "heatmap") +
    labs(
      title = "Confusion Matrix: Random Forest Model",
      subtitle = paste("Model Performance on Full Dataset (n =", nrow(diabetes), ")"),
      x = "Predicted Class",
      y = "True Class"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5)
    )
  
  print(p)
}

