library(polyester)
library(Biostrings)

args = commandArgs(trailingOnly=TRUE)

fasta_file = args[1]
output_dir = args[2]
stranded_arg   = args[3]
error_rate     = as.numeric(args[4])

stranded = FALSE

if (stranded_arg == "true") {
  stranded = TRUE
}

fasta = readDNAStringSet(fasta_file)

fold_changes = head(matrix(c(rep(c(1,4),length(fasta)),rep(c(4,1),length(fasta))),nrow=length(fasta)*2),length(fasta))

readspertx = round(20 * width(fasta) / 100)

simulate_experiment(fasta_file, strand_specific=stranded, reads_per_transcript=readspertx, 
    num_reps=c(2,2), fold_changes=fold_changes, outdir=output_dir, error_rate=error_rate)
