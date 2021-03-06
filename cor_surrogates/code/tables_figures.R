#-----------------------------------------------
# obligatory to append to the top of each script
renv::activate(project = here::here(".."))

# There is a bug on Windows that prevents renv from working properly. The following code provides a workaround:
if (.Platform$OS.type == "windows") .libPaths(c(paste0(Sys.getenv ("R_HOME"), "/library"), .libPaths()))

source(here::here("..", "_common.R"))

## ----load-all-SLobjects, message=FALSE, error=FALSE, warning=FALSE----------------------------------------------------------------------------------------------------

library("cvAUC")
library("conflicted")
library("tidyverse")
library("dplyr")
library("cowplot")
library("ggplot2")
library("vimp")
library("kyotil")
library(gridExtra)
library(cowplot)
library(here)
# filter() is used in both dplyr and stats, so need to set the preference to dplyr
conflict_prefer("filter", "dplyr")
conflict_prefer("summarise", "dplyr")
source(here("code", "utils.R"))
method <- "method.CC_nloglik" # since SuperLearner relies on this to be in GlobalEnv
ggplot2::theme_set(theme_cowplot())

load(file = here("output", "cvaucs_d57_vacc.rda"))
load(file = here("output", "ph2_vacc_ptids.rda"))

## ----learner-screens, warning=kable_warnings--------------------------------------------------------------------------------------------------------------------------
caption <- "All learner-screen combinations (14 in total) used as input to the Superlearner."

tab <- cvaucs_d57_vacc %>%
  filter(!Learner %in% c("SL", "Discrete SL")) %>%
  select(Learner, Screen) %>%
  mutate(Screen = fct_relevel(Screen, c("all", "glmnet", "univar_logistic_pval",
                                        "highcor_random")),
         Learner = as.factor(Learner)) %>%
  arrange(Learner, Screen) %>% 
  distinct(Learner, Screen) %>%
  rename("Screen*" = Screen) 

if(!grepl("Mock", study_name)){
  tab <- tab %>%
    mutate(Learner = fct_relevel(Learner, c("SL.mean", "SL.glmnet.0", "SL.glmnet.1", "SL.xgboost.2.no", "SL.xgboost.4.no",  
                                            "SL.xgboost.2.yes", "SL.xgboost.4.yes", "SL.ranger.yes", "SL.ranger.no", "SL.glm"))) %>%
    arrange(Learner, `Screen*`)
}else{
  tab <- tab %>%
    mutate(Learner = fct_relevel(Learner, c("SL.mean", "SL.glm"))) %>%
    arrange(Learner, `Screen*`)
}

tab %>% write.csv(here("output", "learner-screens.csv"))

## ----All 14 variable sets --------------------------------------------------------------------------------------------------------------------
caption <- "The 12 variable sets on which an estimated optimal surrogate was built."

tab <- data.frame(`Variable Set Name` = c("1_baselineRiskFactors", 
                                          "2_varset_bAbSpike", "3_varset_bAbRBD", "4_varset_pnabID50", "5_varset_pnabID80",  
                                          "6_varset_bAb_pnabID50", "7_varset_bAb_pnabID80", 
                                          "8_varset_bAb_combScores", "9_varset_allMarkers", "10_varset_allMarkers_combScores"),
                  `Variables included in the set` = c("Baseline risk factors only (Reference model)",
                                                      "Baseline risk factors + bAb anti-Spike markers",
                                                      "Baseline risk factors + bAb anti-RBD markers",
                                                      "Baseline risk factors + p-nAb ID50 markers",
                                                      "Baseline risk factors + p-nAb ID80 markers",
                                                      "Baseline risk factors + bAb markers + p-nAb ID50 markers",
                                                      "Baseline risk factors + bAb markers + p-nAb ID80 markers",
                                                      "Baseline risk factors + bAb markers + combination scores across the five markers [PCA1, PCA2, FSDAM1/FSDAM2 (the first two
components of nonlinear PCA), and the maximum signal diversity score]",
                                                      "Baseline risk factors + all individual markers",
                                                      "Baseline risk factors + all individual markers + all combination scores (Full model)"))

tab %>% write.csv(here("output", "varsets.csv"))

##############################################################################################################################
##############################################################################################################################
# Forest plots for vaccine model
# vaccine group
options(bitmapType = "cairo")
for(i in 1:length(unique(cvaucs_d57_vacc$varset))) {
  variableSet = unique(cvaucs_d57_vacc$varset)[i]
  png(file = here("figs", paste0("forest_vacc_cvaucs_", variableSet, ".png")), width=1000, height=1100)
  top_learner <- make_forest_plot(cvaucs_d57_vacc %>% filter(varset==variableSet))
  grid.arrange(top_learner$top_learner_nms_plot, top_learner$top_learner_plot, ncol=2)
  dev.off()
}

