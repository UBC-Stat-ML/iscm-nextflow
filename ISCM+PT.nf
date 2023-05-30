#!/usr/bin/env nextflow

// Use this to collect final results, e.g. plots and master csv files
deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')


// build java code from a repo
process buildCode {
  executor 'local'
  cache true 
  input:
    val gitRepoName from 'ptanalysis'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from '36b44532a4c071a11cb2527b7210e56c3ab656d4'
    val snapshotPath from "${System.getProperty('user.home')}/w/ptanalysis"
  output:
    file 'code' into code
    file 'ptanalysis/data' into data
  script:
    template 'buildRepo.sh' // for quick prototyping, switch to 'buildSnapshot', and set cache to false above
}

nCPUs = 5

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

nRounds = 20
if (params.dryRun) {
  nRounds = 5
  models = models.subList(0, 1)
}


process runBlang {
  time '10h'  
  cpus nCPUs
  memory '10 GB'
  errorStrategy 'ignore'  

  input:
                     
    each model from  models
                     
    each method from '--experimentConfigs.description IAIS     --engine iscm.IAIS --engine.usePosteriorSamplingScan true --engine.initialNumberOfSMCIterations 3 --engine.nRounds 15 --engine.nParticles ' + nRounds,
                     '--experimentConfigs.description ISCM-50  --engine iscm.ISCM --engine.resamplingESSThreshold 0.5 --engine.usePosteriorSamplingScan true --engine.initialNumberOfSMCIterations 3 --engine.nRounds 15 --engine.nParticles ' + nRounds,
                     '--experimentConfigs.description ISCM-100 --engine iscm.ISCM --engine.resamplingESSThreshold 1.0 --engine.usePosteriorSamplingScan true --engine.initialNumberOfSMCIterations 3 --engine.nRounds 15 --engine.nParticles ' + nRounds,
                     '--experimentConfigs.description PT       --engine PT --engine.initialization FORWARD --engine.nScans 10000 --engine.nChains ' + nRounds    

    file code
    file data
    
  output:
    file 'output' into results
    
  """
  java -Xmx10g -cp ${code}/lib/\\* blang.runtime.Runner \
    --experimentConfigs.resultsHTMLPage false \
    --experimentConfigs.tabularWriter.compressed true \
    $model \
    $method  \
    --engine.nThreads Fixed \
    --engine.nThreads.number $nCPUs
     
  # consolidate all csv files in one place
  mkdir output
  mv results/latest/monitoring/*.csv.gz output
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
    --experimentConfigs.tabularWriter.compressed true \
    --dataPathInEachExecFolder \
        lambdaInstantaneous.csv.gz \
        logNormalizationConstantProgress.csv.gz \
        annealingParameters.csv.gz \
        roundTimings.csv.gz \
        multiRoundPropagation.csv.gz \
        multiRoundResampling.csv.gz \
        predictedResamplingInterval.csv.gz \
        energyExplCorrelation.csv.gz \
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
  
  read.csv("aggregated/multiRoundPropagation.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = iteration, y = ess, colour = method, linetype = method)) +
      geom_line()  + 
      facet_grid(model~round, scales = "free") +
      theme_minimal()
  ggsave("multiRoundPropagation-by-iteration.pdf", width = 35, height = 20, limitsize = FALSE)
  
  preds <- read.csv("aggregated/predictedResamplingInterval.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    filter(method == "ISCM")
  preds\$type <- 'predicted'
  actuals <- read.csv("aggregated/multiRoundResampling.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    filter(method == "ISCM") %>%
    rename(value = deltaIterations)
  actuals\$type <- 'actual'
  
  actuals %>%
    full_join(preds, by = c("model", "method", "round", "type", "value")) %>%
    ggplot(aes(x = round, y = value, colour = type)) +
      geom_point() + 
      facet_wrap(~model) +
      theme_minimal()
  ggsave("preds.pdf", width = 10, height = 5, limitsize = FALSE)
  
  timings <- read.csv("aggregated/roundTimings.csv.gz") %>%
    group_by(model, method) %>%
    mutate(value = cumsum(value)) %>%
    mutate(nExplorationSteps = cumsum(nExplorationSteps))
  
  read.csv("aggregated/lambdaInstantaneous.csv.gz") %>%
    filter(isAdapt == "false") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = beta, y = value, colour = method, linetype = method)) +
      geom_line()  + 
      scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("lambdaInstantaneous.pdf", width = 10, height = 5, limitsize = FALSE)
  
  read.csv("aggregated/energyExplCorrelation.csv.gz") %>%
    filter(isAdapt == "false") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = beta, y = value)) +
      geom_line()  + 
      facet_wrap(~model) +
      theme_minimal()
  ggsave("energyExplCorrelation.pdf", width = 10, height = 5, limitsize = FALSE)
  
  read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = round, y = value, colour = method)) +
      geom_line()  + 
      scale_x_log10() +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress-by-round.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
    inner_join(timings, by = c("model", "method", "round")) %>% 
    rename(value = value.x) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = nExplorationSteps, y = value, colour = method, linetype = method)) +
      geom_line()  + 
      scale_x_log10() +
      xlab("time (ms)") +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress-by-nExpl.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
    inner_join(timings, by = c("model", "method", "round")) %>% 
    rename(time = value.y) %>%
    rename(value = value.x) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = time, y = value, colour = method, linetype = method)) +
      geom_line()  + 
      scale_x_log10() +
      xlab("time (ms)") +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("aggregated/logNormalizationConstantProgress.csv.gz") %>%
    inner_join(timings, by = c("model", "method", "round")) %>% 
    rename(time = value.y) %>%
    rename(value = value.x) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    filter(round > 2) %>%
    ggplot(aes(x = time, y = value, colour = method, linetype = method)) +
      geom_line()  + 
      scale_x_log10() +
      xlab("time (ms)") +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress-suffix.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("aggregated/annealingParameters.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = round, y = value, colour = chain, group = chain)) +
      geom_line()  + 
      facet_grid(model~method, scales = "free_y") +
      scale_y_log10() +
      theme_minimal()
  ggsave("annealingParameters.pdf", width = 10, height = 30, limitsize = FALSE)
  
  read.csv("aggregated/annealingParameters.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>%
    filter(isAdapt == "false") %>% 
    filter(method == "ISCM") %>%
    ggplot(aes(x = chain, y = value)) +
      geom_line()  + 
      facet_grid(method~model, scales = "free_x") +
      theme_minimal()
  ggsave("annealingParameters-final.pdf", width = 30, height = 5, limitsize = FALSE)

  read.csv("aggregated/annealingParameters.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>%
    filter(isAdapt == "false") %>% 
    filter(method == "ISCM") %>%
    ggplot(aes(x = chain, y = value)) +
      geom_line()  + 
      scale_y_log10() +
      facet_grid(method~model, scales = "free_x") +
      theme_minimal()
  ggsave("annealingParameters-log-final.pdf", width = 30, height = 5, limitsize = FALSE)

  """
  
}