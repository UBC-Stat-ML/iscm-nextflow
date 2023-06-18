#!/usr/bin/env nextflow

// Use this to collect final results, e.g. plots and master csv files
deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')


// build java code from a repo
process buildCode {
  executor 'local'
  cache true 
  input:
    val gitRepoName from 'ptanalysis_internal'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from 'bba259c7035ddda57fa8a8e525f8afa1511017c2'
    val snapshotPath from "${System.getProperty('user.home')}/w/ptanalysis"
  output:
    file 'code' into code
    file 'ptanalysis_internal/data' into data
  script:
    template 'buildRepo.sh' // for quick prototyping, switch to 'buildSnapshot', and set cache to false above
}

// for this one it makes most sense to set n cpu = n rounds for every methods
nCPUs = params.nCPUs

params.dryRun = false

models = [
   '--model blang.validation.internals.fixtures.Ising --model.beta 1',
   '--model demos.DiscreteMultimodal',
   '--model demos.AnnealedMVN',
   '--model demos.UnidentifiableProduct',
   '--model demos.XY',
   '--model demos.ToyMix',
   '--model demos.PhylogeneticTree --model.observations.file data/FES_8.g.fasta --model.observations.encoding DNA',
   '--model ode.MRNATransfection --model.data data/m_rna_transfection/processed.csv',
   '--model blang.validation.internals.fixtures.Diffusion --model.process NA NA NA NA NA NA NA NA NA 0.9 --model.startPoint 0.1',
   '--model mix.SimpleMixture --model.data file data/mixture_data.csv',
   '--model hier.HierarchicalRockets --model.data data/failure_counts.csv', 
   '--model glms.SpikeSlabClassification --model.data data/titanic/titanic-covariates-unid.csv --model.instances.name Name --model.instances.maxSize 200 --model.labels.dataSource data/titanic/titanic.csv --model.labels.name Survived'
]

nRounds = 15
nPassesPerScan = 3
if (params.dryRun) {
  nRounds = 4 // should be at least 4 otherwise code crashes
  models = models.subList(0, 1)
}


def PT(nChains) {
  return "--experimentConfigs.description PT-$nChains  --engine PT --engine.initialization FORWARD --engine.nScans ${Math.ceil(25*Math.pow(2,nRounds)/nChains)} --engine.nChains $nChains" 
}

methods = [
  "--experimentConfigs.description SAIS --engine iscm.IAIS --engine.usePosteriorSamplingScan true --engine.initialNumberOfSMCIterations 5 --engine.nRounds $nRounds --engine.nParticles 5",
  "--experimentConfigs.description SSMC --engine iscm.ISCM --engine.resamplingESSThreshold 0.9 --engine.usePosteriorSamplingScan true --engine.initialNumberOfSMCIterations 5 --engine.nRounds $nRounds --engine.nParticles 5",
  PT(10),
  PT(20)
]


process runBlang {
  time '10h'  
  cpus nCPUs
  memory '20 GB'
  errorStrategy 'ignore'  

  input:
                     
    each model from  models
                     
    each method from methods 

    file code
    file data
    
  output:
    file 'output' into results
    
  """
  java -Xmx10g -cp ${code}/lib/\\* blang.runtime.Runner \
    --experimentConfigs.resultsHTMLPage false \
    --experimentConfigs.tabularWriter.compressed false \
    $model \
    $method  \
    --engine.nPassesPerScan $nPassesPerScan \
    --engine.nThreads Fixed \
    --engine.nThreads.number $nCPUs
     
  # consolidate all csv files in one place
  mkdir output
  mv results/latest/monitoring/*.csv output
  mv results/latest/*.tsv output
  mv results/latest/executionInfo/stdout.txt output
  mv results/latest/executionInfo/stderr.txt output
  """
}

