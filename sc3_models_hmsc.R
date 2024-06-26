
# Species distribution models on selected species

library(doSNOW)
library(foreach)
library(tictoc)
library(Hmsc)

data_sdm_500 <- readRDS("data/data_sdm_ebird_pca_500.rds")
data_sdm_200 <- readRDS("data/data_sdm_ebird_pca_200.rds")
data_sdm_1000 <- readRDS("data/data_sdm_ebird_pca_500.rds")


# HMSC --------------------------------------------------------------------

run_sdm <- function(data_sdm) {
  pb <- txtProgressBar(min = 0, max = length(data_sdm), style = 3)
  
  coda_hmsc <- list()
  rhat_beta <- list()
  rhat_gamma <- list()
  eff_ss_beta <- list()
  eff_ss_gamma <- list()
  
  tic()
  
  results <- foreach(i=1:length(data_sdm)) %do% {
    
    smp <- 2500
    trans <- 5000
    thin <- 2
    
    Y <- as.matrix(data_sdm[[i]]$y)
    XData <- data_sdm[[i]][,grepl("PC", names(data_sdm[[i]]))]
    
    model_str <- Hmsc(Y = Y, XData = XData, distr = "probit")
    
    sdm <- sampleMcmc(model_str, 
                      samples=smp, 
                      transient=trans, 
                      thin=thin, 
                      nChains=4, 
                      nParallel=4)
    
    coda_hmsc[[i]] <- convertToCodaObject(sdm)
    rhat_beta[[i]] <- gelman.diag(coda_hmsc[[i]]$Beta, multivariate = F)
    rhat_gamma[[i]] <- gelman.diag(coda_hmsc[[i]]$Gamma, multivariate = F)
    eff_ss_beta[[i]] <- effectiveSize(coda_hmsc[[i]]$Beta)
    eff_ss_gamma[[i]] <- effectiveSize(coda_hmsc[[i]]$Gamma)
    
    boo1 <- any(rhat_beta[[i]]$psrf[,"Upper C.I."]>1.05) | 
      any(rhat_gamma[[i]]$psrf[,"Upper C.I."]>1.05)
    boo2 <- any(eff_ss_beta[[i]]<100) | any(eff_ss_gamma[[i]]<100)
    
    while(boo1 | boo2) {
      
      smp <- smp*2
      trans <- trans*2
      thin <- thin*2
      
      sdm <- sampleMcmc(model_str, 
                        samples=smp, 
                        transient=trans, 
                        thin=thin, 
                        nChains=4, 
                        nParallel=4)
      
      coda_hmsc[[i]] <- convertToCodaObject(sdm)
      rhat_beta[[i]] <- gelman.diag(coda_hmsc[[i]]$Beta, multivariate = F)
      rhat_gamma[[i]] <- gelman.diag(coda_hmsc[[i]]$Gamma, multivariate = F)
      eff_ss_beta[[i]] <- effectiveSize(coda_hmsc[[i]]$Beta)
      eff_ss_gamma[[i]] <- effectiveSize(coda_hmsc[[i]]$Gamma)
      
      boo1 <- any(rhat_beta[[i]]$psrf[,"Upper C.I."]>1.05) | 
        any(rhat_gamma[[i]]$psrf[,"Upper C.I."]>1.05)
      boo2 <- any(eff_ss_beta[[i]]<100) | any(eff_ss_gamma[[i]]<100)
      
    }
    
    setTxtProgressBar(pb, i)
    
    return(sdm)
    
  }
  
  toc()
  
  return(results)
}

results_500 <- run_sdm(data_sdm_500)
results_200 <- run_sdm(data_sdm_200)
results_1000 <- run_sdm(data_sdm_1000)

saveRDS(results_500, "results/results_hmsc_ebird_500.rds")
saveRDS(results_200, "resultsresults_hmsc_ebird_200.rds")
saveRDS(results_1000, "results/results_hmsc_ebird_1000.rds")

