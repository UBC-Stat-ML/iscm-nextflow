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
    val codeRevision from '1f1d46ce2a3de940f5b6261734ed3c35b34f35db'
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
  memory '60 GB'
  errorStrategy 'ignore'  

  input:
    each method from '--engine iscm.ISCM --engine.usePosteriorSamplingScan true --engine.initialNumberOfSMCIterations 2 --engine.nRounds 15 --engine.nParticles 20',
                     '--engine SCM --engine.nParticles 10000'
                     
    each model from  '--model blang.validation.internals.fixtures.Ising --model.beta 1',
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
        propagation.csv.gz \
        multiRoundPropagation.csv.gz \
    --keys \
      engine as method \
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
  
  mrp <- read.csv("${aggregated}/multiRoundPropagation.csv.gz")
  max_round <- max(mrp\$round)
  mrp <- mrp %>%
    filter(round == max_round) 
    
  p <- read.csv("${aggregated}/propagation.csv.gz")
  df <- bind_rows(mrp, p)
  
  maxIter <- df %>%
    group_by(method, model) %>%
    summarize(max_iter = max(iteration))
    
  df <- df %>% 
    inner_join(maxIter) %>%
    mutate(relative_iter = iteration/max_iter)
  
  df %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = relative_iter, y = annealingParameter, linetype = method, color = method)) +
      geom_line(alpha = 0.8) + 
      facet_wrap(~model) +
      theme_minimal()
  ggsave("annealingSchedules.pdf", width = 10, height = 10, limitsize = FALSE)

  """
  
}