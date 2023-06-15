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
    val codeRevision from '75501068045c5b82960c27c2afa2d42bd0a79fab'
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
   '--model demos.XY',
   '--model ode.MRNATransfection --model.data data/m_rna_transfection/processed.csv',
   '--model mix.SimpleMixture --model.data file data/mixture_data.csv',
   '--model hier.HierarchicalRockets --model.data data/failure_counts.csv', 
   '--model glms.SpikeSlabClassification --model.data data/titanic/titanic-covariates-unid.csv --model.instances.name Name --model.instances.maxSize 200 --model.labels.dataSource data/titanic/titanic.csv --model.labels.name Survived'
]

nexpls = [0.0, 0.5, 1, 2, 4, 8]

nRounds = 10
if (params.dryRun) {
  nRounds = 4
  models = models.subList(0, 1)
  nexpls = [0.5, 1]
}


process runBlang {
  time '10h'  
  cpus nCPUs
  memory '10 GB'
  errorStrategy 'ignore'  

  input:
                     
    each model from  models
    
    each nexpl from nexpls
                     
    each method from '--experimentConfigs.description SSMC --engine iscm.ISCM --engine.resamplingESSThreshold 0.5 --engine.usePosteriorSamplingScan true --engine.initialNumberOfSMCIterations 3 --engine.nRounds ' + nRounds + ' --engine.nParticles ' + nCPUs 

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
    --engine.nPassesPerScan $nexpl \
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
    --keys \
      engine.nPassesPerScan as nPassesPerScan \
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
  require("scales")
  
  cc <- scales::seq_gradient_pal("grey", "black", "Lab")(seq(0,1,length.out=6))
  
  read.csv("aggregated/lambdaInstantaneous.csv.gz") %>%
    filter(isAdapt == "false") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    ggplot(aes(x = beta, y = value, colour = factor(nPassesPerScan), group = factor(nPassesPerScan))) +
      labs(color='Expected updates\nper exploration phase')  + 
      scale_colour_manual(values=cc) +
      geom_line()  + 
      scale_y_continuous(expand = expansion(mult = 0.05), limits = c(0, NA)) +
      facet_wrap(~model, scales = "free_y") +
      theme_minimal()
  ggsave("lambdaInstantaneous.pdf", width = 10, height = 4, limitsize = FALSE)

  

  """
  
}