// Merge many csv files while padding relevant experimental configs as new columns in the merged csv
process aggregate {
  time '1m'
  echo false
  scratch false
  input:
    file 'exec_*' from results.toList()
  output:
    file 'results/aggregated/' into aggregated
  """
  aggregate \
    --experimentConfigs.resultsHTMLPage false \
    --experimentConfigs.tabularWriter.compressed false \
    --dataPathInEachExecFolder \
        lambdaInstantaneous.csv \
        cumulativeLambda.csv \
        globalLambda.csv \
        logNormalizationConstantProgress.csv \
        annealingParameters.csv \
        roundTimings.csv \
        multiRoundResampling.csv \
        predictedResamplingInterval.csv \
        energyExplCorrelation.csv \
    --keys \
      experimentConfigs.description as method \
      model \
           from arguments.tsv
  mv results/latest results/aggregated
  """
}

process plot {
  scratch false  
  
  publishDir deliverableDir, mode: 'copy', overwrite: true
   
  input:
    file aggregated
  output:
    file '*.*'
    file 'aggregated'   
  afterScript 'rm Rplots.pdf; cp .command.sh rerun.sh'
  """
  #!/usr/bin/env Rscript
  require("ggplot2")
  require("dplyr")
  require("stringr")
  
  read.csv("aggregated/cumulativeLambda.csv") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = round, y = value, colour = beta, group = beta)) +
      geom_line()  + 
      facet_grid(model~method, scales = "free_y") +
      theme_minimal()
  ggsave("cumulativeLambdaEstimates.pdf", width = 10, height = 30, limitsize = FALSE)
  
  read.csv("aggregated/globalLambda.csv") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = round, y = value)) +
      geom_line()  + 
      facet_grid(model~method, scales = "free_y") +
      theme_minimal()
  ggsave("globalLambdaEstimates.pdf", width = 10, height = 30, limitsize = FALSE)
  
  timings <- read.csv("aggregated/roundTimings.csv") %>%
    group_by(model, method) %>%
    mutate(value = cumsum(value)) %>%
    mutate(nExplorationSteps = cumsum(nExplorationSteps))
  
  read.csv("aggregated/lambdaInstantaneous.csv") %>%
    filter(isAdapt == "false") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = beta, y = value, colour = method, linetype = method)) +
      geom_line()  + 
      scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("lambdaInstantaneous.pdf", width = 10, height = 5, limitsize = FALSE)
  
  read.csv("aggregated/energyExplCorrelation.csv") %>%
    filter(isAdapt == "false") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = beta, y = value)) +
      geom_line()  + 
      facet_wrap(~model) +
      theme_minimal()
  ggsave("energyExplCorrelation.pdf", width = 10, height = 5, limitsize = FALSE)
  
  read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = round, y = value, colour = method)) +
      geom_line()  + 
      scale_x_log10() +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress-by-round.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
    inner_join(timings, by = c("model", "method", "round")) %>% 
    rename(value = value.x) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = nExplorationSteps, y = value, colour = method, linetype = method)) +
      geom_line()  + 
      scale_x_log10() +
      xlab("number of exploration steps") +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress-by-nExpl.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
    inner_join(timings, by = c("model", "method", "round")) %>% 
    rename(time = value.y) %>%
    rename(value = value.x) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = time, y = value, colour = method, linetype = method)) +
      geom_line()  + 
      scale_x_log10() +
      xlab("time (ms)") +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("aggregated/logNormalizationConstantProgress.csv") %>%
    inner_join(timings, by = c("model", "method", "round")) %>% 
    rename(time = value.y) %>%
    rename(value = value.x) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    filter(round > 2) %>%
    ggplot(aes(x = time, y = value, colour = method, linetype = method)) +
      geom_line()  + 
      scale_x_log10() +
      xlab("time (ms)") +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress-suffix.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("aggregated/annealingParameters.csv") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = round, y = value, colour = chain, group = chain)) +
      geom_line()  + 
      facet_grid(model~method, scales = "free_y") +
      scale_y_log10() +
      theme_minimal()
  ggsave("annealingParameters.pdf", width = 10, height = 30, limitsize = FALSE)
  


  """
  
}