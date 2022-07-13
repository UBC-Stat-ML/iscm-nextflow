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
    val codeRevision from '72362299cc3ec3bae8563fa138cb3ba6b8ad3b83'
    val snapshotPath from "${System.getProperty('user.home')}/w/ptanalysis"
  output:
    file 'code' into code
    file 'ptanalysis/data' into data
  script:
    template 'buildRepo.sh' // for quick prototyping, switch to 'buildSnapshot', and set cache to false above
}

nCPUs = 5

process runBlang {
  time '10h'  
  cpus nCPUs
  memory '2 GB'
  errorStrategy 'ignore'  

  input:
                     
    each model from  '--model blang.validation.internals.fixtures.Ising --model.beta 1'
                 /*  '--model hier.HierarchicalRockets --model.data data/failure_counts.csv',
                     '--model demos.PhylogeneticTree --model.observations.file data/FES_8.g.fasta --model.observations.encoding DNA',
                     '--model demos.DiscreteMultimodal',
                     '--model demos.AnnealedMVN',
                     '--model demos.UnidentifiableProduct',
                     '--model demos.XY',
                     '--model demos.ToyMix',
                     '--model ode.MRNATransfection --model.data data/m_rna_transfection/processed.csv',
                     '--model blang.validation.internals.fixtures.Diffusion --model.process NA NA NA NA NA NA NA NA NA 0.9 --model.startPoint 0.1',
                     '--model mix.SimpleMixture --model.data file data/mixture_data.csv',
                     '--model glms.SpikeSlabClassification --model.data data/titanic/titanic-covariates-unid.csv --model.instances.name Name --model.instances.maxSize 200 --model.labels.dataSource data/titanic/titanic.csv --model.labels.name Survived'
                  */
                     
    each method from '--engine iscm.ISCM --engine.usePosteriorSamplingScan true --engine.nRounds 8 --engine.initialNumberOfSMCIterations 3 --engine.nParticles 20',
                     '--engine iscm.ISCM --engine.usePosteriorSamplingScan false --engine.nRounds 8 --engine.initialNumberOfSMCIterations 75 --engine.nParticles 20',
                     '--engine PT --engine.nScans 2000 --engine.nChains 20'    

    each seed from 1..2
  
    file code
    file data
    
  output:
    file 'output' into results
    
  """
  java -Xmx2g -cp ${code}/lib/\\* blang.runtime.Runner \
    --experimentConfigs.resultsHTMLPage false \
    --experimentConfigs.tabularWriter.compressed true \
    $model \
    $method  \
    --engine.random $seed \
    --engine.nThreads Fixed \
    --engine.nThreads.number $nCPUs
     
  # consolidate all csv files in one place
  mkdir output
  mv results/latest/monitoring/*.csv.gz output
  mv results/latest/*.tsv output
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
    --keys \
      engine as method \
      engine.nParticles as nParticles \
      engine.random as seed \
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
    file 'aggregated'   // include the csv files into deliverableDir
  afterScript 'rm Rplots.pdf; cp .command.sh rerun.sh'  // clean up after R, include script to rerun R code from CSVs
  """
  #!/usr/bin/env Rscript
  require("ggplot2")
  require("dplyr")
  require("stringr")
  

  
  timings <- read.csv("${aggregated}/roundTimings.csv.gz") %>%
    group_by(model, method, seed, nParticles) %>%
    mutate(value = cumsum(value))
  

  
  read.csv("${aggregated}/logNormalizationConstantProgress.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = round, y = value, colour = factor(paste0(method, "_", nParticles)), linetype = factor(seed))) +
      geom_line()  + 
      scale_x_log10() +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress-by-round.pdf", width = 10, height = 10, limitsize = FALSE)
  
  read.csv("${aggregated}/logNormalizationConstantProgress.csv.gz") %>%
    inner_join(timings, by = c("model", "method", "round", "seed", "nParticles")) %>% 
    rename(time = value.y) %>%
    rename(value = value.x) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = time, y = value, colour = factor(paste0(method, "_", nParticles)), linetype = factor(seed))) +
      geom_line()  + 
      scale_x_log10() +
      xlab("time (ms)") +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("logNormalizationConstantProgress.pdf", width = 10, height = 10, limitsize = FALSE)

  """
  
}