# All 12 Superlearners
allSLs <- cvaucs_d57_vacc %>% filter(Learner == "SL") %>%
  mutate(varsetNo = sapply(strsplit(varset, "_"), `[`, 1),
         varsetNo = as.numeric(varsetNo)) %>%
  arrange(varsetNo) %>% 
  mutate(varset = fct_reorder(varset, AUC, .desc = F)) %>%
  arrange(-AUC)

png(file = here("figs", paste0("forest_vacc_cvaucs_allSLs.png")), width=1000, height=1100)
lowestXTick <- floor(min(allSLs$ci_ll)*10)/10
highestXTick <- ceiling(max(allSLs$ci_ul)*10)/10
top_learner_plot <- ggplot() +
  geom_pointrange(allSLs %>% mutate(varset = fct_reorder(varset, AUC, .desc = F)), mapping=aes(x=varset, y=AUC, ymin=ci_ll, ymax=ci_ul), size = 1, color="blue", fill="blue", shape=20) +
  coord_flip() +
  scale_y_continuous(breaks = seq(lowestXTick, max(highestXTick, 1), 0.1), labels = seq(lowestXTick, max(highestXTick, 1), 0.1), limits = c(lowestXTick, max(highestXTick, 1))) +
  theme_bw() +
  labs(y = "CV-AUC [95% CI]", x = "") +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank(),
        axis.title.y = element_blank(),
        axis.text.x = element_text(size=16),
        axis.title.x = element_text(size=16),
        axis.text.y = element_blank(),
        plot.margin=unit(c(1,-0.15,1,-0.15),"cm"),
        panel.border = element_blank(),
        axis.line = element_line(colour = "black"))

total_learnerScreen_combos = length(allSLs$LearnerScreen)  

allSLs_withCoord <- allSLs %>%
  select(varset, AUCstr) %>%
  gather("columnVal", "strDisplay") %>%
  mutate(xcoord = case_when(columnVal=="varset" ~ 1.4,
                            columnVal=="AUCstr" ~ 2),
         ycoord = rep(total_learnerScreen_combos:1, 2))

top_learner_nms_plot <- ggplot(allSLs_withCoord, aes(x = xcoord, y = ycoord, label = strDisplay)) +
  geom_text(hjust=1, vjust=0, size=5) +
  xlim(0.7,2) +
  theme(plot.margin=unit(c(1.7,-0.15,2.4,-0.15),"cm"),
        axis.line=element_blank(),
        axis.text.y = element_blank(),
        axis.text.x = element_text(size = 2, color = "white"),
        axis.ticks = element_blank(),
        axis.title = element_blank())

top_learner <- list(top_learner_plot = top_learner_plot, top_learner_nms_plot = top_learner_nms_plot)
grid.arrange(top_learner$top_learner_nms_plot, top_learner$top_learner_plot, ncol=2)
dev.off()
  
#################################################################################################################################
#################################################################################################################################
# plot ROC curve and pred.Prob with SL, Discrete SL and top 2 best-performing individual Learners for all 12 variable sets
for(i in 1:length(unique(cvaucs_d57_vacc$varset))) {
  variableSet = unique(cvaucs_d57_vacc$varset)[i]
  dat <- cvaucs_d57_vacc %>% filter(varset==variableSet)
  
  top2 <- bind_rows(
    dat %>% 
      arrange(-AUC) %>%
      filter(!Learner %in% c("SL", "Discrete SL")) %>%
      dplyr::slice(1:2),
    dat %>%
      filter(Learner == "SL"),
    dat %>%
      filter(Learner == "Discrete SL")
  ) %>%
    mutate(LearnerScreen = ifelse(Learner == "SL", "Super Learner",
                                  ifelse(Learner == "Discrete SL", Learner,
                                         paste0(Learner, "_", Screen_fromRun))))
  
  # Get cvsl fit and extract cv predictions
  load(file = here("output", paste0("CVSLfits_vacc_EventIndPrimaryD57_", variableSet, ".rda")))
  pred <- get_cv_predictions(cv_fit = cvfits[[1]], cvaucDAT = top2)
  
  # plot ROC curve
  options(bitmapType = "cairo")
  png(file = here("figs", paste0("ROCcurve_", variableSet, ".png")),
      width = 1000, height = 1000)
  p1 <- plot_roc_curves(predict = pred, cvaucDAT = top2, weights = ph2_vacc_ptids$wt.D57)
  print(p1)
  dev.off()
  
  # plot pred prob plot
  options(bitmapType = "cairo")
  png(file = here("figs", paste0("predProb_", variableSet, ".png")),
      width = 1000, height = 1000)
  p2 <- plot_predicted_probabilities(pred)
  print(p2)
  dev.off()
}


# Get top 2 Superlearner performers
cvaucs_d57_vacc %>% arrange(-AUC) %>% 
  filter(Learner == "SL") %>%
  select(varset, AUCstr) %>%
  write.csv(here("output", "SLperformance_allvarsets.csv"))
  
