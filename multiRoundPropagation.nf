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
    val codeRevision from 'eaebb3473786e6df39a3fe63ffaf064eba0998ca'
    val snapshotPath from "${System.getProperty('user.home')}/w/ptanalysis"
  output:
    file 'code' into code
    file 'ptanalysis/data' into data
  script:
    template 'buildRepo.sh' // for quick prototyping, switch to 'buildSnapshot', and set cache to false above
}

params.nRounds = 10

process runBlang {
  time '10h'  
  cpus 1
  memory '10 GB'
  errorStrategy 'ignore'  

  input:
                     
    each model from  '--model blang.validation.internals.fixtures.Ising --model.beta 1',
                     '--model demos.DiscreteMultimodal',
                     '--model demos.AnnealedMVN',
                     '--model demos.UnidentifiableProduct',
                     '--model demos.XY',
                     '--model demos.ToyMix',
                     '--model demos.PhylogeneticTree --model.observations.file data/FES_8.g.fasta --model.observations.encoding DNA',
                     '--model ode.MRNATransfection --model.data data/m_rna_transfection/processed.csv',
                     '--model demos.PhylogeneticTree --model.observations.file data/primates.fasta --model.observations.encoding DNA',
                     '--model blang.validation.internals.fixtures.Diffusion --model.process NA NA NA NA NA NA NA NA NA 0.9 --model.startPoint 0.1',
                     '--model mix.SimpleMixture --model.data file data/mixture_data.csv',
                     '--model hier.HierarchicalRockets --model.data data/failure_counts.csv', 
                     '--model glms.SpikeSlabClassification --model.data data/titanic/titanic-covariates-unid.csv --model.instances.name Name --model.instances.maxSize 200 --model.labels.dataSource data/titanic/titanic.csv --model.labels.name Survived'
                     
    file code
    file data
    
  output:
    file 'output' into results
    
  """
  java -Xmx5g -cp ${code}/lib/\\* -Xmx10g blang.runtime.Runner \
    --experimentConfigs.resultsHTMLPage false \
    --experimentConfigs.tabularWriter.compressed true \
    --engine iscm.ISCM \
    --engine.nThreads Single \
    --engine.usePosteriorSamplingScan true \
    --engine.initialNumberOfSMCIterations 2 \
    --engine.nRounds $params.nRounds \
    --engine.nParticles 20 \
    $model  
     
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
  
  read.csv("${aggregated}/multiRoundPropagation.csv.gz") %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>% 
    mutate(model = str_replace(model, ".*[.]", "")) %>% 
    mutate(method = str_replace(method, ".*[.]", "")) %>% 
    ggplot(aes(x = iteration, y = ess)) +
      geom_line()  + 
      facet_grid(model~round, scales = "free_y") +
      scale_y_log10() +
      theme_bw()
  ggsave("multiRoundPropagation-by-iteration.pdf", width = 35, height = 20, limitsize = FALSE)
  """
  
}